(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: de qué va una noticia de hardware para quien sigue las gráficas
    de sobremesa. Ver [SEMILLA.md]. *)

type noticia = { titulo : string; resumen : string; fuente : string }

val partes : string -> noticia

val aplicar : string -> (string, string) result
(** Pura. [{"tema": "graficas"|"otro", "tipo": …, "fabricantes": […],
    "modelos": […], "nuevos": […]}]; defecto si no sabe si va de gráficas de
    sobremesa. *)

val cristal : (string, string) Cristal.cristal
