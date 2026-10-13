(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type t = { cursor : int; persona : string option; atomos_desde_persona : int }

let inicial = { cursor = 0; persona = None; atomos_desde_persona = 0 }

let de_texto s =
  let open Yojson.Safe.Util in
  try
    let j = Yojson.Safe.from_string s in
    { cursor = (match member "cursor" j with `Int i -> i | _ -> 0);
      persona = (match member "persona" j with `String p -> Some p | _ -> None);
      atomos_desde_persona = (match member "atomos_desde_persona" j with `Int i -> i | _ -> 0) }
  with Yojson.Json_error _ | Type_error _ -> inicial

let a_texto e =
  Yojson.Safe.pretty_to_string
    (`Assoc
       [ ("cursor", `Int e.cursor);
         ("persona", match e.persona with Some p -> `String p | None -> `Null);
         ("atomos_desde_persona", `Int e.atomos_desde_persona) ])
  ^ "\n"
