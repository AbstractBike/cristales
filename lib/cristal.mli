(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristalización de pipelines de IA.

    Una etapa es {e líquida} (un LLM en cada llamada), {e sombra} (responde el
    LLM y el cristal corre a su lado para compararse), {e mixta} (cristal con
    respaldo líquido) o {e cristalina} (código determinista que un LLM escribió
    una vez). Las etapas se componen en pipelines con [>>>].

    Todo es estilo directo: con OCaml 5 la llamada al LLM de una etapa líquida
    es una función normal que puede bloquear una fibra de Eio sin mónadas. *)

(** {1 Cristales} *)

type motivo = string
(** Por qué un cristal no sabe tratar una entrada. *)

type ('i, 'o) forma = { entrada : 'i -> string; salida : 'o -> string }
(** Cómo se escriben en el registro la entrada y la salida de una etapa. Es
    obligatoria: una etapa cuya entrada no se registra no deja semillas.
    Dos salidas son iguales para la sombra si se escriben igual. *)

type ('i, 'o) cristal = {
  nombre : string;
  forma : ('i, 'o) forma;
  aplicar : 'i -> ('o, motivo) result;
      (** Pura. [Error] es un defecto declarado, no un fallo. *)
}

val cristal :
  string -> ('i, 'o) forma -> ('i -> ('o, motivo) result) -> ('i, 'o) cristal

val texto : (string, string) forma
(** Entrada y salida tal cual: la forma de un cristal de texto a texto. *)

(** {1 Etapas} *)

type ('i, 'o) etapa =
  | Liquida of { nombre : string; forma : ('i, 'o) forma; llm : 'i -> 'o }
  | Sombra of { cristal : ('i, 'o) cristal; llm : 'i -> 'o }
      (** Responde el LLM; el cristal se ejecuta a la vez y se compara. *)
  | Mixta of { cristal : ('i, 'o) cristal; llm : 'i -> 'o }
  | Cristalina of ('i, 'o) cristal

type fase = [ `Liquida | `Sombra | `Mixta | `Cristalina ]

val liquida : string -> ('i, 'o) forma -> ('i -> 'o) -> ('i, 'o) etapa
val sombra : ('i, 'o) cristal -> ('i -> 'o) -> ('i, 'o) etapa
val mixta : ('i, 'o) cristal -> ('i -> 'o) -> ('i, 'o) etapa
val cristalina : ('i, 'o) cristal -> ('i, 'o) etapa

val nombre : ('i, 'o) etapa -> string
val fase : ('i, 'o) etapa -> fase

val solidificar : ('i, 'o) etapa -> ('i, 'o) etapa
(** Un paso hacia el cristal: [Sombra] pasa a [Mixta] y [Mixta] a
    [Cristalina]. [Liquida] no tiene cristal y [Cristalina] ya lo es. *)

val fundir : ('i, 'o) etapa -> ('i, 'o) etapa
(** [Sombra] y [Mixta] pasan a [Liquida] con el LLM que tuvieran. Una
    [Cristalina] no tiene LLM, así que se deja tal cual. *)

(** {1 Pipelines} *)

type ('i, 'o) t

val etapa : ('i, 'o) etapa -> ('i, 'o) t
val ( >>> ) : ('i, 'm) t -> ('m, 'o) t -> ('i, 'o) t

(** Qué pasó con una entrada en una etapa. Hay exactamente un evento por
    entrada y etapa ejecutada, y lleva la entrada escrita con la [forma] de la
    etapa: es la línea del registro (ver [doc/registro.md]). *)
type evento =
  | Por_cristal of { etapa : string; entrada : string; salida : string }
      (** El cristal resolvió; no hubo LLM. *)
  | Por_liquido of { etapa : string; entrada : string; salida : string }
      (** La etapa es líquida; resolvió el LLM. *)
  | Defecto of {
      etapa : string;
      entrada : string;
      motivo : motivo;
      liquido : string option;
    }
      (** El cristal declaró un defecto. En [Mixta] le sigue el LLM y
          [liquido] es lo que respondió: el par entrada → salida es semilla
          para recristalizar. En [Cristalina] es [None]. *)
  | Comparado of {
      etapa : string;
      entrada : string;
      liquido : string;
      cristal : (string, motivo) result;
    }
      (** Etapa [Sombra]: respondió el LLM y el cristal dio [cristal]. *)

val etapa_de : evento -> string

type fallo = { etapa : string; motivo : motivo }
(** Defecto en una etapa [Cristalina]: no hay LLM al que caer. *)

val ejecutar : ?observar:(evento -> unit) -> ('i, 'o) t -> 'i -> ('o, fallo) result

val etapas : ('i, 'o) t -> (string * fase) list
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

  val acuerdo : t -> string -> float option
  (** Solo en [Sombra]: fracción de entradas en que el cristal respondió lo
      mismo que el LLM. Un defecto cuenta como desacuerdo. [None] si la etapa
      no ha pasado por sombra. *)

  val etapas : t -> string list
  (** Etapas vistas, en orden alfabético. *)
end
