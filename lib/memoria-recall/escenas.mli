(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Lectura del repo [memoria] (doc/memoria.md, L2 y L3): [persona.md] y
    [escenas/<slug>.md]. Solo lee; lo escribe [memoria-consolida]. Un parser
    mínimo del frontmatter, tolerante: los campos que falten quedan vacíos y
    un fichero roto no tumba a los demás. *)

type t = {
  slug : string;  (** El nombre del fichero sin [.md]. *)
  titulo : string;  (** Si falta, el slug. *)
  resumen : string;
  calor : float;  (** 0 si falta o no es un número. *)
  actualizada : string;
}

val frontmatter : string -> (string * string) list
(** Los pares [clave: valor] entre los dos primeros [---]; los valores, sin
    comillas alrededor. Nada si el texto no empieza por [---]. *)

val de_texto : slug:string -> string -> t

val slug_valido : string -> bool
(** [a-z0-9-_], sin puntos ni barras: no se sale de [escenas/]. *)

val indice : string -> t list
(** Las escenas de un repo, de más a menos calor y, a igual calor, por slug:
    el orden no depende del sistema de ficheros. Nada si no hay repo. *)

val persona : string -> string option
(** [persona.md] sin frontmatter, recortado; [None] si no está o está vacío. *)

val escena : string -> string -> (string, string) result
(** El Markdown entero de una escena, por slug. *)

val leer_fichero : string -> string option
