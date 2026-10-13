(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** [memoria_l1] en GreptimeDB (E/S). Todas las columnas van entre
    comillas: [id] y [version] son palabras reservadas de su SQL. *)

val crear_tabla : Forja_http.Greptime.t -> (unit, string) result
(** [CREATE TABLE IF NOT EXISTS] con el esquema de doc/memoria.md
    ([contenido] con índice FULLTEXT, clave [id], índice de tiempo [ts]). *)

val desde : Forja_http.Greptime.t -> int -> Atomo.t list
(** Los átomos vigentes con alguna versión escrita después de ese [ts]
    (ms), en su última versión ({!Atomo.vigentes}). *)

val ids : Forja_http.Greptime.t -> string list
(** Los ids que ya hay en la tabla. *)

val insertar_sql : Atomo.t list -> string
(** Un [INSERT] con todas esas filas (expuesto para probarlo). *)

val insertar : Forja_http.Greptime.t -> Atomo.t list -> (int, string) result
(** De 50 en 50; las filas escritas. *)
