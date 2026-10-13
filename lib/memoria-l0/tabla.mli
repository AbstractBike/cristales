(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La tabla [memoria_l0] en SQL de GreptimeDB (doc/memoria.md).

    Clave [(sesion, "uuid")] con [ts] como índice de tiempo: el motor mito
    deduplica por clave e índice de tiempo (última escritura gana), así que
    reingerir un mensaje lo sobrescribe en vez de duplicarlo. No es
    [append_mode], que sí duplicaría. [uuid] es palabra reservada en el SQL
    de GreptimeDB: hay que citarla siempre, ["uuid"].

    Se escribe con [INSERT] de varias filas por [/v1/sql] y no por
    [/v1/ingest]: el pipeline [greptime_identity] crea su propio esquema
    (índice [greptime_timestamp], sin clave ni índice fulltext) y aquí la
    clave es lo que da la idempotencia. En los literales de GreptimeDB la
    barra invertida no escapa nada: basta doblar la comilla simple. *)

val nombre : string
(** [memoria_l0] *)

val crear : string
(** [CREATE TABLE IF NOT EXISTS memoria_l0 …], con [texto] en un índice
    fulltext (tantivy, analizador inglés, sin distinguir mayúsculas) para
    [matches(texto, '…')]. *)

val literal : string -> string
(** Entre comillas simples, con las simples dobladas y sin NUL. *)

val insertar : nodo:string -> Transcript.mensaje list -> string
(** Un [INSERT] con una fila por mensaje. La lista no debe ser vacía. *)

val lotes : ?max_filas:int -> ?max_bytes:int -> Transcript.mensaje list -> Transcript.mensaje list list
(** Parte en lotes de hasta [max_filas] (500) y unos [max_bytes] de texto
    (1 MiB), en orden. *)
