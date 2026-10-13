(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Un checkout del repo memoria (E/S): [persona.md], [escenas/<slug>.md],
    [atomos-importados/] y [.estado]. Git lo pone quien llama. *)

val escenas : string -> (Escena.t list, string) result
(** Las de [escenas/*.md], por slug. Un fichero que no se entiende es un
    error: mejor parar que reescribirlo. *)

val persona : string -> string
(** [persona.md], o vacía. *)

val estado : string -> Estado.t

val escribir :
  string -> escenas:Escena.t list -> escritas:string list -> borradas:string list -> persona:string option -> Estado.t -> unit
(** Escribe las escenas de [escritas], borra las de [borradas] (nunca una
    bloqueada en disco), la persona si la hay y el estado. *)

val escribir_fichero : string -> string -> string -> unit
(** [escribir_fichero repo ruta texto], creando el directorio. *)
