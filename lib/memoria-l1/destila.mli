(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La destilación de una sesión, lote a lote: extraer (memoria-atomos),
    buscar candidatos, juzgar (memoria-dedup), escribir y avanzar el
    cursor. Los efectos se inyectan: la agencia, GreptimeDB y el log los
    pone [bin/memoria-destila]; las pruebas, falsos.

    Garantías:
    - el cursor solo avanza cuando el lote está escrito; si el cursor falla
      después, la pasada siguiente ve el lote ya escrito ({!efectos.escrito})
      y solo guarda el cursor: ni se repite el encargo ni se duplica nada;
    - si un modelo no responde o GreptimeDB falla, [Error]: la pasada se
      para y nada se da por hecho;
    - si el extractor devuelve basura, el encargo se juzga [mal] y se
      reintenta una vez con el siguiente modelo más capaz de la escalera. Si
      vuelve a fallar, el cursor NO avanza: se cuenta el fallo en el cursor
      y la sesión se deja para la siguiente pasada. Solo tras
      {!max_fallos} pasadas seguidas ilegibles se salta el lote (y se
      avisa): un fallo pasajero (un modelo caído, una exploración mala de la
      agencia) se recupera solo, y un lote envenenado no atasca la sesión
      para siempre;
    - si el juez devuelve basura, se juzga [mal] y se guarda todo. *)

type efectos = {
  encargar : Agencia.Agente.t -> ?modelo:Agencia.Modelo.t -> string -> Agencia.Encargo.t;
      (** Un encargo de la agencia, registrado en su archivo. *)
  juzgar_mal : Agencia.Encargo.t -> string -> unit;  (** Con la nota. *)
  candidatos : Atomo.nuevo -> (Atomo.t list, string) result;
  escrito : sesion:string -> hasta:int -> (bool, string) result;
      (** Si el lote que acaba en [hasta] ya escribió sus filas. *)
  escribir : hasta:int -> Atomo.t list -> (unit, string) result;
  guardar_cursor : sesion:string -> Lote.cursor -> (unit, string) result;
  avisar : string -> unit;
}

type agentes = { atomos : Agencia.Agente.t; dedup : Agencia.Agente.t }

val max_fallos : int
(** 3 pasadas. *)

type informe = {
  sesion : string;
  lote : Lote.t;
  encargos : Agencia.Encargo.t list;  (** Los de este lote, en orden. *)
  escenas : string list;
  extraidos : Atomo.nuevo list;
  descartados : (string * string) list;
  decisiones : (Dedup.caso * Dedup.decision) list;
  filas : Atomo.t list;  (** Lo escrito en [memoria_l1]. *)
}

type paso =
  | Destilado of informe
  | Recuperado  (** Ya estaba escrito: solo se guardó el cursor. *)
  | Ilegible of { fallos : int; saltado : bool }
      (** El extractor no dio JSON ni al reintentar; [saltado] tras
          {!max_fallos}. *)

val lote :
  efectos -> agentes -> sesion:string -> cursor:Lote.cursor option -> Lote.t -> (paso, string) result
(** Un lote entero, cursor incluido, con el cursor de antes del lote. *)

type resumen = {
  informes : informe list;
  recuperados : int;
  ilegibles : int;  (** Lotes que se quedaron sin avanzar por ilegibles. *)
  saltados : int;
  error : string option;  (** Por qué se paró, si fue por un error. *)
}

val avanzo : resumen -> bool
(** Si algún lote movió el cursor. *)

val sesion :
  efectos -> agentes -> ?limite:int -> sesion:string -> cursor:Lote.cursor option -> Atomo.mensaje list -> resumen
(** Lotes hasta acabar la sesión, hacer [limite], dar con un lote ilegible
    o con un error, con los mensajes que da {!Almacen.mensajes}. *)
