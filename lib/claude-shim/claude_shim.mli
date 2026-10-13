(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** El shim de Claude Code: el subconjunto de la Messages API de Anthropic
    que usan trabajo-kt, buscarcasa-kt, coches-kt y la agencia, servido con
    {b Claude Code} ([claude -p]) y la suscripción en vez de una clave de
    pago.

    Dos formas de petición:
    - {b con herramienta} ([tools[0]], el tool use forzado de los kt): se le
      pide a Claude un único JSON conforme a su [input_schema] y vuelve
      envuelto en un bloque [tool_use];
    - {b sin herramienta} (la agencia): las instrucciones y la entrada tal
      cual, y la respuesta en un bloque [text].

    Puro: el proceso [claude] lo lanza [bin/claude-shim]. Es el puerto del
    [ClaudeCodeShim.kt] de trabajo-kt, con su misma conducta. *)

type prompt = { system : string; user : string }
(** [system] va en [--system-prompt] y [user] por stdin: el texto ajeno (una
    oferta, un CV) nunca se mezcla con nuestras instrucciones. *)

type peticion = {
  modelo : string;  (** El de la petición, tal cual: vuelve en la respuesta. *)
  alias : string;  (** [haiku], [sonnet] u [opus]: lo que entiende Claude Code. *)
  prompt : prompt;
  herramienta : (string * Yojson.Safe.t) option;  (** Nombre e [input_schema]. *)
}

val peticion : string -> (peticion, string) result
(** Lee el cuerpo de un [POST /v1/messages]. *)

val alias : string -> string
(** [claude-haiku-5-5] → [haiku]; [opus] → [opus]; lo demás, [sonnet]. *)

val argumentos : bin:string -> alias:string -> system:string -> string list
(** [claude -p] sin herramientas, sin MCP y sin skills: el modelo solo puede
    contestar. *)

val claves_esperadas : Yojson.Safe.t -> string list
(** Las claves de primer nivel de un JSON Schema. *)

val extraer_json : string -> (Yojson.Safe.t, string) result
(** El objeto JSON del texto de Claude, tolerando fences y prosa alrededor. *)

val desenvolver : Yojson.Safe.t -> string list -> Yojson.Safe.t
(** Si el modelo devolvió el eco del schema ([{"properties": {...}}]) en vez
    de la instancia, la instancia. *)

val respuesta : peticion -> id:string -> string -> (string, string) result
(** Con la salida JSON de [claude -p], el cuerpo de la respuesta Messages, o
    por qué no lo hay. *)

val motivo_fallo : err:string -> out:string -> string
(** stderr si lo hay; si no, el [result] del JSON de stdout (ahí cuenta el
    CLI «Not logged in»); si no, stdout. A lo sumo 300 bytes. *)

val autorizado : cabecera:string option -> token:string option -> bool
(** Sin token vale todo; con él, la cabecera tiene que ser esa (en tiempo
    constante). *)
