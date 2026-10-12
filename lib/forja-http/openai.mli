(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Traducción entre el Chat Completions de OpenAI (el que sirven
    llama-server, vLLM y compañía) y las peticiones de la forja. Pura; la
    misma interfaz que {!Anthropic}. *)

(** Qué devuelve la tarea. *)
type forma =
  | Texto  (** El contenido del mensaje. *)
  | Esquema
      (** El objeto que impone [response_format = {type: json_schema}]: la
          salida es su JSON. La forma de las pipelines con salida
          estructurada sobre un modelo local. *)

val peticion :
  tarea:string option -> Yojson.Safe.t -> (Forja.peticion * forma, string) result
(** [Ok] si es una tarea cristalizable: a lo sumo un mensaje [system] (o
    [developer]) y un turno de usuario, con texto; sin streaming, sin
    herramientas, una sola respuesta, y sin [response_format] o con un
    [json_schema]. La plantilla es el [system] y, si lo hay, el esquema. *)

val salida : forma -> Yojson.Safe.t -> string option
(** La salida de una respuesta del LLM que terminó en [stop]: el texto, o
    el objeto JSON en forma canónica. *)

val respuesta : modelo:string -> forma -> string -> (Yojson.Safe.t, string) result
(** Una [chat.completion] con la salida de un cristal. [Error] si la forma
    es [Esquema] y la salida no es un objeto JSON. *)

val error : tipo:string -> string -> Yojson.Safe.t

(** {1 Cristales parciales} *)

val campos : Yojson.Safe.t -> string list
(** Las propiedades del [json_schema] de una petición; [[]] sin él. *)

val restringir : Yojson.Safe.t -> string list -> Yojson.Safe.t
(** La petición con el esquema reducido a esos campos. *)

val uso : Yojson.Safe.t -> (int * int) option
(** Tokens de entrada y de salida de una respuesta ([usage]). *)
