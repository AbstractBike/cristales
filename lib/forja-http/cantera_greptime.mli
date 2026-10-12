(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cantera en GreptimeDB, la base de la flota.

    Escribe con el pipeline [greptime_identity] (JSON tal cual, sin escapar
    SQL) en una tabla append-only y lee por la API SQL por HTTP. *)

type post = Greptime.post
(** Hace un POST con ese [Content-Type] y devuelve estado y cuerpo. *)

val crear : post:post -> url:Uri.t -> ?db:string -> ?tabla:string -> unit -> Forja.Cantera.t
(** [url] es la raíz HTTP de GreptimeDB (puerto 4000). [db] por defecto
    [public] (se crea al arrancar si no existe), [tabla] por defecto
    [forja_cantera].

    Si GreptimeDB no responde, [registrar] lo cuenta por stderr y sigue: la
    respuesta al cliente no depende de la cantera. [muestras] devuelve lo
    que pueda leer (nada si la tabla aún no existe). *)

val filas : Yojson.Safe.t -> Forja.Cantera.muestra list
(** Interpreta la respuesta de la consulta de [muestras]. Expuesta para
    probarla sin GreptimeDB. *)
