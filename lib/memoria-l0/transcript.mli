(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Una línea del JSONL de Claude Code ([~/.claude/projects/*/*.jsonl] y los
    subagentes en [*/<sesion>/subagents/agent-*.jsonl]) a un mensaje de L0.

    Solo cuentan [user] y [assistant]; lo demás ([attachment], [system],
    [ai-title], [summary], [queue-operation]…) se descarta. Limpieza
    (doc/memoria.md):
    - Fuera los mensajes [isMeta] y los resúmenes de compactación.
    - Fuera los [tool_result] enteros, las imágenes y el [thinking].
    - Cada [tool_use], una línea [[herramienta <nombre>: <descripción>]]
      (su [description] o, si no tiene, su primer campo corto), nunca su
      entrada.
    - Fuera los bloques [<system-reminder>], [<command-*>],
      [<local-command-*>], [<bash-stdout>], [<task-notification>]… (la
      salida de comandos y lo que inyecta el arnés).
    - Lo que queda vacío no es mensaje.
    - Se redacta ({!Redaccion}) y luego se trunca a {!max_bytes}. *)

type mensaje = {
  ts : string;  (** El [timestamp] tal cual (RFC 3339, UTC). *)
  sesion : string;  (** [sessionId]; el de la sesión padre en un subagente. *)
  uuid : string;
  agente : string;  (** [agentId] del subagente; [""] en la sesión principal. *)
  proyecto : string;  (** [cwd] *)
  rol : string;  (** [user] | [assistant] *)
  texto : string;  (** Limpio, redactado y truncado. *)
  redacciones : (Redaccion.tipo * int) list;
  truncado : bool;
}

val max_bytes : int
(** 8 KiB. *)

val limpiar : string -> string
(** Quita los bloques del arnés y recorta espacios. *)

val truncar : string -> string * bool
(** A {!max_bytes} sin partir un carácter UTF-8, con marca
    [[…truncado, N bytes]]. *)

val herramienta : string -> Yojson.Safe.t -> string
(** La línea de un [tool_use] a partir de su nombre y su [input]. *)

val de_linea : ?al_redactar:(Redaccion.tipo -> antes:string -> string -> unit) -> string -> mensaje option
(** [None] si la línea no es JSON, no es un mensaje o queda vacía.
    [al_redactar], como en {!Redaccion.redactar}. *)
