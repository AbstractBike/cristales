(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Pedirle un encargo a un modelo: Messages de Anthropic o Chat
    Completions de OpenAI, según el modelo. Cada petición lleva
    [x-forja-tarea] con el nombre del agente: si la URL es la de una forja,
    ella verá cada agente como una tarea, y cristalizará los que lo
    merezcan. *)

type destinos = {
  anthropic : Uri.t;  (** Raíz de la Messages API (o de la forja). *)
  openai : Uri.t option;  (** Raíz de un servidor Chat Completions (o de la forja). *)
  cabeceras_anthropic : (string * string) list;  (** La autenticación, tal cual. *)
  cabeceras_openai : (string * string) list;
}

val peticion : Agencia.Agente.t -> Agencia.Modelo.t -> string -> string * Yojson.Safe.t
(** La ruta y el cuerpo. *)

val leer : Agencia.Modelo.api -> Yojson.Safe.t -> (string * int * int, string) result
(** Texto, tokens de entrada y tokens de salida de una respuesta 200. *)

val llamar :
  _ Eio.Time.clock ->
  Cohttp_eio.Client.t ->
  destinos ->
  ?espera:float ->
  Agencia.Agente.t ->
  Agencia.Modelo.t ->
  string ->
  Agencia.respuesta
(** Nunca lanza: un fallo es [salida = Error]. [espera] en segundos
    (600). *)
