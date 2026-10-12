(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La extracción de ofertas de trabajo (trabajo.email), campo a campo.

    Un cristal {e parcial}: de los 14 campos que pide la extracción da solo
    los que sabe decidir por reglas, y en cada oferta los que pueda; la forja
    le pide al LLM el resto (doc/forja.md, «Campo a campo»). Las habilidades
    técnicas, los idiomas, el tipo de contrato, el tamaño de la empresa y si
    es una agencia no los da nunca: piden criterio (los idiomas, además, el
    LLM los deduce del idioma de la oferta y los nombra a su manera). *)

type oferta = {
  url : string;
  titulo : string;
  empresa : string;
  ubicacion : string;
  descripcion : string;
}

val leer : string -> oferta option
(** El mensaje de la extracción: [<posting>] con líneas [URL:], [Title:],
    [Company:], [Location:] y [Description:] hasta el final. *)

val campos : oferta -> (string * Yojson.Safe.t) list
(** Los campos que sabe de esta oferta, con los nombres y valores de la
    extracción. *)

val cristal : (string, string) Cristal.cristal
(** El mensaje → el objeto JSON con esos campos. Defecto si no hay
    [<posting>]. *)
