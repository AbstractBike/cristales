(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: los televisores que nombra un texto, o que pide alguien al darse
    de alta. Ver [SEMILLA.md]. *)

module Catalogo = Catalogo
module Texto = Texto

type tele = {
  familia : Texto.familia;
  pulgadas : int option;
  modelo : string;  (** Canónico: «LG OLED77C6», «Hisense 75U7SE», «Samsung TQ77S95H»; sin tamaño, «LG OLED C6». *)
  serie : string;
  anio : int option;
  tecnologia : Catalogo.tecnologia option;
  gama : Catalogo.gama option;
  hz : int option;
  hdmi21 : bool option;
  sistema : Catalogo.sistema option;
  ocho_k : bool;
  precio_nuevo : float option;
  precio_lanzamiento : float option;
}

type lectura = {
  teles : tele list;
  desconocidos : string list;
  pulgadas : int list;
  tecnologias : Catalogo.tecnologia list;
  marcas : string list;
  hz : int option;
}

val tele : Texto.familia -> int option -> tele
(** La tele de una familia con un tamaño: su modelo canónico y lo que el catálogo sabe de ella. *)

val menciones : string -> Texto.mencion list
(** Las familias que nombra el texto, en orden, con el tamaño que lleva su código. *)

val tamanos : ?sueltas:bool -> ?cm:bool -> string -> int list * (int * int) list
(** Los tamaños que dice el texto, sin repetir y en orden (sin los de un soporte: «hasta 75″»), y
    cada uno con la palabra donde está. [sueltas] (por omisión, sí): también los números sueltos de
    los tamaños que se fabrican («OLED de 77»). [cm] (sí): también los centímetros («189 cm»). *)

val leer : ?sueltas:bool -> string -> lectura
(** Pura: lo que nombra el texto, sin decidir nada. *)

val json_tele : tele -> Yojson.Safe.t

val aplicar : string -> (string, string) result
(** [{"modelos": [{"marca", "modelo", "serie", "anio", "pulgadas", "tecnologia", "gama",
    "precio_lanzamiento", "precio_nuevo", "hz", "sistema", "en_catalogo"}], "desconocidos": [...],
    "pulgadas": [...], "pulgadas_min": int|null, "tecnologias": [...], "marcas": [...],
    "hz_min": int|null}]; defecto si no nombra ni modelos, ni tamaños, ni tecnología, ni marca. *)

val cristal : (string, string) Cristal.cristal
