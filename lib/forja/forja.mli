(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La forja: un proxy de LLM que cristaliza las tareas que atiende.

    Cada petición pertenece a una {e tarea}: unas instrucciones fijas (la
    {e plantilla}, el system prompt) aplicadas a una {e entrada} que varía.
    Una tarea nueva es líquida: la forja la pasa al LLM y guarda el par
    entrada → salida en la {e cantera}. Cuando la tarea {e madura} (bastantes
    muestras y el LLM contesta igual a lo mismo), la forja lo avisa para que
    se nuclee: se le pide al LLM el método, no otra respuesta. El cristal que
    sale se revisa, se commitea y se pone en la {e vitrina}; desde entonces la
    tarea la atiende el cristal y el LLM solo ve los defectos.

    Este módulo es el núcleo y es puro salvo por la cantera, que se inyecta:
    no habla HTTP ni llama al LLM. Decide ([decidir]) y aprende ([aprender]);
    quien lo envuelve (ver [forja_http]) hace la llamada. *)

(** {1 Tareas} *)

module Tarea : sig
  type t = private string

  val explicita : string -> (t, string) result
  (** Nombre puesto por el cliente: [[a-z0-9-]+], hasta 64 caracteres. *)

  val de_plantilla : string -> t
  (** Nombre derivado de la plantilla: [t-] y 12 hex de su digest. Misma
      plantilla, misma tarea. *)

  val to_string : t -> string
end

type peticion = {
  tarea : Tarea.t;
  plantilla : string;  (** Lo que no cambia: las instrucciones. *)
  entrada : string;  (** Lo que cambia de una llamada a otra. *)
}

type cristal = (string, string) Cristal.cristal
(** En la forja un cristal va de texto a texto: el de la entrada al de la
    respuesta. Los cristales tipados se adaptan al registrarlos. *)

(** {1 Vitrina}

    Los cristales ya nucleados, revisados y commiteados. Se compila con el
    proxy: un cristal nuevo es un cambio de código, no de estado. *)

module Vitrina : sig
  type estado = [ `Mixta | `Cristalina ]

  type pieza = {
    tarea : Tarea.t;
    estado : estado;
    cristal : cristal;
    descripcion : string;
        (** Qué hace, para quien lo llame como herramienta (ver
            [forja-mcp]). El proxy no la usa. *)
  }

  type t

  val vacia : t
  val con : ?descripcion:string -> Tarea.t -> estado -> cristal -> t -> t
  val buscar : t -> Tarea.t -> (estado * cristal) option

  val listar : t -> pieza list
  (** Por nombre de tarea. *)
end

(** {1 Cantera}

    Registro de lo que resolvió el líquido. Es de donde salen las semillas. *)

module Cantera : sig
  type muestra = {
    tarea : Tarea.t;
    plantilla : string;
    entrada : string;
    salida : string;
    contraste : string option;
        (** Segunda respuesta del LLM a la misma entrada, si se pidió. *)
    defecto : Cristal.motivo option;
        (** Si vino de un defecto de un cristal mixto, su motivo. *)
  }

  type t = {
    registrar : muestra -> unit;
    muestras : Tarea.t -> muestra list;  (** En orden de llegada. *)
    tareas : unit -> Tarea.t list;  (** Las que tienen alguna muestra. *)
  }

  val en_memoria : unit -> t
end

(** {1 Madurez} *)

module Madurez : sig
  type politica = {
    minimo : int;  (** Muestras antes de proponer la nucleación. *)
    contrastar_cada : int;
        (** Una de cada [n] llamadas líquidas se pide dos veces. *)
    contrastes : int;  (** Contrastes mínimos para juzgar la estabilidad. *)
    estabilidad : float;
        (** Fracción de contrastes en que el LLM repitió la respuesta. *)
  }

  val por_defecto : politica
  (** 20 muestras, contraste 1 de cada 10, 2 contrastes, estabilidad 0,9. *)

  type informe = { muestras : int; contrastes : int; coincidencias : int }

  val vacio : informe
  val sumar : informe -> Cantera.muestra -> informe
  val informe : Cantera.muestra list -> informe

  val madura : politica -> informe -> bool
  (** Si al pedirle dos veces lo mismo al LLM contesta lo mismo, la tarea
      debería ser un cristal. *)
end

(** {1 Semilla} *)

module Semilla : sig
  val markdown : Tarea.t -> Madurez.informe -> Cantera.muestra list -> string
  (** [SEMILLA.md] del futuro cristal, con las muestras de la cantera. *)

  val nucleacion : prompt:string -> Cantera.muestra list -> string
  (** Rellena el prompt de nucleación ([prompts/cristalizar.md]) con la
      plantilla de la tarea y las muestras. Del fichero se toma lo que hay
      entre la primera y la última raya [---]. *)
end

(** {1 La forja} *)

type t

val crear :
  ?politica:Madurez.politica ->
  ?observar:(Cristal.evento -> unit) ->
  vitrina:Vitrina.t ->
  cantera:Cantera.t ->
  unit ->
  t
(** [observar] recibe los mismos eventos que [Cristal.ejecutar], con la tarea
    como nombre de etapa: se le puede enchufar un [Cristal.Medidor]. *)

type decision =
  | Por_cristal of string  (** Responde el cristal; no se llama al LLM. *)
  | Al_liquido of { contrastar : bool; defecto : Cristal.motivo option }
      (** Hay que llamar al LLM (dos veces si [contrastar]) y luego
          [aprender]. [defecto] si un cristal mixto no supo. *)
  | Fallo of Cristal.fallo
      (** Defecto de un cristal [`Cristalina]: no hay LLM al que caer. *)

val decidir : t -> peticion -> decision

val aprender :
  t ->
  peticion ->
  ?contraste:string ->
  ?defecto:Cristal.motivo ->
  string ->
  Madurez.informe option
(** Registra en la cantera la salida del LLM. Devuelve [Some informe] la
    primera vez que la tarea madura; quien llama prepara la semilla. *)

(** {1 Introspección}

    Lo que la forja sabe de cada tarea, para quien la observa (la API
    [/forja/…] del proxy y, a través de ella, [forja-mcp]). *)

type fase = [ `Liquida | `Mixta | `Cristalina ]

type resumen = {
  tarea : Tarea.t;
  fase : fase;  (** [`Liquida] si no está en la vitrina. *)
  informe : Madurez.informe;
  madura : bool;  (** Según la política de la forja. *)
}

val resumen : t -> Tarea.t -> resumen

val tareas : t -> resumen list
(** Las de la cantera y las de la vitrina, por nombre. *)

val vitrina : t -> Vitrina.t
val politica : t -> Madurez.politica
val informe : t -> Tarea.t -> Madurez.informe
val cantera : t -> Cantera.t
