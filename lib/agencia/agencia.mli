(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La agencia: agentes que saben a qué modelo pedir cada cosa.

    Un {e agente} es una tarea con instrucciones fijas y una {e escalera} de
    modelos, del más barato al más capaz. Cada {e encargo} (una entrada que
    se le da al agente) va al modelo que elige la agencia con el histórico
    de ese agente: el más barato que ha demostrado hacerlo bien, o el que el
    agente tiene por defecto mientras no lo sepa. De vez en cuando prueba
    uno más barato que aún no ha visto; un modelo que lo hace mal queda
    descartado para ese agente. Todo encargo, con su modelo, su salida, su
    tiempo, sus tokens y el veredicto de quien lo juzgó, queda en el
    {e archivo}: es lo que la agencia sabe.

    Es el hermano de la forja: la forja pregunta {e si} hace falta un LLM
    (y, cuando no, lo cristaliza); la agencia, {e cuál}. Los encargos pueden
    pasar por la forja, que verá cada agente como una tarea.

    Puro salvo el archivo, que se inyecta, como la cantera en la forja. *)

(** {1 Modelos} *)

module Modelo : sig
  type api = Anthropic | Openai  (** Messages o Chat Completions. *)
  type t = { nombre : string; api : api }

  val de_texto : string -> (t, string) result
  (** ["claude-haiku-5-5"] es de Anthropic; ["openai:qwen3-30b"], de un
      servidor Chat Completions (llama-server, vLLM…). *)

  val to_string : t -> string
  (** Inverso de [de_texto]. *)
end

(** {1 Agentes} *)

module Agente : sig
  type t = {
    nombre : Forja.Tarea.t;  (** [[a-z0-9-]+]: con él va a la forja. *)
    descripcion : string;
    instrucciones : string;  (** El system prompt. *)
    escalera : Modelo.t list;  (** Del más barato al más capaz; no vacía. *)
    defecto : Modelo.t;
        (** A quién se pide mientras no se sepa más: uno de la escalera. *)
    max_tokens : int;
    ejemplos : int;
        (** Cuántos encargos juzgados [bien] van como ejemplos en cada
            encargo (y si van advertencias): 0 los apaga. Ver {!Ejemplos}. *)
  }

  val crear :
    nombre:string ->
    ?descripcion:string ->
    instrucciones:string ->
    escalera:Modelo.t list ->
    ?defecto:Modelo.t ->
    ?max_tokens:int ->
    ?ejemplos:int ->
    unit ->
    (t, string) result
  (** Sin [defecto], el más capaz de la escalera; [max_tokens] 4096;
      [ejemplos] 3 (de 0 a {!ejemplos_maximo}). *)

  val ejemplos_maximo : int

  val version : t -> string
  (** 12 hex del digest de las instrucciones. Otras instrucciones son otro
      trabajo: el histórico de las anteriores no cuenta para elegir. *)
end

(** {1 Encargos} *)

type respuesta = {
  salida : (string, string) result;  (** El texto, o por qué no lo hay. *)
  fuente : string;  (** [x-forja-fuente] si pasó por la forja, o [directo]. *)
  ms : int;
  tokens_entrada : int;
  tokens_salida : int;
}
(** Lo que vuelve de pedirle algo a un modelo. *)

val sin_respuesta : string
(** La [fuente] de un encargo que no llegó al modelo (sin conexión, sin
    servidor): su error no cuenta contra el modelo. *)


type veredicto = Bien | Mal

val veredicto_de_texto : string -> veredicto option
val veredicto_a_texto : veredicto -> string

module Encargo : sig
  type t = {
    id : string;  (** 16 hex. *)
    agente : Forja.Tarea.t;
    version : string;  (** {!Agente.version} cuando se hizo. *)
    modelo : string;  (** {!Modelo.to_string}. *)
    motivo : string;  (** Por qué ese modelo. *)
    fuente : string;
        (** [x-forja-fuente] si pasó por la forja ([cristal], [liquido]…),
            o [directo]. *)
    entrada : string;
    salida : (string, string) result;  (** O el error del modelo. *)
    ms : int;
    tokens_entrada : int;
    tokens_salida : int;
    veredicto : veredicto option;
    nota : string;  (** Del veredicto. *)
  }

  val id_valido : string -> bool
end

(** {1 Archivo} *)

