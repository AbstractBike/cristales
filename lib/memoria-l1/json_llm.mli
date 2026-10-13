(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Sacar el JSON de lo que responde un modelo: sin los bloques
    [<think>…</think>], sin la valla [```json] y sin el texto que algunos
    ponen alrededor. Puro. *)

val extraer : string -> (Yojson.Safe.t, string) result
(** El primer objeto o array JSON completo de la respuesta. *)

val texto : Yojson.Safe.t -> string -> string option
(** Un campo de texto no vacío (recortado) de un objeto. *)

val entero : Yojson.Safe.t -> string -> int option
(** Un campo entero (o un número, o un texto con un entero). *)

val textos : Yojson.Safe.t -> string -> string list
(** Un campo lista de textos; lo que no es texto se ignora. *)
