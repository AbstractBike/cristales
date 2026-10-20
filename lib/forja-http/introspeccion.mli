(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La API de introspección de la forja ([/forja/…]): sus tareas, su
    vitrina, sus semillas. Es de la que tiran los servidores [forja-mcp] de
    todos los lenguajes; el formato está en [mcp/CONTRATO.md]. Pura salvo la
    cantera de la forja. *)

type respuesta = { estado : int; tipo : string; cuerpo : string }

val atender :
  ?contar:(tarea:string -> resultado:string -> unit) ->
  ?uso:(tarea:string -> Yojson.Safe.t) ->
  Forja.t -> meth:Http.Method.t -> ruta:string -> query:(string * string list) list -> string -> respuesta option
(** [None] si la ruta no es de [/forja/]. [contar] recibe cada aplicación de
    un cristal de la vitrina ([POST /forja/vitrina/{tarea}]) con su resultado,
    [cristal] o [defecto]: lo que resuelve la vitrina no pasa por el LLM ni
    deja muestra, y sin contarlo no se sabe el grado de cristalización de la
    tarea. [uso], si se da, va en cada cristal de [GET /forja/vitrina] como
    campo [uso]: lo que ha resuelto, para quien lo mira (vitrina.pin). *)
