(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Las mediciones de la agencia: cada encargo y cada veredicto, como un
    punto con etiquetas (agente, modelo, fuente…) en GreptimeDB, para
    contarlos y agruparlos por PromQL en el dashboard «Agencia» de Perses.

    El archivo ya guarda cada encargo, pero en tablas sin etiquetas (para
    leerlo entero). Esto es su vista de métricas, y se escribe aparte: la
    agencia vive en un proceso por sesión (agencia-mcp), así que no hay un
    [/metrics] que scrapear; cada encargo se mide al hacerse. *)

type punto = {
  tabla : string;
  etiquetas : (string * string) list;
  campos : (string * int) list;
  ms : float option;  (** Cuándo, en milisegundos Unix; [None], al llegar. *)
}

val encargo : Agencia.Encargo.t -> punto
(** [agencia_encargo{agente, version, modelo, fuente, resultado}] con
    [n] (1), [ms], [tokens_entrada] y [tokens_salida]. *)

val veredicto : Forja.Tarea.t -> modelo:string -> Agencia.veredicto -> punto
(** [agencia_veredicto{agente, modelo, veredicto}] con [n] (1). *)

val linea : punto -> string
(** En el protocolo de línea de InfluxDB, con las etiquetas escapadas. *)

val con_medidas : (punto -> unit) -> Agencia.Archivo.t -> Agencia.Archivo.t
(** El archivo, que además mide cada encargo que registra y cada veredicto
    que guarda. El modelo de un veredicto se toma del encargo, si se
    registró en este proceso, o del historial. *)

val a_greptime : Forja_http.Greptime.t -> punto -> unit
