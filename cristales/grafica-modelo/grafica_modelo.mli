(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: las gráficas que nombra un texto. Ver [SEMILLA.md]. *)

module Catalogo = Catalogo
module Texto = Texto

type gpu = { modelo : Catalogo.modelo; vram : int }

type lectura = {
  modelos : gpu list;
  desconocidos : string list;
  antiguas : string list;
  profesionales : string list;
}

val leer : string -> lectura
(** Pura: lo que nombra [texto], sin decidir nada. *)

val json_gpu : gpu -> Yojson.Safe.t

val aplicar : string -> (string, string) result
(** El JSON de [leer] ([{"modelos": [...], "desconocidos": [...], "antiguas": [...],
    "profesionales": [...]}]); defecto si no nombra ninguna gráfica o solo
    desconocidas. *)

val cristal : (string, string) Cristal.cristal
