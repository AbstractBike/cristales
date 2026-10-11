(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** El proxy: habla la Messages API de Anthropic por los dos lados, así que
    cualquier cliente se enchufa cambiando solo la URL base.

    [POST /v1/messages] pasa por la forja; [/forja/…] es su introspección
    ([Introspeccion], para [forja-mcp]); lo demás se reenvía tal cual.
    Cada respuesta lleva [x-forja-fuente]: [cristal], [liquido], [defecto]
    (un cristal mixto no supo y respondió el LLM) o [paso] (la petición no es
    una tarea cristalizable: varios turnos, herramientas, streaming…). *)

type t = {
  cliente : Cohttp_eio.Client.t;
  upstream : Uri.t;  (** Raíz de la API real, p. ej. [https://api.anthropic.com]. *)
  forja : Forja.t;
  madura : Forja.Tarea.t -> Forja.Madurez.informe -> unit;
      (** Se llama una vez cuando una tarea madura. *)
}

val cliente : _ Eio.Net.t -> Cohttp_eio.Client.t
(** Cliente HTTP y HTTPS. Requiere un RNG instalado
    ([Mirage_crypto_rng_unix.use_default]). *)

val http : Cohttp_eio.Client.t -> Http.Method.t -> Uri.t -> string -> int * string
(** Una petición con cuerpo JSON: estado y cuerpo de la respuesta. Lanza si
    no hay conexión. *)

val post : Cohttp_eio.Client.t -> Cantera_greptime.post
(** Un POST con ese cliente, para [Cantera_greptime.crear]. *)

val servir :
  sw:Eio.Switch.t ->
  net:_ Eio.Net.t ->
  ip:Eio.Net.Ipaddr.v4v6 ->
  puerto:int ->
  t ->
  'a
