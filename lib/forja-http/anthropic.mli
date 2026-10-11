(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

(** Traducción entre la Messages API de Anthropic y las peticiones de la
    forja. Pura. *)

val cabecera_tarea : string
(** [x-forja-tarea]: nombre explícito de la tarea. Sin ella, la tarea se
    deriva del system prompt. *)

val peticion :
  tarea:string option -> Yojson.Safe.t -> (Forja.peticion, string) result
(** [Ok] si la petición es una tarea cristalizable: un solo turno de usuario
    con texto, instrucciones en [system] (o tarea explícita), sin
    herramientas y sin streaming. [Error motivo] en otro caso: la petición
    pasa al LLM sin que la forja la toque. *)

val texto : Yojson.Safe.t -> string option
(** Texto de una respuesta del LLM que terminó en [end_turn]. *)

val respuesta : modelo:string -> string -> Yojson.Safe.t
(** Respuesta en formato Messages con el texto que dio el cristal. *)

val error : tipo:string -> string -> Yojson.Safe.t
