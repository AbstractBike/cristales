(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Lo que devuelve el agente [memoria-escenas]: operaciones sobre las
    escenas, en JSON. El LLM no toca ficheros; las aplica
    {!Consolidacion.aplicar}, que las valida. *)

type contenido = {
  slug : string;
  titulo : string;
  resumen : string;
  cuerpo : string;  (** El cuerpo entero, no un parche. *)
  atomos : string list;  (** Los átomos nuevos que integra. *)
}

type t =
  | Actualizar of contenido
  | Fusionar of string list * contenido  (** Las escenas que junta y la resultante. *)
  | Crear of contenido
  | Nada

type salida = {
  operaciones : t list;
  persona : string option;
      (** El motivo, si la salida lleva [[ACTUALIZAR_PERSONA]] en cualquier
          sitio. *)
}

val senal : string
(** ["[ACTUALIZAR_PERSONA]"]. *)

val de_texto : string -> (salida, string) result
(** Del primer [{] al último [}] (tolera texto o un bloque de código
    alrededor). Una operación que no se entiende es un error de toda la
    salida: mejor repetir que aplicar a medias. *)

val a_json : t -> Yojson.Safe.t
val describir : t -> string
(** Una línea: [crear flota-nixos], [fusionar a+b -> c]… *)
