(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Lo que inyecta el hook SessionStart: persona e índice de escenas. Es
    para la caché de prompts, así que es una función pura del repo: sin
    fechas, sin rutas que cambien, mismo orden siempre; byte a byte igual
    mientras el repo no cambie. *)

val presupuesto : int
(** Bytes como mucho del contexto (≈ 6000 caracteres). *)

val recortar : int -> string -> string
(** Como mucho tantos bytes, sin partir un carácter UTF-8; si recorta,
    acaba en […]. *)

val texto : repo:string -> persona:string option -> Escenas.t list -> string
(** El contexto, o [""] si no hay ni persona ni escenas. *)

val salida_hook : string -> string
(** El JSON del hook ([hookSpecificOutput.additionalContext]), o [""] si el
    contexto está vacío: un hook sin salida es válido. *)

val de_repo : string -> string
(** [salida_hook] del repo leído del disco. *)
