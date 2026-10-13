(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: la memoria que nombra un texto (los part numbers, con lo que
    dicen; lo que el texto dice de la memoria; las placas y servidores, con la
    memoria que admiten). Ver [SEMILLA.md]. *)

module Catalogo = Catalogo
module Texto = Texto

type especificacion = {
  generacion : Catalogo.generacion option;
  formato : Catalogo.formato option;
  formato_dicho : bool;  (** El formato lo dice el texto o su etiqueta JEDEC; si no, se ha deducido. *)
  ecc : bool option;
  registrada : bool option;
  capacidad : int option;  (** MB por módulo. *)
  modulos : int option;
  total : int option;  (** MB. *)
  iguales : bool option;
  disponibles : int option;  (** Unidades sueltas: «4 Stück verfügbar». *)
  velocidad : int option;  (** MT/s. *)
  cas : int option;
  rangos : int option;
  anchura : int option;
  voltaje : float option;
}

type lectura = {
  modulos : (Catalogo.modulo * int) list;  (** Los part numbers leídos, con la palabra donde empiezan. *)
  desconocidos : string list;  (** Lo que parece un part number sin que ninguna regla lo lea. *)
  especificacion : especificacion;  (** Lo que dice el texto, sin los part numbers. *)
  generaciones : Catalogo.generacion list;
  velocidades : int list;
  varias : int list;  (** Capacidades (MB) sueltas que no casan: varias ofertas. *)
  placas : Catalogo.placa list;
  marcas : string list;
  oem : string option;
  lineas : string list;
  kit : bool;
  servidor : bool;
  portatil : bool;
}

val leer : string -> lectura
(** Pura: lo que dice el texto, sin decidir nada. *)

val combinar : especificacion -> Catalogo.modulo option -> especificacion
(** La especificación completada con la del part number: el texto manda; el
    part number da lo que el texto calla (y su formato, al deducido). *)

val sin_repetir : 'a list -> 'a list
val gb_json : int -> Yojson.Safe.t
(** MB a GB: entero si lo es; 0.5 para 512 MB. *)

val json_modulo : Catalogo.modulo -> Yojson.Safe.t
val json_placa : Catalogo.placa -> Yojson.Safe.t

val aplicar : string -> (string, string) result
(** [{"modulos": [...], "especificacion": {...} | null, "placas": [...],
    "desconocidos": [...], "marcas": [...]}]; defecto si no nombra ningún
    módulo, ninguna placa ni nada de la memoria. *)

val cristal : (string, string) Cristal.cristal
