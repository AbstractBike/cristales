(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

(** El registro de una pipeline: un {!Cristal.evento} por línea, en JSON.
    Es el contrato entre pipelines en cualquier lenguaje y las herramientas de
    cristalización. Formato en [doc/registro.md]. *)

val version : int

val a_json : Cristal.evento -> string
(** Una línea, sin salto final. *)

val de_json : string -> (Cristal.evento, string) result
(** Los campos que no son del contrato ([ts], [modelo]…) se ignoran. *)

val escribir : out_channel -> Cristal.evento -> unit
(** Para pasar como [~observar]: escribe la línea y vacía el canal. *)

val de_greptime : string -> (Cristal.evento list, string) result
(** Lee la respuesta de GreptimeDB a un [SELECT] sobre la tabla del registro
    ([cristal_registro], ver [doc/registro.md]): sus columnas se llaman como los
    campos del contrato, y una columna a [null] es un campo ausente. *)

val leer : string -> (Cristal.evento list, string) result
(** Lee un fichero de registro: JSON Lines, o la respuesta de GreptimeDB tal
    cual la devuelve [/v1/sql]. Ignora líneas vacías; el error dice en qué
    línea o fila se rompió. *)
