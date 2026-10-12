(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Lo que comparten los servidores MCP de este repo ([forja-mcp],
    [agencia-mcp]): JSON-RPC por líneas, [initialize], [tools/list] y
    [tools/call]. Puro: un mensaje entra, la respuesta sale; el transporte
    (stdio) lo pone cada binario. *)

val versiones : string list
(** Versiones del protocolo que se aceptan, la más nueva primero. *)

val version : string
(** La que se ofrece si el cliente pide una que no se conoce. *)

(** {1 Herramientas} *)

val cadena : Yojson.Safe.t
val entero : Yojson.Safe.t

val esquema : ?requeridos:string list -> (string * Yojson.Safe.t) list -> Yojson.Safe.t
(** El [inputSchema] de un objeto con esas propiedades. *)

val herramienta : string -> string -> Yojson.Safe.t -> Yojson.Safe.t
(** Nombre, descripción y esquema. *)

val texto : ?error:bool -> string -> Yojson.Safe.t
(** Resultado de [tools/call] con un bloque de texto. *)

(** {1 Llamadas} *)

type error = int * string
(** Código y mensaje JSON-RPC. *)

val invalido : string -> ('a, error) result
(** Parámetros inválidos ([-32602]). *)

val argumento : Yojson.Safe.t -> string -> (Yojson.Safe.t option, error) result
(** Un argumento de [tools/call]; [None] si no está. *)

(** {1 Servidor} *)

type servidor = {
  nombre : string;
  version : string;
  instrucciones : unit -> string;  (** Las [instructions] de [initialize]. *)
  herramientas : unit -> Yojson.Safe.t list;
  llamar : string -> Yojson.Safe.t -> (Yojson.Safe.t, error) result;
      (** Nombre de la herramienta y sus [arguments] (un objeto). *)
}

val responder : servidor -> Yojson.Safe.t -> Yojson.Safe.t option
(** Respuesta a un mensaje. [None] para las notificaciones (sin [id]). *)

val linea : servidor -> string -> string option
(** Lo mismo sobre una línea de texto, como viaja por stdio. Una línea que
    no es JSON da el error de análisis de JSON-RPC. *)
