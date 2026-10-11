(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

(** Cristal: fechas en español a ISO 8601. Ver [SEMILLA.md]. *)

type fecha = { anyo : int; mes : int; dia : int }

val aplicar : hoy:fecha -> string -> (fecha, string) result
(** Pura: solo depende del texto y de [hoy]. *)

val cristal : hoy:fecha -> (string, fecha) Cristal.cristal
val iso : fecha -> string
val valida : fecha -> bool
