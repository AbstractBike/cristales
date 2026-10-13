(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Traducción entre la Messages API de Anthropic y las peticiones de la
    forja. Pura. *)

val cabecera_tarea : string
(** [x-forja-tarea]: nombre explícito de la tarea. Sin ella, la tarea se
    deriva de la plantilla. *)

(** Qué devuelve la tarea. *)
type forma =
  | Texto  (** El texto de la respuesta ([end_turn]). *)
  | Herramienta of string
      (** La entrada de una herramienta forzada con
          [tool_choice = {type: tool, name}]: la salida es su JSON. Es la
          forma de las pipelines con salida estructurada. *)

val peticion :
  tarea:string option -> Yojson.Safe.t -> (Forja.peticion * forma, string) result
(** [Ok] si la petición es una tarea cristalizable: un solo turno de usuario
    con texto, instrucciones en [system] (o tarea explícita), sin streaming,
    y sin herramientas o con una sola forzada. La plantilla es el [system]
    y, con herramienta, su definición: otra herramienta, otra tarea.
    [Error motivo] en otro caso: la petición pasa al LLM sin que la forja la
    toque. *)

val salida : forma -> Yojson.Safe.t -> string option
(** La salida de una respuesta del LLM: el texto si terminó en [end_turn], o
    el JSON (canónico: claves ordenadas) de la herramienta si terminó en
    [tool_use]. *)

val texto : Yojson.Safe.t -> string option
(** [salida Texto]. *)

val respuesta : modelo:string -> forma -> string -> (Yojson.Safe.t, string) result
(** Respuesta en formato Messages con la salida de un cristal. [Error] si la
    forma es [Herramienta] y la salida no es un objeto JSON. *)

val error : tipo:string -> string -> Yojson.Safe.t

(** {1 Cristales parciales} *)

val campos : Yojson.Safe.t -> string list
(** Las propiedades de la herramienta forzada de una petición; [[]] sin ella. *)

val restringir : Yojson.Safe.t -> string list -> Yojson.Safe.t
(** La petición con la herramienta forzada reducida a esos campos: lo que se
    le pide al LLM cuando el cristal ya dio el resto. *)

val uso : Yojson.Safe.t -> (int * int) option
(** Tokens de entrada y de salida de una respuesta ([usage]). *)

(** {1 Ejemplos} *)

val con_ejemplos : Yojson.Safe.t -> bool
(** Si la petición lleva turnos previos al último (ejemplos few-shot). *)

val sin_ejemplos : Yojson.Safe.t -> Yojson.Safe.t
(** La misma petición sin ellos: el system y el último turno. *)
