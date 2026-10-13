(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** El SQL de las búsquedas sobre [memoria_l0] y [memoria_l1] (doc/memoria.md).
    Puro: arma las sentencias y ordena las filas; quien llama las ejecuta.

    Lo que pone quien busca nunca llega crudo al SQL: la consulta se parte
    en términos de letras y dígitos ({!terminos}), y los demás textos van
    como literales escapados ({!literal}). En GreptimeDB la barra invertida
    escapa dentro de un literal, así que se quita. *)

type tablas = { l0 : string; l1 : string }

val literal : string -> string
(** ['…'] con las comillas dobladas, sin barras invertidas ni controles. *)

val terminos : string -> string list
(** Los términos de una consulta en minúsculas, sin repetir, como mucho 12;
    todo lo que no es letra o dígito separa. *)

val fecha : string -> (string, string) result
(** [AAAA-MM-DD] o [AAAA-MM-DD HH:MM[:SS]] (o con [T]) como timestamp de
    GreptimeDB ([AAAA-MM-DD HH:MM:SS]). *)

val tipos : string list
(** Los de L1: [persona], [regla], [hecho], [metodo], [episodio]. *)

val atomos :
  tablas -> terminos:string list -> ?tipo:string -> ?proyecto:string -> unit -> string
(** Las versiones vigentes ([vigente = true]) que casan con algún término;
    hay que quedarse luego con las de versión máxima ({!ultimas}). *)

val ultimas : tablas -> string list -> string
(** La versión máxima de cada uno de esos ids, vigente o no. *)

val mensajes : tablas -> terminos:string list -> ?proyecto:string -> ?desde:string -> unit -> string

val aciertos : string list -> string -> int
(** Cuántos términos distintos aparecen en el texto (en minúsculas). *)

val minusculas : string -> string
(** ASCII y las mayúsculas acentuadas del español. *)

val extracto : ?ancho:int -> string list -> string -> string
(** Un trozo del texto alrededor del primer término que aparezca. *)
