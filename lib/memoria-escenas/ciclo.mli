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
  encargar : ?modelo:Agencia.Modelo.t -> Agencia.Agente.t -> string -> Agencia.Encargo.t;
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
  fallidos : int;  (** Lotes sin hacer: si hay alguno, el cursor no se mueve. *)
  encargos : encargo list;
}

val lotes : int -> Atomo.t list -> Atomo.t list list
(** De [n] en [n], ordenados por escena propuesta y por [ts]. *)

val consolidar :
  efectos ->
  escenas_agente:Agencia.Agente.t ->
  persona_agente:Agencia.Agente.t ->
  ?reglas:string ->
  ?anteriores:string list ->
  ?lote:int ->
  estado:Estado.t ->
  persona:string ->
  Escena.t list ->
  Atomo.t list ->
  salida
(** [reglas]: el CLAUDE.md y el AGENTS.md vigentes, que mandan sobre los
    átomos (van en cada encargo, de escenas y de persona). [anteriores]:
    prefijos de proyecto de una etapa anterior de la flota, cuyos átomos
    solo pueden ir a la trayectoria. Los átomos que ya están en los
    [atomos] de una escena actualizada después de escribirse no se
    repiten. [lote] por defecto 30. [persona] es el [persona.md] actual. El cursor
    nuevo es el [ts] mayor de los átomos dados, salvo que algún lote se
    quedara sin hacer (dos salidas inservibles, la segunda con el modelo por
    defecto del agente): entonces no se mueve y la siguiente pasada los
    repite todos. *)

val ms_de_iso : string -> int option
(** [2026-10-13T20:37:06Z] en milisegundos desde 1970 (UTC). *)