module Archivo : sig
  type t = {
    guardar : Agente.t -> unit;  (** Crea o redefine (gana el último). *)
    agentes : unit -> Agente.t list;  (** Por nombre. *)
    registrar : Encargo.t -> unit;
    juzgar : Forja.Tarea.t -> string -> veredicto -> string -> unit;
        (** Agente, id del encargo, veredicto y nota. Gana el último. *)
    historial : Forja.Tarea.t -> Encargo.t list;
        (** En orden de llegada, con su último veredicto. *)
  }

  val en_memoria : unit -> t
end

(** {1 Elección} *)

module Politica : sig
  type t = {
    juicios : int;  (** Veredictos antes de dar a un modelo por fiable o descartado. *)
    acierto : float;  (** Fracción de bien para ser fiable. *)
    explorar_cada : int;  (** Uno de cada [n] encargos prueba un modelo más barato. *)
  }

  val por_defecto : t
  (** 3 juicios, 0,8 de acierto, explorar 1 de cada 5. *)
end

type nivel = Fiable | Descartado | Por_ver

type cuenta = {
  modelo : Modelo.t;
  encargos : int;
  errores : int;  (** El modelo no respondió: cuentan como mal. *)
  juzgados : int;  (** Veredictos más errores. *)
  bien : int;
  ms_medio : int;
  tokens : int;  (** De entrada y salida, en total. *)
  nivel : nivel;
}

val cuentas : ?politica:Politica.t -> Agente.t -> Encargo.t list -> cuenta list
(** Una por peldaño de la escalera, en su orden, con los encargos de la
    versión actual del agente. *)

type eleccion = { modelo : Modelo.t; motivo : string }

val elegir : ?politica:Politica.t -> Agente.t -> Encargo.t list -> eleccion
(** El modelo para el siguiente encargo, con el historial del agente:

    - la base es el más barato {!Fiable}; si no hay, el [defecto] o, si
      está descartado, el siguiente más capaz que no lo esté; si no queda
      ninguno por encima, el más capaz por debajo que no lo esté; y si lo
      están todos, el más capaz;
    - uno de cada [explorar_cada] encargos va al más barato {!Por_ver} por
      debajo de la base, si lo hay. *)

(** {1 Ejemplos y advertencias}

    Lo que la agencia aprende de los veredictos, además de a qué modelo
    pedir: los encargos juzgados [bien] van como ejemplos (few-shot) en los
    siguientes, y las notas de los juzgados [mal], como advertencias. Solo
    los de la versión actual de las instrucciones. *)

module Ejemplos : sig
  type t = {
    pares : (string * string) list;
        (** Entrada y salida de encargos juzgados [bien], del menos parecido
            a la entrada al más: el más parecido queda junto a ella. *)
    advertencias : string list;  (** Notas de veredictos [mal], la más reciente primero. *)
  }

  val vacio : t
  val es_vacio : t -> bool

  type parametros = {
    presupuesto : int;  (** Bytes de todos los pares juntos. *)
    max_entrada : int;  (** Una entrada más larga se corta (y lo dice). *)
    max_advertencias : int;
    max_nota : int;  (** Bytes de cada advertencia. *)
  }

  val por_defecto : parametros
  (** 6000 de presupuesto, entradas de 1500, 3 advertencias de 500. *)

  val similitud : string -> string -> float
  (** Jaccard de los conjuntos de palabras (minúsculas, de 2 bytes o más),
      de 0 a 1. Léxica y barata: nada de embeddings. *)

  val elegir : ?parametros:parametros -> Agente.t -> Encargo.t list -> string -> t
  (** Con el historial del agente (en orden de llegada) y la entrada del
      encargo nuevo: hasta [Agente.ejemplos] pares de los encargos de la
      versión actual con salida y veredicto [bien], los más parecidos a la
      entrada y, a igualdad, los más recientes, sin repetir entrada; uno que
      no cabe en lo que queda del presupuesto se salta. Una entrada de más de
      [max_entrada] se corta si la salida es corta (no más de [max_entrada]);
      si las dos son largas (traducir, reescribir), el ejemplo se salta. Y hasta
      [max_advertencias] notas no vacías de veredictos [mal], recientes y
      sin repetir. Determinista. Con [Agente.ejemplos = 0], {!vacio}. *)

  val system : Agente.t -> t -> string
  (** Las instrucciones y, si hay advertencias, una sección
      [## Advertencias] al final. Sin advertencias, las instrucciones tal
      cual: el system solo cambia cuando llega un [mal] con nota nuevo. *)
end
