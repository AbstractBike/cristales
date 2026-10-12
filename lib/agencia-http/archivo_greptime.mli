(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** El archivo de la agencia en GreptimeDB, la base de la flota. Tres
    tablas append-only: [agencia_agentes] (cada definición; gana la última),
    [agencia_encargos] y [agencia_veredictos] (gana el último de cada
    encargo). Nada se borra: el histórico es el histórico. *)

val crear : post:Forja_http.Greptime.post -> url:Uri.t -> ?db:string -> unit -> Agencia.Archivo.t
(** [db] por defecto [agencia]; se crea al arrancar si no existe. Si
    GreptimeDB no responde, se cuenta por stderr y se sigue. *)

(** {1 Filas}

    Una fila es la lista de valores en el orden de sus columnas, como la
    devuelve [/v1/sql]. Expuestas para probarlas sin GreptimeDB. *)

val fila_agente : Agencia.Agente.t -> Yojson.Safe.t
val agente : Yojson.Safe.t -> Agencia.Agente.t option
val fila_encargo : Agencia.Encargo.t -> Yojson.Safe.t
val encargo : Yojson.Safe.t -> Agencia.Encargo.t option
