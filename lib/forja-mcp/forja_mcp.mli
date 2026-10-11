(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La vitrina como servidor MCP: cada cristal es una herramienta.

    Al revés que el proxy: allí la forja se pone delante del LLM; aquí el LLM
    (Claude Desktop, Claude Code) llama al cristal cuando lo necesita. No hay
    respaldo líquido: un defecto vuelve como error de herramienta con su
    motivo, y quien llamó (que ya es un LLM) decide qué hacer.

    Puro: un mensaje JSON-RPC entra, la respuesta sale. El transporte (stdio)
    lo pone [bin/forja-mcp]. *)

val version : string
(** Versión del protocolo MCP que se ofrece si el cliente pide una que no se
    conoce. *)

val responder : Forja.Vitrina.t -> Yojson.Safe.t -> Yojson.Safe.t option
(** Respuesta a un mensaje. [None] para las notificaciones (sin [id]). *)

val linea : Forja.Vitrina.t -> string -> string option
(** Lo mismo sobre una línea de texto, como viaja por stdio. Una línea que
    no es JSON da el error de análisis de JSON-RPC. *)
