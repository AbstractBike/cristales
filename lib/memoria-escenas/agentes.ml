(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Agencia

(* Mientras la agencia no sepa más, Sonnet: consolidar pide criterio, y
   Opus para 15 escenas sería caro sin necesidad. La agencia explorará
   los de abajo y, si lo hacen bien, bajará sola. *)
let defecto escalera =
  List.find_opt (fun (m : Modelo.t) -> m.nombre = "claude-sonnet-5-5") escalera

let crear ~nombre ~descripcion ~instrucciones ~max_tokens ~escalera =
  match Agente.crear ~nombre ~descripcion ~instrucciones ~escalera ?defecto:(defecto escalera) ~max_tokens () with
  | Ok a -> a
  | Error e -> invalid_arg (nombre ^ ": " ^ e)

let escenas ~escalera =
  crear ~nombre:"memoria-escenas"
    ~descripcion:
      "Consolida átomos de memoria (L1) en escenas Markdown (L2, tope 15): devuelve operaciones JSON (actualizar, \
       fusionar, crear, nada) que aplica el código."
    ~instrucciones:Prompt.escenas ~max_tokens:16000 ~escalera

let persona ~escalera =
  crear ~nombre:"memoria-persona"
    ~descripcion:"Regenera persona.md (L3, ≤ 2000 caracteres) a partir de la persona actual y las escenas cambiadas."
    ~instrucciones:Prompt.persona ~max_tokens:4000 ~escalera

let asegurar (archivo : Archivo.t) (a : Agente.t) =
  let igual (b : Agente.t) =
    Agente.version a = Agente.version b
    && List.map Modelo.to_string a.escalera = List.map Modelo.to_string b.escalera
    && Modelo.to_string a.defecto = Modelo.to_string b.defecto
    && a.max_tokens = b.max_tokens
  in
  match List.find_opt (fun (b : Agente.t) -> b.nombre = a.nombre) (archivo.agentes ()) with
  | Some b when igual b -> ()
  | _ -> archivo.guardar a
