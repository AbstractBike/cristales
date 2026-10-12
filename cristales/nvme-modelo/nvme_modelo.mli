(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: los SSD que nombra un texto. Ver [SEMILLA.md]. *)

module Catalogo = Catalogo
module Texto = Texto

type ssd = { modelo : Catalogo.modelo; capacidad : int option; tbw : int option; formato : string }

type lectura = {
  modelos : ssd list;
  desconocidos : string list;
  capacidades : int list;
  interfaz : Texto.interfaz_leida;
  formato : string option;
  marcas : string list;
  enterprise : bool;
}

val leer : string -> lectura
(** Pura: lo que nombra el texto, sin decidir nada. *)

val json_ssd : ssd -> Yojson.Safe.t

val interfaz_texto : Texto.interfaz_leida -> string option
(** «pcie4», «sata», «sas», o nada si no lo dice. *)

val aplicar : string -> (string, string) result
(** El JSON de [leer] ([{"modelos": [...], "desconocidos": [...], "capacidades": [...],
    "interfaz": ..., "formato": ..., "marcas": [...]}]); defecto si no nombra ningún
    modelo del catálogo o solo desconocidos. *)

val cristal : (string, string) Cristal.cristal
