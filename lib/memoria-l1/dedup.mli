(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Los duplicados: candidatos sin LLM (fulltext de GreptimeDB fusionado
    por RRF), la entrada y la lectura del juez [memoria-dedup], y el plan
    de escritura que sale de sus decisiones. Puro: las consultas las hace
    {!Almacen}. *)

(** {1 Candidatos} *)

val terminos : ?max:int -> string -> string list
(** Las palabras con las que buscar parecidos a un contenido: sin vacías,
    de 4 letras o más (o de 2 si llevan cifras: [a2], [k0s]), las más
    distintivas primero (con mayúscula o cifra, luego las largas); como
    mucho [max] (6). Solo letras y cifras: van tal cual a [matches]. *)

val consulta : string -> string
(** El patrón de [matches(lower(contenido), …)] para un término: en
    minúsculas y entre comillas dobles (así [or], [and] y [not] no son
    operadores, y casa como subcadena). *)

val rrf : ?k:int -> string list list -> (string * float) list
(** Reciprocal Rank Fusion de varias listas de ids ordenadas: la suma de
    [1 / (k + rango)] (rango desde 1; [k] = 60), de más a menos. *)

val vigentes : (string * int) list -> Atomo.t list -> Atomo.t list
(** Con la versión mayor de cada id, solo las filas que son esa versión y
    están vigentes; una por id. *)

val mejores : ?n:int -> Atomo.t list list -> Atomo.t list
(** Una lista por término (ya de vigentes, en su orden), fusionadas por
    {!rrf}: los [n] (5) mejores. *)

(** {1 El juez} *)

type caso = {
  etiqueta : string;  (** [n1], [n2]…: cómo lo ve el juez. *)
  nuevo : Atomo.nuevo;
  candidatos : Atomo.t list;
}

val casos : (Atomo.nuevo * Atomo.t list) list -> caso list
(** Etiqueta los átomos nuevos en orden. *)

val hace_falta_juez : caso list -> bool
(** Si algún átomo tiene candidatos; si no, se guardan todos sin llamar al
    modelo. *)

val entrada : caso list -> string
(** El mensaje de usuario del encargo: los candidatos (sin repetir) y, por
    cada nuevo, su contenido y los ids de sus candidatos. *)

type accion = Guardar | Saltar | Actualizar | Fusionar

val accion_a_texto : accion -> string

type decision = {
  caso : string;  (** La etiqueta del caso. *)
  accion : accion;
  objetivos : string list;  (** Ids de candidatos de ese caso. *)
  contenido : string option;
  tipo : Atomo.tipo option;
  prioridad : int option;
  fechas : string list;
}

val guardar_todo : caso list -> decision list
(** Lo que se hace si el juez no responde o responde basura: nunca se
    pierde nada. *)

val leer : caso list -> string -> (decision list, string) result
(** Una decisión por caso. [Error] si la respuesta no es un array JSON (el
    encargo salió mal; quien llama guarda todo). Dentro, lo inválido se
    corrige hacia [Guardar]: un caso sin decisión, una acción desconocida,
    objetivos que no son candidatos de ese caso, o actualizar o fusionar
    sin objetivos. *)

(** {1 El plan} *)

val plan : caso list -> decision list -> Atomo.t list
(** Las filas que hay que escribir en [memoria_l1], en orden:

    - [Guardar]: el nuevo, versión 1 (si el mismo id no salió ya en el lote);
    - [Saltar]: nada;
    - [Actualizar] y [Fusionar]: una versión nueva del primer objetivo con el
      contenido, tipo y prioridad del juez (o los del nuevo), unión de origen
      y de fechas (las del juez solo si son [AAAA-MM-DD]); y una versión no
      vigente de cada otro objetivo, que queda absorbido. Al fusionar la
      prioridad no baja de la mayor de las fusionadas, y una regla absoluta
      (-1) sigue siéndolo.

    Dos frenos, porque un juez flojo (en la prueba real, gemma) llegó a
    fundir un método, un hecho y un episodio en el episodio de una
    retirada, y las lecciones se perdían: un objetivo más duradero que el
    resultado no se toca (persona, regla y método > hecho > episodio), y
    como mucho {!max_objetivos} objetivos por decisión. Si no queda
    ninguno, se guarda el nuevo.

    Las decisiones se aplican en orden: un objetivo ya absorbido en el lote
    no cuenta, y el que ya se actualizó parte de su última versión. *)

val durabilidad : Atomo.tipo -> int
val max_objetivos : int
