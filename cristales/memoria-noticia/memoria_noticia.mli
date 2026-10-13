(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: de qué va una noticia de hardware para quien sigue la memoria
    RAM. Ver [SEMILLA.md]. *)

val aplicar : string -> (string, string) result
(** Pura. [{"tema": "memoria"|"almacenamiento"|"hardware"|"otro", "tipo": …,
    "segmento": …, "fabricantes": […], "generaciones": […], "formatos": […],
    "modelos": […], "nuevos": […]}]; defecto si solo dice «Speicher» y no se
    sabe si es memoria o almacenamiento. *)

val cristal : (string, string) Cristal.cristal
