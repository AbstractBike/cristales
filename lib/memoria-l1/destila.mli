(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La destilación de una sesión, lote a lote: extraer (memoria-atomos),
    buscar candidatos, juzgar (memoria-dedup), escribir y avanzar el
    cursor. Los efectos se inyectan: la agencia, GreptimeDB y el log los
    pone [bin/memoria-destila]; las pruebas, falsos.

    Garantías:
    - el cursor solo avanza cuando el lote está escrito;
    - si un modelo no responde, la sesión se deja para la siguiente pasada;
    - si el extractor devuelve basura, el encargo se juzga [mal] y se
      reintenta una vez con el siguiente modelo más capaz de la escalera;
      si vuelve a fallar, el lote se salta (se avisa) para no atascarse;
    - si el juez devuelve basura, se juzga [mal] y se guarda todo. *)

type efectos = {
  encargar : Agencia.Agente.t -> ?modelo:Agencia.Modelo.t -> string -> Agencia.Encargo.t;
      (** Un encargo de la agencia, registrado en su archivo. *)
  juzgar_mal : Agencia.Encargo.t -> string -> unit;  (** Con la nota. *)
  candidatos : Atomo.nuevo -> Atomo.t list;
  escribir : Atomo.t list -> (unit, string) result;
  guardar_cursor : sesion:string -> hasta:int -> escena:string option -> (unit, string) result;
  avisar : string -> unit;
}

type agentes = { atomos : Agencia.Agente.t; dedup : Agencia.Agente.t }

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

val lote :
  efectos -> agentes -> sesion:string -> escena_previa:string option -> Lote.t -> (informe, string) result
(** Un lote entero, cursor incluido. [Error] si no se pudo (sin respuesta
    del modelo, GreptimeDB sin escribir): el cursor no se ha movido. *)

val sesion :
  efectos ->
  agentes ->
  ?limite:int ->
  sesion:string ->
  cursor:(int * string option) option ->
  Atomo.mensaje list ->
  informe list * string option
(** Lotes hasta acabar la sesión o hacer [limite] (sin límite si no se da),
    con los mensajes que da {!Almacen.mensajes}. Devuelve los informes y,
    si paró por un error, cuál. *)
