(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** L2 → L3: cuándo se regenera [persona.md] y con qué. Puro. *)

val max_caracteres : int
(** 2000. *)

val umbral_atomos : int
(** 50 átomos nuevos desde la última persona bastan para regenerarla. *)

val disparo :
  ultima:string option -> escenas:Escena.t list -> senal:string option -> atomos_desde:int -> string option
(** El motivo para regenerarla, o nada. Por orden: la señal
    [[ACTUALIZAR_PERSONA]] de la consolidación; escenas actualizadas
    después de [ultima] (toda escena, si no hay persona aún); o
    {!umbral_atomos} átomos consolidados desde la última. *)

val cambiadas : ultima:string option -> Escena.t list -> Escena.t list
(** Las escenas actualizadas después de [ultima] (todas, sin [ultima]). *)

val entrada : actual:string -> motivo:string -> cambiadas:Escena.t list -> resto:Escena.t list -> string
(** El mensaje para el agente [memoria-persona]. *)

val validar : string -> (string, string) result
(** La salida del agente: sin bloque de código alrededor, no vacía y de
    {!max_caracteres} como mucho. *)
