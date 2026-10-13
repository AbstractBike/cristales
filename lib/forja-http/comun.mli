(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Lo que comparten las APIs que habla la forja ({!Anthropic}, {!Openai}). *)

val campo : string -> Yojson.Safe.t -> Yojson.Safe.t option

val cadena : Yojson.Safe.t -> string
(** JSON canónico (claves ordenadas): así se comparan las salidas. *)

val solo_texto : Yojson.Safe.t -> string option
(** Un contenido que es una cadena o una lista de bloques de texto. *)

val objeto_json : string -> (Yojson.Safe.t, string) result
(** La salida de un cristal estructurado, si es un objeto JSON. *)

(** {1 Esquemas: cristales parciales} *)

val cambiar : string -> (Yojson.Safe.t -> Yojson.Safe.t) -> Yojson.Safe.t -> Yojson.Safe.t
(** El objeto con el campo [k] cambiado, si lo tiene. *)

val propiedades : Yojson.Safe.t -> string list
(** Las propiedades de un JSON Schema de objeto. *)

val restringir_esquema : string list -> Yojson.Safe.t -> Yojson.Safe.t
(** El esquema con solo esas propiedades (y obligatorias). *)

val ultimo_de_ejemplos : Yojson.Safe.t list -> Yojson.Safe.t option
(** Si los turnos son usuario/asistente alternos, todos de texto, y el
    último es de usuario, ese último: los anteriores son ejemplos
    (few-shot) de la misma tarea. *)
