(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Métricas en el formato de texto de Prometheus, para que las recoja el
    vmagent de la flota (modules/observability/metrics.nix de nixos-config)
    y acaben en GreptimeDB.

    Contadores e histogramas que se van sumando, y medidas que se calculan
    al servirlas ({!servir}). Sin dependencias ni hilos: la forja corre en
    un solo dominio de Eio. *)

type t

type etiquetas = (string * string) list

val crear : unit -> t

val contador : t -> string -> ayuda:string -> unit
(** Declara un contador; [nombre] debería acabar en [_total]. *)

val histograma : t -> string -> ayuda:string -> cubos:float list -> unit
(** Declara un histograma con esos límites superiores (en segundos, en
    tokens…), en orden. *)

val sumar : t -> string -> ?etiquetas:etiquetas -> float -> unit
(** Suma a un contador declarado. Uno no declarado se ignora. *)

val observar : t -> string -> ?etiquetas:etiquetas -> float -> unit
(** Una observación de un histograma declarado. *)

type medida = { nombre : string; ayuda : string; valores : (etiquetas * float) list }
(** Un gauge calculado al servir. *)

val servir : t -> medida list -> string
(** El texto de la exposición: lo acumulado y las medidas. *)
