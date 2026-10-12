(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: qué se vende en un anuncio de segunda mano de discos y
    componentes. Ver [SEMILLA.md]. *)

type tipo = Ssd | Sata | Hdd | Externo | Caja | Adaptador | Pc | Portatil | Consola | Componente | Lote | Busca | Otro

val tipo_texto : tipo -> string

type decision = Decide of tipo | Defecto of string

val decidir : Grafica_anuncio.anuncio -> Nvme_modelo.lectura -> decision

val vida : string -> int option
(** El % de vida que dice el texto («100% Health», «0% Verschleiß» = 100). *)

val horas : string -> int option
val escritos : string -> int option
(** TB escritos que dice el texto. *)

val aplicar : string -> (string, string) result
(** Pura. El JSON con [tipo], el disco (modelo del catálogo o [null], marca,
    segmento, interfaz, formato, DRAM, NAND, PLP, capacidad, TBW…), su estado,
    su salud (horas, escritos, vida, SMART) y lo que dice de garantía, factura,
    caja, disipador y cambio; defecto si no sabe qué disco es («varios
    modelos: …», «modelo desconocido: …»). *)

val cristal : (string, string) Cristal.cristal
