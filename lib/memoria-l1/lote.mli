(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Los lotes de una sesión: qué mensajes de L0 van al siguiente encargo de
    extracción, con cuáles de fondo, y hasta dónde avanza el cursor. Puro.

    El cursor de una sesión es el [ts] del último mensaje ya destilado: lo
    que tenga un [ts] mayor está por destilar. Así reprocesar es idempotente
    y una pasada interrumpida se retoma donde quedó. *)

val util : Atomo.mensaje -> bool
(** Si el mensaje dice algo: no está vacío ni es solo líneas
    [[herramienta …]]. Los que no, no cuentan para el lote ni van de fondo
    (pero el cursor pasa por encima). *)

type cursor = {
  hasta : int;  (** [ts] del último mensaje destilado. *)
  escena : string option;  (** La última escena, que hereda el siguiente lote. *)
  fallos : int;  (** Pasadas seguidas en que el lote siguiente salió ilegible. *)
}
(** El cursor de una sesión, como se guarda en [memoria_cursor]. *)

type t = {
  fondo : Atomo.mensaje list;  (** Útiles anteriores al lote, solo contexto. *)
  nuevos : Atomo.mensaje list;  (** Útiles, de los que se extrae. *)
  hasta : int;  (** El cursor tras destilarlo. *)
}

type paso =
  | Nada  (** No hay nada después del cursor. *)
  | Avanzar of int  (** Solo hay mensajes inútiles: el cursor pasa a este [ts]. *)
  | Lote of t

val siguiente : ?nuevos:int -> ?fondo:int -> cursor:int option -> Atomo.mensaje list -> paso
(** Con los mensajes de la sesión (en cualquier orden; basta con que estén
    los [fondo] útiles anteriores al cursor), el siguiente paso: hasta
    [nuevos] (10) útiles posteriores al cursor y los [fondo] (5) útiles
    anteriores al primero. Los mensajes con el mismo [ts] no se separan:
    el lote se alarga hasta incluirlos todos. *)
