(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** L1 → L2: qué se le enseña al agente [memoria-escenas] y cómo se
    aplican sus operaciones. Puro.

    Las reglas que el prompt pide, el código las hace cumplir: tope de 15
    escenas (a 12 se recomienda actualizar o fusionar, a 14 se rechaza
    crear, a 15 hay que fusionar), como mucho {!max_crear} [crear] por lote,
    nunca se toca una escena bloqueada y solo se actualiza o fusiona lo que
    el agente tuvo delante. *)

val tope : int
(** 15. *)

val max_crear : int
(** 2 por lote. *)

val aviso : int -> string option
(** El aviso escalonado para tantas escenas: nada por debajo de 12. *)

val puede_crear : int -> bool
(** Con tantas escenas, ¿se admite una más? Solo por debajo de 14. *)

(** {1 Qué se le enseña} *)

val palabras : string -> string list
(** Las palabras con contenido de un texto, en minúsculas y sin repetir. *)

val abiertas : Escena.t list -> Atomo.t list -> string list
(** Los slugs de las escenas más parecidas a los átomos (3, o 5 desde 12
    escenas, para que haya qué fusionar), sin las bloqueadas, de más a menos
    parecida. *)

val entrada :
  ?reglas:string ->
  ?anteriores:Atomo.etapa list ->
  ahora:string ->
  escenas:Escena.t list ->
  abiertas:string list ->
  Atomo.t list ->
  string
(** El mensaje para el agente: reglas vigentes (el CLAUDE.md y el AGENTS.md
    de hoy, que mandan), aviso, índice, escenas abiertas enteras, átomos
    nuevos (con su marca de historia o de etapa anterior, ver
    {!Atomo.linea}) y hora. *)

val reintento : entrada:string -> salida:string -> string list -> string
(** El mensaje para repetir: la entrada, la respuesta y los rechazos. *)

(** {1 Cómo se aplica} *)

type resultado = {
  escenas : Escena.t list;  (** El conjunto entero después, por slug. *)
  escritas : string list;  (** Slugs creados o reescritos. *)
  borradas : string list;  (** Slugs que ya no existen (fusionados). *)
  aplicadas : Operacion.t list;
  rechazos : (Operacion.t * string) list;  (** Con el motivo. *)
  recortadas : string list;
      (** Slugs cuyo cuerpo se pasaba hasta un 25 % y se recortó por líneas
          desde el final; más allá, la operación se rechaza. *)
}

val aplicar :
  ahora:string ->
  abiertas:string list ->
  nuevos:Atomo.t list ->
  Escena.t list ->
  Operacion.t list ->
  resultado
(** Primero las fusiones (liberan sitio), luego las actualizaciones y al
    final las creaciones; las que incumplen una regla se rechazan con su
    motivo y no cambian nada. Los [atomos] de cada operación se filtran a
    los ids de [nuevos] y se unen a los de la escena. *)
