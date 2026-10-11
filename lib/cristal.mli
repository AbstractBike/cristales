(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristalización de pipelines de IA.

    Una etapa es {e líquida} (un LLM en cada llamada), {e cristalina} (código
    determinista que un LLM escribió una vez) o {e mixta} (cristal con respaldo
    líquido). Las etapas se componen en pipelines con [>>>].

    Todo es estilo directo: con OCaml 5 la llamada al LLM de una etapa líquida
    es una función normal que puede bloquear una fibra de Eio sin mónadas. *)

(** {1 Cristales} *)

type motivo = string
(** Por qué un cristal no sabe tratar una entrada. *)

type ('i, 'o) cristal = {
  nombre : string;
  aplicar : 'i -> ('o, motivo) result;
      (** Pura. [Error] es un defecto declarado, no un fallo. *)
}

val cristal : string -> ('i -> ('o, motivo) result) -> ('i, 'o) cristal

(** {1 Etapas} *)

type ('i, 'o) etapa =
  | Liquida of { nombre : string; llm : 'i -> 'o }
  | Mixta of { cristal : ('i, 'o) cristal; llm : 'i -> 'o }
  | Cristalina of ('i, 'o) cristal

val liquida : string -> ('i -> 'o) -> ('i, 'o) etapa
val mixta : ('i, 'o) cristal -> ('i -> 'o) -> ('i, 'o) etapa
val cristalina : ('i, 'o) cristal -> ('i, 'o) etapa

val nombre : ('i, 'o) etapa -> string

val solidificar : ('i, 'o) etapa -> ('i, 'o) etapa
(** [Mixta] pasa a [Cristalina]; el resto no cambia. *)

val fundir : ('i, 'o) etapa -> ('i, 'o) etapa
(** [Cristalina] y [Mixta] pasan a [Liquida] con el LLM que tuvieran. Una
    [Cristalina] no tiene LLM, así que se deja tal cual. *)

(** {1 Pipelines} *)

type ('i, 'o) t

val etapa : ('i, 'o) etapa -> ('i, 'o) t
val ( >>> ) : ('i, 'm) t -> ('m, 'o) t -> ('i, 'o) t

(** Qué resolvió cada entrada en cada etapa. *)
type evento =
  | Por_cristal of string  (** El cristal resolvió; no hubo LLM. *)
  | Por_liquido of string  (** La etapa es líquida; resolvió el LLM. *)
  | Defecto of string * motivo
      (** El cristal declaró un defecto. En [Mixta] le sigue el LLM; es
          semilla para recristalizar. *)

type fallo = { etapa : string; motivo : motivo }
(** Defecto en una etapa [Cristalina]: no hay LLM al que caer. *)

val ejecutar : ?observar:(evento -> unit) -> ('i, 'o) t -> 'i -> ('o, fallo) result

val etapas : ('i, 'o) t -> (string * [ `Liquida | `Mixta | `Cristalina ]) list
(** Estado de cada etapa, en orden. *)

(** {1 Medida} *)

module Medidor : sig
  type t

  val crear : unit -> t
  val observar : t -> evento -> unit

  val grado : t -> string -> float option
  (** Fracción de entradas de la etapa resueltas sin LLM. [None] si no ha
      visto ninguna. *)

  val grado_total : t -> float option
  (** Lo mismo sobre todas las etapas: el grado de cristalización de la
      pipeline. *)
end
