(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Una pasada de ingesta: recorre los transcripts, lee de cada uno lo
    nuevo desde el {!Cursor}, lo pasa por {!Transcript} y entrega los
    mensajes por lotes a [escribir]. El cursor de un fichero solo avanza si
    todos sus lotes se escribieron. Sin [escribir] (modo seco) no escribe
    nada ni toca el cursor: solo cuenta. *)

type estadisticas = {
  mutable ficheros : int;  (** Con algo nuevo que leer. *)
  mutable bytes : int;
  mutable lineas : int;
  mutable mensajes : int;
  mutable usuario : int;
  mutable asistente : int;
  mutable de_subagentes : int;
  mutable truncados : int;
  mutable fallidos : int;  (** Ficheros con algún lote que no se escribió. *)
  redacciones : (Redaccion.tipo, int) Hashtbl.t;
  mensajes_redactados : int ref;
}

val ficheros : string -> string list
(** [<raiz>/*/*.jsonl] y los [agent-*.jsonl] bajo [<raiz>/*/<sesion>/subagents/]
    (también los de [workflows/wf_*/]), ordenados. *)

val lineas_desde : string -> int -> string list * int
(** Las líneas completas desde ese desplazamiento y el desplazamiento tras
    la última; una línea a medio escribir se deja para la próxima. Si el
    fichero es más corto que el desplazamiento, empieza desde 0. *)

val pasar :
  raiz:string ->
  cursor:Cursor.t ->
  ?escribir:(Transcript.mensaje list -> (unit, string) result) ->
  ?al_fichero:(string -> unit) ->
  ?al_redactar:(string -> Redaccion.tipo -> antes:string -> string -> unit) ->
  ?al_mensaje:(string -> Transcript.mensaje -> unit) ->
  unit ->
  estadisticas
(** [al_fichero] se llama tras cada fichero cuyo cursor avanzó (para
    guardarlo); [al_redactar], con cada redacción y su fichero
    ({!Redaccion.redactar}); [al_mensaje], con cada mensaje tal como iría
    a L0 y su fichero. *)

val informe : estadisticas -> string
(** Las cifras, en texto, una por línea. *)
