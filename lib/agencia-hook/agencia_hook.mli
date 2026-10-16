(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Los hooks de Claude Code de la agencia (doc/agencia.md, «Hooks»): que
    las sesiones la usen y juzguen lo que le encargan. Puro: la red y los
    ficheros los pone [bin/agencia-hook]. *)

val contexto : (string * string) list -> string option
(** SessionStart: el JSON del hook con el catálogo de agentes (nombre y
    descripción, en el orden dado) y cuándo encargarles. [None] sin
    agentes. *)

val pendientes : Yojson.Safe.t list -> (string * string) list
(** De las líneas de una transcripción, los encargos (agente, id) cuyo
    resultado vio la sesión y que no juzgó con [agencia_juzgar], en orden
    de llegada y sin repetir. *)

val bloqueo : (string * string) list -> string option
(** Stop: el JSON que para la sesión una vez para pedir los veredictos.
    [None] si no hay pendientes. *)
