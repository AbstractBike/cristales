(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La API de introspección de la forja ([/forja/…]): sus tareas, su
    vitrina, sus semillas. Es de la que tiran los servidores [forja-mcp] de
    todos los lenguajes; el formato está en [mcp/CONTRATO.md]. Pura salvo la
    cantera de la forja. *)

type respuesta = { estado : int; tipo : string; cuerpo : string }

val atender :
  Forja.t -> meth:Http.Method.t -> ruta:string -> query:(string * string list) list -> string -> respuesta option
(** [None] si la ruta no es de [/forja/]. *)
