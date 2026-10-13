(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La agencia a la vista: sus agentes, cómo le va a cada modelo con cada
    uno y sus encargos, en JSON. Lo usan [agencia-mcp] (las herramientas
    [agencia_agentes] y [agencia_historico]) y la API de solo lectura
    [/agencia/…] de [agencia-vista], de la que tira [agencia.pin].

    Pura salvo el archivo, que solo se lee. *)

(** {1 JSON} *)

val nivel : Agencia.nivel -> string
(** [fiable], [descartado] o [por ver]. *)

val json_cuenta : Agencia.cuenta -> Yojson.Safe.t

val json_agente :
  Agencia.Archivo.t -> Agencia.Politica.t -> ?instrucciones:bool -> Agencia.Agente.t -> Yojson.Safe.t
(** Su definición (con las instrucciones si se piden), a quién irá su
    siguiente encargo y por qué, y las cuentas de cada modelo. *)

val json_encargo : ?recorte:int -> Agencia.Encargo.t -> Yojson.Safe.t
(** La entrada recortada a [recorte] bytes y la salida a [2,5 × recorte]
    (200 y 500 por defecto). *)

val json_historico : Agencia.Archivo.t -> Agencia.Politica.t -> ?recorte:int -> ultimos:int -> Agencia.Agente.t -> Yojson.Safe.t
(** El agente con sus instrucciones, cuántos encargos lleva y los
    [ultimos], del más reciente al más antiguo. *)

(** {1 API} *)

type respuesta = { estado : int; tipo : string; cuerpo : string }

val atender :
  Agencia.Archivo.t ->
  Agencia.Politica.t ->
  meth:Http.Method.t ->
  ruta:string ->
  query:(string * string list) list ->
  respuesta option
(** Solo GET:

    {v
GET /agencia/politica                    juicios, acierto, explorar_cada
GET /agencia/agentes                     los agentes con sus cuentas
GET /agencia/agentes/{agente}?encargos=20  uno, con instrucciones y últimos encargos
    v}

    [None] si la ruta no es de [/agencia/]. *)
