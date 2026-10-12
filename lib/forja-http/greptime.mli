(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** GreptimeDB por HTTP, la base de la flota: escribir JSON tal cual en
    tablas append-only (pipeline [greptime_identity]) y leer por la API SQL.
    Lo usan la cantera de la forja y el histórico de la agencia. *)

type post = Uri.t -> tipo:string -> string -> (int * string, string) result
(** Hace un POST con ese [Content-Type] y devuelve estado y cuerpo. *)

type t

val conectar : post:post -> url:Uri.t -> db:string -> t
(** [url] es la raíz HTTP de GreptimeDB (puerto 4000). Crea la base si no
    existe (desde [public], que siempre existe); las tablas las crea la
    primera ingesta. *)

val ingerir : t -> tabla:string -> Yojson.Safe.t -> unit
(** Una fila (un objeto JSON). Si GreptimeDB no responde, lo cuenta por
    stderr y sigue. *)

val sql : t -> string -> (int * string, string) result
(** Una sentencia en la base, tal cual. *)

val leer : t -> string -> Yojson.Safe.t list
(** Las filas de una consulta; nada si falla (la tabla aún no existe). *)

val crudas : Yojson.Safe.t -> Yojson.Safe.t list
(** Las filas de una respuesta de [/v1/sql]. *)

val lineas : t -> string -> unit
(** Puntos en el protocolo de línea de InfluxDB, uno por línea: las
    etiquetas son columnas de la clave de la tabla, así que se pueden
    agrupar por PromQL. Si GreptimeDB no responde, lo cuenta y sigue. *)
