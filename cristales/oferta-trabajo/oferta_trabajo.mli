(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La extracción de ofertas de trabajo (trabajo.email), campo a campo.

    Un cristal {e parcial}: de los 14 campos que pide la extracción da solo
    los que sabe decidir por reglas, y en cada oferta los que pueda; la forja
    le pide al LLM el resto (doc/forja.md, «Campo a campo»). Las habilidades
    técnicas y el tamaño de la empresa no los da nunca: piden criterio (el
    tamaño, además, sale de lo que el LLM sabe de la empresa, no de la
    oferta). El contrato y si es una agencia, solo cuando la oferta no deja
    dudas. Los idiomas (v3) los da siempre, con otro significado que el del
    LLM: los que la oferta exige, en ISO 639-1 (SEMILLA.md, «Idiomas
    exigidos»).

    Sirve dos tareas de la forja con la misma entrada y la misma salida:
    [t-a9fd1c2e9324] (Chat Completions con [json_schema]) y [t-cab6e50313a9]
    (Messages con la herramienta [extract_job]). *)

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

val descripcion : string
(** Para quien lo llame como herramienta (la vitrina). *)
