(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Por dónde va la ingesta en cada fichero: el desplazamiento en bytes
    tras la última línea completa ya escrita. Los JSONL de Claude Code solo
    crecen; si uno encoge (se reescribió), se vuelve a empezar desde 0, y
    reingerir es idempotente. Se guarda en texto, una línea
    [<desplazamiento>\t<ruta>] por fichero. *)

type t

val vacio : unit -> t
val ruta_por_defecto : unit -> string
(** [$XDG_STATE_HOME/memoria/cursor], o [~/.local/state/memoria/cursor]. *)

val cargar : string -> t
(** Vacío si el fichero no existe o no se entiende. *)

val guardar : string -> t -> unit
(** Atómico (escribe al lado y renombra); crea el directorio. *)

val desde : t -> string -> int
val fijar : t -> string -> int -> unit
