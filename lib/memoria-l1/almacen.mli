(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Las tablas de la memoria en GreptimeDB (doc/memoria.md): lee
    [memoria_l0], lee y escribe [memoria_l1] y el cursor de cada sesión
    ([memoria_cursor]). Todo por la API SQL ({!Forja_http.Greptime}).

    Toda lectura devuelve [Error] si GreptimeDB falla: un error nunca se
    confunde con «no hay nada» (sin cursor, sin mensajes), que llevaría a
    reprocesar o a saltarse una sesión.

    [memoria_cursor] — append-only; el vigente de cada sesión es el de [ts]
    mayor.

    | Columna | Tipo | Nota |
    |---|---|---|
    | [ts] | TIMESTAMP TIME INDEX | cuándo se escribió |
    | [sesion] | STRING PRIMARY KEY | |
    | [hasta] | INT64 | [ts] (ms) del último mensaje de L0 destilado |
    | [escena] | STRING | la última escena, que hereda el siguiente lote |
    | [fallos] | INT | pasadas seguidas en que el lote siguiente salió ilegible |

    Las filas de [memoria_l1] que escribe un lote llevan [ts = hasta + i]
    (el [ts] del último mensaje del lote, más su orden), no la hora de
    escritura: así reescribir un lote cuyo cursor no llegó a guardarse cae
    en las mismas claves ([id], [ts]) y {!escrito} lo reconoce. *)

type t

val crear : Forja_http.Greptime.t -> t
(** Crea [memoria_l1] y [memoria_cursor] si no existen ([memoria_l0] es de
    la ingesta). *)

(** {1 SQL} (expuesto para probarlo) *)

val literal : string -> string
(** Entre comillas simples, con las comillas dobladas (en GreptimeDB 1.2 la
    barra invertida de un literal llega tal cual: comprobado). *)

val ms : Yojson.Safe.t -> int option
(** Un timestamp de [/v1/sql] en milisegundos: entero en ms, µs o ns (por
    magnitud); [None] si no es un número. *)

val atomo : Yojson.Safe.t -> Atomo.t option
(** Una fila de {!columnas_l1}. *)

val columnas_l1 : string
(** Las columnas de [memoria_l1] (sin [ts]), en el orden de {!atomo}. *)

val valores : ts:int -> Atomo.t -> string
(** La tupla [(...)] de un INSERT en [memoria_l1] con [ts] y {!columnas_l1}. *)

val cursor_de_fila : Yojson.Safe.t -> (string * Lote.cursor) option
(** Una fila de la consulta de {!cursores}. *)

(** {1 Lectura} *)

val cursores : t -> ((string * Lote.cursor) list, string) result
(** El cursor vigente de cada sesión, en una sola consulta agregada. *)

val sesiones :
  t -> cursores:(string * Lote.cursor) list -> inactiva_min:int -> desde:int -> ((string * int) list, string) result
(** Las sesiones de L0 sin mensajes en los últimos [inactiva_min] minutos,
    con actividad desde [desde] (ms) y con algo posterior a su cursor, con
    su último [ts]. *)

val mensajes : t -> sesion:string -> cursor:int option -> fondo:int -> (Atomo.mensaje list, string) result
(** Los mensajes posteriores al cursor y, de los anteriores, los últimos
    [fondo] (para sacar de ellos el fondo útil). *)

val candidatos : t -> ?n:int -> ?por_termino:int -> Atomo.nuevo -> (Atomo.t list, string) result
(** Los [n] (5) átomos vigentes más parecidos: una consulta
    [matches(lower(contenido), '"término"')] por término
    ({!Dedup.terminos}), [por_termino] (20) filas cada una, por prioridad y
    recencia, fusionadas por RRF. *)

val escrito : t -> sesion:string -> hasta:int -> (bool, string) result
(** Si ese lote ya escribió filas (entre [hasta] y [hasta + 999] con origen
    en la sesión): su cursor falló después de escribir. *)

(** {1 Escritura} *)

val escribir : t -> hasta:int -> Atomo.t list -> (unit, string) result
(** Un INSERT con todas las filas, la [i]-ésima con [ts = hasta + i]. *)

val guardar_cursor : t -> ts:int -> sesion:string -> Lote.cursor -> (unit, string) result
