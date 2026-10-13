(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Un checkout del repo memoria (E/S): [persona.md], [escenas/<slug>.md],
    [atomos-importados/] y [.estado]. Git lo pone quien llama. *)

val escenas : string -> Escena.t list * string list
(** Las de [escenas/*.md], por slug, y un aviso por cada una que no se
    entiende. Esas no paran la pasada: entran como bloqueadas (cuentan para
    el tope, salen en el índice y nadie las reescribe ni las borra). *)

val persona : string -> string
(** [persona.md], o vacía. *)

val estado : string -> Estado.t

val escribir :
  string -> escenas:Escena.t list -> escritas:string list -> borradas:string list -> persona:string option -> Estado.t -> unit
(** Escribe las escenas de [escritas], borra las de [borradas] (nunca una
    bloqueada en disco), la persona si la hay y el estado. *)

val escribir_fichero : string -> string -> string -> unit
(** [escribir_fichero repo ruta texto], creando el directorio. *)
