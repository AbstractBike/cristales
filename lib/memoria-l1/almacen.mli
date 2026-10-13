(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Las tablas de la memoria en GreptimeDB (doc/memoria.md): lee
    [memoria_l0], lee y escribe [memoria_l1] y el cursor de cada sesión
    ([memoria_cursor]). Todo por la API SQL ({!Forja_http.Greptime}).

    [memoria_cursor] — append-only; el vigente de cada sesión es el de [ts]
    mayor.

    | Columna | Tipo | Nota |
    |---|---|---|
    | [ts] | TIMESTAMP TIME INDEX | cuándo se escribió |
    | [sesion] | STRING PRIMARY KEY | |
    | [hasta] | INT64 | [ts] (ms) del último mensaje de L0 destilado |
    | [escena] | STRING | la última escena, que hereda el siguiente lote | *)

type t

val crear : Forja_http.Greptime.t -> t
(** Crea [memoria_l1] y [memoria_cursor] si no existen ([memoria_l0] es de
    la ingesta). *)

(** {1 SQL} (expuesto para probarlo) *)

val literal : string -> string
(** Entre comillas simples, con las comillas dobladas (en GreptimeDB la
    barra invertida no escapa). *)

val ms : Yojson.Safe.t -> int option
(** Un timestamp de [/v1/sql] en milisegundos: entero en ms, µs o ns (por
    magnitud), o texto ISO 8601 no; [None] si no se entiende. *)

val atomo : Yojson.Safe.t -> Atomo.t option
(** Una fila de {!columnas_l1}. *)

val columnas_l1 : string
(** Las columnas de [memoria_l1] (sin [ts]), en el orden de {!atomo}. *)

val valores : ts:int -> Atomo.t -> string
(** La tupla [(...)] de un INSERT en [memoria_l1] con [ts] y {!columnas_l1}. *)

(** {1 Lectura} *)

val sesiones : t -> inactiva_min:int -> (string * int) list
(** Las sesiones de L0 sin mensajes en los últimos [inactiva_min] minutos
    y con algo posterior a su cursor, con su último [ts]. *)

val cursor : t -> string -> (int * string option) option
(** El cursor de una sesión ([hasta] y escena), si tiene. *)

val mensajes : t -> sesion:string -> cursor:int option -> fondo:int -> Atomo.mensaje list
(** Los mensajes posteriores al cursor y, de los anteriores, los últimos
    [fondo] (para sacar de ellos el fondo útil). *)

val candidatos : t -> ?n:int -> ?por_termino:int -> Atomo.nuevo -> Atomo.t list
(** Los [n] (5) átomos vigentes más parecidos: una consulta [matches] por
    término ({!Dedup.terminos}), [por_termino] (20) filas cada una, por
    prioridad y recencia, fusionadas por RRF. *)

(** {1 Escritura} *)

val escribir : t -> ts:int -> Atomo.t list -> (unit, string) result
(** Un INSERT con todas las filas; cada una con un ms más que la anterior,
    para que dos versiones del mismo id no colisionen. *)

val guardar_cursor : t -> ts:int -> sesion:string -> hasta:int -> escena:string option -> (unit, string) result
