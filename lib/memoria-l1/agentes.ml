(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Agencia

let defecto ~preferido escalera = List.find_opt (fun (m : Modelo.t) -> m.nombre = preferido) escalera

let crear ~nombre ~descripcion ~instrucciones ~preferido ~escalera =
  Agente.crear ~nombre ~descripcion ~instrucciones ~escalera ?defecto:(defecto ~preferido escalera) ~max_tokens:8192 ()

let atomos ~escalera =
  crear ~nombre:"memoria-atomos"
    ~descripcion:"Destila átomos de memoria (persona, regla, hecho, método, episodio) de un tramo de sesión de Claude Code, con su escena; salida JSON."
    ~instrucciones:Prompts.atomos ~preferido:"claude-sonnet-5-5" ~escalera

let dedup ~escalera =
  crear ~nombre:"memoria-dedup"
    ~descripcion:"Juez de duplicados de la memoria: para cada átomo nuevo, guardar, saltar, actualizar o fusionar con sus candidatos; salida JSON."
    ~instrucciones:Prompts.dedup ~preferido:"claude-haiku-5-5" ~escalera

let igual (a : Agente.t) (b : Agente.t) =
  Agente.version a = Agente.version b
  && List.map Modelo.to_string a.escalera = List.map Modelo.to_string b.escalera
  && Modelo.to_string a.defecto = Modelo.to_string b.defecto
  && a.descripcion = b.descripcion && a.max_tokens = b.max_tokens

let asegurar (archivo : Archivo.t) (a : Agente.t) =
  match List.find_opt (fun (b : Agente.t) -> b.nombre = a.nombre) (archivo.agentes ()) with
  | Some b when igual a b -> false
  | _ ->
      archivo.guardar a;
      true
