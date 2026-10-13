(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Un átomo L1 tal como lo lee la consolidación: una fila de [memoria_l1]
    (doc/memoria.md, «Contratos entre piezas»). *)

type t = {
  ts : int;  (** Milisegundos: cuándo se escribió esta versión. *)
  id : string;  (** [a-<hex12>]. *)
  version : int;
  vigente : bool;
  tipo : string;  (** [persona] | [regla] | [hecho] | [metodo] | [episodio]. *)
  prioridad : int;
  escena : string;  (** La escena propuesta al extraer. *)
  contenido : string;
  proyecto : string;
  origen : string;  (** JSON tal cual. *)
  fechas : string;  (** JSON: lista de fechas [AAAA-MM-DD]. *)
  escrito : int;
      (** Milisegundos: cuándo se escribió de verdad esta versión. [ts] es el
          del último mensaje del lote (para reescribir idempotente); el cursor
          de la consolidación va sobre [escrito] (o [ts] en filas viejas, sin
          él). *)
}

val columnas : string list
(** Las columnas de [memoria_l1] en el orden de {!fila} y {!de_fila}. *)

val de_fila : Yojson.Safe.t -> t option
(** Una fila de [/v1/sql] con las columnas en el orden de {!columnas};
    [escrito] nulo vale [ts]. *)

val vigentes : t list -> t list
(** De cada [id], la versión mayor (a igual versión, la escrita después), y
    solo si está vigente. En orden de [escrito]. *)

val fechas : t -> string list
(** Las fechas del JSON [fechas]; ninguna si no se entiende. *)

val historia : t -> bool
(** Sale de una nota importada ([origen] con [nota:]): historia, no regla
    vigente; manda lo más reciente y el CLAUDE.md. *)

(** Cómo se reconoce una etapa anterior de la flota. *)
type etapa =
  | Proyecto of string  (** Su proyecto empieza por este prefijo. *)
  | Antes_de of string  (** Su última fecha es anterior a esta ([AAAA-MM-DD]). *)

val anterior : anteriores:etapa list -> t -> bool
(** De una etapa anterior: solo puede ir a la trayectoria. *)

val linea : ?anteriores:etapa list -> t -> string
(** Una línea para el prompt: id, tipo, marca de historia o de etapa
    anterior, primera..última fecha, proyecto y contenido. *)
