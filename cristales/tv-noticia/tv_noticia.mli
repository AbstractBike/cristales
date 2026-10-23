(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: de qué va una noticia de imagen y sonido para quien sigue los
    televisores. Ver [SEMILLA.md]. *)

val aplicar : string -> (string, string) result
(** Pura. [{"tema": "tv"|"imagen-sonido"|"otro", "tipo": "lanzamiento"|"precio"|"oferta"|"analisis"|
    "software"|"mercado"|"rumor"|"otro", "marcas": […], "modelos": […], "nuevos": […],
    "tecnologias": […]}]; defecto si nombra una marca de teles y no sabe si va de teles. *)

val cristal : (string, string) Cristal.cristal
