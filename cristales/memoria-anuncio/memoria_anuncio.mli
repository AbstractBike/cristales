(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: qué se vende en un anuncio de segunda mano de memoria RAM. Ver
    [SEMILLA.md]. *)

type tipo = Modulo | Kit | Lote | Pc | Portatil | Servidor | Placa | Cpu | Componente | Busca | Otro

val tipo_texto : tipo -> string

type anuncio = {
  titulo : string;
  categoria : string;
  descripcion : string;
  precio : float option;
  portal : string;
  pais : string;
}

val partes : string -> anuncio
(** «Título:», «Categoría:», «Precio:», «Portal:», «País:» y «Descripción:»
    (hasta el final); sin «Título:», todo es el título. *)

val leer_precio : string -> float option
(** «185», «185.0», «1.250 €», «88,99». *)

val aplicar : string -> (string, string) result
(** Pura. El JSON con [tipo], la memoria (cuántos módulos, de cuánto, su
    generación, formato, ECC, registro, velocidad, CAS, rangos, anchura,
    voltaje, fabricante, part number, OEM), lo que dice el anuncio (disipador,
    RGB, procedencia, si está probada, estado, garantía, factura, envío, si
    se vende por separado, cambio) y el precio por módulo; defecto si no sabe
    cuánta memoria es («no dice la capacidad», «no se sabe si es un módulo o
    un kit: 64 GB», «varias capacidades: …»). *)

val cristal : (string, string) Cristal.cristal
