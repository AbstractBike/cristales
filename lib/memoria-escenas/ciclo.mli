(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Una pasada de consolidación: átomos nuevos → escenas → persona. Los
    encargos y la hora se inyectan; los ficheros los escribe quien llama.

    Por lote de átomos (agrupados por escena propuesta, para que cada lote
    sea de un tema): se abren las escenas más parecidas, se encarga a
    [memoria-escenas], se aplican sus operaciones y, si alguna se rechaza,
    se le devuelven los motivos una vez y se aplica la segunda respuesta
    (o, si esa no se entiende, lo válido de la primera). Una salida que no
    es JSON se juzga mal en la agencia sin esperar a nadie. *)

type efectos = {
  encargar : Agencia.Agente.t -> string -> Agencia.Encargo.t;
  juzgar_mal : Agencia.Encargo.t -> string -> unit;  (** Con la nota. *)
  ahora : unit -> string;  (** ISO 8601 en UTC. *)
  log : string -> unit;
}

type encargo = { agente : string; id : string; modelo : string; ms : int; tokens : int; resumen : string }
(** Lo que se cuenta de cada encargo, para juzgarlo después. *)

type salida = {
  escenas : Escena.t list;
  escritas : string list;  (** Slugs a escribir. *)
  borradas : string list;  (** Slugs a borrar. *)
  persona : string option;  (** El texto nuevo de [persona.md], si se regeneró. *)
  estado : Estado.t;
  consolidados : int;  (** Átomos procesados. *)
  encargos : encargo list;
}

val lotes : int -> Atomo.t list -> Atomo.t list list
(** De [n] en [n], ordenados por escena propuesta y por [ts]. *)

val consolidar :
  efectos ->
  escenas_agente:Agencia.Agente.t ->
  persona_agente:Agencia.Agente.t ->
  ?lote:int ->
  estado:Estado.t ->
  persona:string ->
  Escena.t list ->
  Atomo.t list ->
  salida
(** [lote] por defecto 30. [persona] es el [persona.md] actual. El cursor
    nuevo es el [ts] mayor de los átomos dados. *)
