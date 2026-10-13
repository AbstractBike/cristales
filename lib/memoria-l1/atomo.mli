(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Los átomos de la memoria (L1) y los mensajes (L0) de los que salen
    (doc/memoria.md). Puro. *)

(** {1 Tipos de átomo} *)

type tipo = Persona | Regla | Hecho | Metodo | Episodio

val tipo_de_texto : string -> tipo option
(** [persona], [regla], [hecho], [metodo] (o [método]), [episodio]; sin
    distinguir mayúsculas. *)

val tipo_a_texto : tipo -> string

val umbral : tipo -> int
(** La prioridad mínima para conservar un átomo de ese tipo: por debajo es
    ruido («mejor nada que basura»). *)

val conservar : tipo -> int -> bool
(** [prioridad >= umbral tipo], o [-1] en una regla (regla global absoluta). *)

val prioridad_valida : int -> int
(** Acota a [-1..100]. *)

(** {1 Mensajes de L0} *)

type mensaje = {
  sesion : string;
  uuid : string;
  ts : int;  (** Milisegundos Unix. *)
  proyecto : string;
  rol : string;  (** [user] o [assistant]. *)
  texto : string;
}

val origen : mensaje -> string
(** [sesion/uuid]: cómo se cita un mensaje de L0 en [memoria_l1.origen]. *)

val fecha : int -> string
(** [AAAA-MM-DD] (UTC) de unos milisegundos Unix. *)

val hora : int -> string
(** [AAAA-MM-DD HH:MM] (UTC). *)

(** {1 Átomos} *)

type nuevo = {
  contenido : string;
  tipo : tipo;
  prioridad : int;
  escena : string;
  proyecto : string;
  origen : string list;  (** Mensajes de L0 de los que sale ({!origen}). *)
  fechas : string list;  (** Las de esos mensajes, ordenadas y sin repetir. *)
}
(** Un átomo recién extraído, antes del juez de duplicados. *)

type t = {
  id : string;  (** [a-<hex12>], estable entre versiones. *)
  version : int;
  vigente : bool;
  tipo : tipo;
  prioridad : int;
  escena : string;
  contenido : string;
  proyecto : string;
  origen : string list;
  fechas : string list;
}
(** Una versión de un átomo: una fila de [memoria_l1] (sin su [ts], que es
    cuándo se escribe). *)

val id_de : nuevo -> string
(** [a-] y 12 hex del digest de contenido y origen: el mismo átomo extraído
    de los mismos mensajes tiene el mismo id. *)

val de_nuevo : nuevo -> t
(** Versión 1, vigente. *)

val union : string list -> string list -> string list
(** Ordenada y sin repetir. *)
