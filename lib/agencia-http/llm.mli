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

val peticion :
  ?contexto:Agencia.Ejemplos.t -> Agencia.Agente.t -> Agencia.Modelo.t -> string -> string * Yojson.Safe.t
(** La ruta y el cuerpo. Con [contexto], el system lleva las advertencias
    al final y los ejemplos van como turnos previos (usuario: su entrada;
    asistente: su salida) antes de la entrada; en Messages el system va
    marcado con [cache_control]. Sin él (o vacío), la petición de siempre. *)

val leer : Agencia.Modelo.api -> Yojson.Safe.t -> (string * int * int, string) result
(** Texto, tokens de entrada (con los de la caché de prompts, leídos o
    escritos) y tokens de salida de una respuesta 200. *)

val llamar :
  _ Eio.Time.clock ->
  Cohttp_eio.Client.t ->
  destinos ->
  ?espera:float ->
  ?archivo:Agencia.Archivo.t ->
  Agencia.Agente.t ->
  Agencia.Modelo.t ->
  string ->
  Agencia.respuesta
(** Nunca lanza: un fallo es [salida = Error]. [espera] en segundos
    (600). Con [archivo], cada encargo lleva los ejemplos y advertencias
    del historial del agente ({!Agencia.Ejemplos.elegir}). *)
