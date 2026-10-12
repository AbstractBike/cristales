(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: qué se vende en un anuncio de segunda mano de informática. Ver
    [SEMILLA.md]. *)

type tipo = Grafica | Antigua | Profesional | Pc | Portatil | Pieza | Componente | Busca | Lote | Otro

val tipo_texto : tipo -> string

type anuncio = { titulo : string; categoria : string; descripcion : string }

val partes : string -> anuncio
(** «Título: …», «Categoría: …», «Descripción: …»; sin «Título:», todo es el título. *)

type decision = Decide of tipo * Grafica_modelo.gpu option | Defecto of string

val decidir : anuncio -> decision
val estado : anuncio -> string

val aplicar : string -> (string, string) result
(** Pura. El JSON con [tipo], la gráfica (o [null]), su estado y lo que dice de
    minería, garantía, factura, caja y cambio; defecto si no sabe qué gráfica
    es («gráfica sin modelo», «varios modelos: …», «modelo desconocido: …»). *)

val cristal : (string, string) Cristal.cristal
