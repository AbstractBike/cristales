(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Las notas de memoria que Claude Code ya tenía
    ([~/.claude/projects/*/memory/*.md]) como átomos L1. Puro.

    Una nota es un átomo, sin LLM: su [description] ya es una frase
    autosuficiente escrita para un índice (la que lista [MEMORY.md]), que es
    justo lo que es un átomo; y la consolidación comprime a 15 escenas de
    1500 caracteres, así que partir cada nota en átomos más finos no
    llegaría a las escenas. El cuerpo sigue en la nota. *)

type t = {
  nombre : string;  (** [name]. *)
  descripcion : string;  (** [description]. *)
  tipo : string;  (** [metadata.type] o [type]: feedback, user, project, reference. *)
  cuerpo : string;
}

val de_texto : string -> t
(** Cabecera YAML sencilla: [clave: valor] por línea, valores entre
    comillas dobles (JSON) o simples (YAML) o sin ellas; [type] vale
    anidado bajo [metadata] o suelto. *)

val es_indice : string -> bool
(** [MEMORY.md]: un índice, no una nota. *)

val tipo_atomo : string -> string
(** feedback → regla, user → persona, project y reference → hecho. *)

val fechas_en : string -> string list
(** Las fechas [AAAA-MM-DD] que aparecen en el texto, ordenadas y sin
    repetir. *)

val id_de : string -> string
(** [a-<hex12>] estable a partir de la ruta relativa de la nota
    ([<proyecto>/<fichero>]): reimportar da el mismo id. *)

val atomo : ts:int -> ruta:string -> proyecto:string -> escena:string -> fecha:string -> t -> Atomo.t
(** El átomo: [contenido] es la descripción (o el primer párrafo, si no
    tiene); [fechas], las del texto más [fecha] (la de la nota); [origen],
    [["nota:<ruta>"]]. *)
