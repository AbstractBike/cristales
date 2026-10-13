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
}

val columnas : string list
(** Las columnas de [memoria_l1] en el orden de {!fila} y {!de_fila}. *)

val de_fila : Yojson.Safe.t -> t option
(** Una fila de [/v1/sql] con las columnas en el orden de {!columnas}. *)

val vigentes : t list -> t list
(** De cada [id], la versión mayor (a igual versión, la más reciente), y
    solo si está vigente. En orden de [ts]. *)

val fechas : t -> string list
(** Las fechas del JSON [fechas]; ninguna si no se entiende. *)

val linea : t -> string
(** Una línea para el prompt: id, tipo, fechas, proyecto y contenido. *)
