(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Los dos agentes de la agencia que usa la consolidación. Sus
    instrucciones son los prompts de [prompts/] (van dentro del binario):
    cambiarlos es otra versión del agente, y la agencia vuelve a aprender. *)

val escenas : escalera:Agencia.Modelo.t list -> Agencia.Agente.t
(** [memoria-escenas]: átomos → operaciones sobre escenas (JSON). *)

val persona : escalera:Agencia.Modelo.t list -> Agencia.Agente.t
(** [memoria-persona]: escenas cambiadas → [persona.md]. *)

val asegurar : Agencia.Archivo.t -> Agencia.Agente.t -> unit
(** Lo guarda en el archivo si no está, o si sus instrucciones, su
    escalera o su modelo por defecto han cambiado. *)
