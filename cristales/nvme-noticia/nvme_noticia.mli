(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: de qué va una noticia de hardware para quien sigue los SSD y el
    almacenamiento. Ver [SEMILLA.md]. *)

val aplicar : string -> (string, string) result
(** Pura. [{"tema": "ssd"|"almacenamiento"|"otro", "tipo": …, "segmento":
    "consumo"|"enterprise"|"?", "fabricantes": […], "modelos": […], "nuevos": […]}];
    defecto si no sabe si va de almacenamiento. *)

val cristal : (string, string) Cristal.cristal
