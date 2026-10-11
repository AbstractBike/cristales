(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La forja como servidor MCP (contrato en [mcp/CONTRATO.md]).

    Cuatro herramientas para observarla ([forja_tareas], [forja_tarea],
    [forja_semilla], [forja_nucleacion]) y una por cristal de la vitrina.
    Al revés que el proxy: allí la forja se pone delante del LLM; aquí el
    LLM (Claude Desktop, Claude Code) la consulta y llama al cristal cuando
    lo necesita. No hay respaldo líquido: un defecto vuelve como resultado
    con [isError] y su motivo, y quien llamó (que ya es un LLM) decide.

    Puro: un mensaje JSON-RPC entra, la respuesta sale. De dónde salen los
    datos lo pone la {!fuente}; el transporte (stdio), [bin/forja-mcp]. *)

val version : string
(** Versión del protocolo MCP que se ofrece si el cliente pide una que no se
    conoce. *)

type cristal = { nombre : string; descripcion : string }

type aplicado =
  | Salida of string
  | Defecto of string
  | No_existe  (** No hay tal cristal en la vitrina. *)
  | Fallo of string  (** La forja no respondió bien; empieza por ["forja: "]. *)

type fuente = {
  cristales : unit -> (cristal list, string) result;
  aplicar : string -> string -> aplicado;  (** Tarea y entrada. *)
  consultar : (string -> (string, string) result) option;
      (** GET de una ruta de la API de introspección ([/forja/…?…]): el
          cuerpo si fue 2xx, o un error que empieza por ["forja: "]. [None]
          sin forja: no hay herramientas fijas. *)
}

val local : Forja.Vitrina.t -> fuente
(** La vitrina en el propio proceso: solo los cristales. *)

val responder : fuente -> Yojson.Safe.t -> Yojson.Safe.t option
(** Respuesta a un mensaje. [None] para las notificaciones (sin [id]). *)

val linea : fuente -> string -> string option
(** Lo mismo sobre una línea de texto, como viaja por stdio. Una línea que
    no es JSON da el error de análisis de JSON-RPC. *)
