(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** El espejo del repo memoria en los nodos que no lo tienen (doc/memoria.md,
    «Recall en toda la flota»). El repo solo vive en el nodo de la tubería;
    los demás necesitan [persona.md] y [escenas/] para el hook y para
    [memoria_escena]. El nodo del repo los publica en GreptimeDB (tabla
    [memoria_espejo], una fila por fichero) y los demás los bajan a un
    directorio local con la misma forma que el repo.

    Cada publicación lleva una huella (MD5 de rutas y contenidos) y cuántos
    ficheros tiene: quien baja toma la última huella y solo la escribe si
    llegaron todas sus filas. Puro: el SQL y las filas aquí, la red y el disco
    en el binario. *)

type fichero = { ruta : string; contenido : string }
(** [ruta] relativa al repo: [persona.md] o [escenas/<slug>.md]. *)

val tabla : string

val del_repo : string -> fichero list
(** [persona.md] y las escenas con slug válido, en orden de ruta. *)

val huella : fichero list -> string
(** Hex; la misma para los mismos ficheros. *)

val filas : fichero list -> Yojson.Safe.t list
(** Las filas a ingerir: ruta, contenido, huella y total. *)

val ultima : string
(** SQL: huella y total de la última publicación. *)

val de_huella : string -> (string, string) result
(** SQL: los ficheros de esa huella; error si no es hex. *)

val ruta_valida : string -> bool
(** [persona.md] o [escenas/<slug>.md]: nada que se salga del directorio. *)

val escribir : string -> fichero list -> unit
(** Deja el directorio con exactamente esos ficheros: escribe en
    [<dir>.nuevo] y lo pone en su sitio con renombres. Ignora las rutas
    inválidas. Guarda la huella en [<dir>/.huella]. *)

val huella_local : string -> string option
