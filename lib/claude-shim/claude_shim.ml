(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Yojson.Safe.Util

type prompt = { system : string; user : string }

type peticion = {
  modelo : string;
  alias : string;
  prompt : prompt;
  herramienta : (string * Yojson.Safe.t) option;
}

let contiene ~sub s =
  let s = String.lowercase_ascii s and n = String.length sub in
  let rec en i = i + n <= String.length s && (String.sub s i n = sub || en (i + 1)) in
  en 0

let alias m = if contiene ~sub:"haiku" m then "haiku" else if contiene ~sub:"opus" m then "opus" else "sonnet"

let claves_esperadas schema =
  match member "properties" schema with `Assoc kvs -> List.map fst kvs | _ | (exception Type_error _) -> []

let instrucciones_esquema system nombre schema =
  let b = Buffer.create 512 in
  if String.trim system <> "" then (Buffer.add_string b system; Buffer.add_string b "\n\n");
  Buffer.add_string b "Responde EXCLUSIVAMENTE con un único objeto JSON que sea una ";
  Buffer.add_string b ("INSTANCIA (no repitas el schema) para la herramienta \"" ^ nombre ^ "\".");
  (match claves_esperadas schema with
  | [] -> ()
  | ks ->
      Buffer.add_string b "\nForma exacta: {";
      Buffer.add_string b (String.concat ", " (List.map (fun k -> Printf.sprintf "\"%s\": ..." k) ks));
      Buffer.add_string b "}");
  Buffer.add_string b "\nDebe validar contra este JSON Schema:\n";
  Buffer.add_string b (Yojson.Safe.to_string schema);
  Buffer.add_string b "\nSin markdown, sin fences, sin texto antes ni después del JSON.";
  Buffer.contents b

(* El contenido de un mensaje: texto, o bloques de los que se toman los de
   texto. *)
let texto = function
  | `String s -> Some s
  | `List bloques ->
      Some
        (String.concat "\n"
           (List.filter_map
              (fun b -> match (member "type" b, member "text" b) with `String "text", `String t -> Some t | _ -> None)
              bloques))
  | _ -> None

let peticion cuerpo =
  match Yojson.Safe.from_string cuerpo with
  | exception Yojson.Json_error e -> Error ("el cuerpo no es JSON: " ^ e)
  | j -> (
      try
        let modelo = match member "model" j with `String m -> m | _ -> "sonnet" in
        let system = Option.value ~default:"" (texto (member "system" j)) in
        let user =
          match member "messages" j with
          | `List (m :: _) -> texto (member "content" m)
          | _ -> None
        in
        let herramienta =
          match member "tools" j with
          | `List (t :: _) ->
              let nombre = match member "name" t with `String n -> n | _ -> "structured_output" in
              let schema = match member "input_schema" t with `Assoc _ as s -> s | _ -> `Assoc [] in
              Some (nombre, schema)
          | _ -> None
        in
        match user with
        | None -> Error "messages[0].content ausente"
        | Some user ->
            let prompt =
              match herramienta with
              | None -> { system; user }
              | Some (nombre, schema) -> { system = instrucciones_esquema system nombre schema; user }
            in
            Ok { modelo; alias = alias modelo; prompt; herramienta }
      with Type_error (m, _) -> Error m)

let argumentos ~bin ~alias ~system =
  [ bin; "-p"; "--output-format"; "json"; "--model"; alias; "--tools"; ""; "--strict-mcp-config";
    "--disable-slash-commands"; "--no-session-persistence"; "--system-prompt"; system ]

let quitar_prefijo p s =
  if String.starts_with ~prefix:p s then String.sub s (String.length p) (String.length s - String.length p) else s

let quitar_sufijo p s =
  if String.ends_with ~suffix:p s then String.sub s 0 (String.length s - String.length p) else s

let extraer_json texto =
  let t = String.trim texto |> quitar_prefijo "```json" |> quitar_prefijo "```" |> quitar_sufijo "```" |> String.trim in
  match (String.index_opt t '{', String.rindex_opt t '}') with
  | Some i, Some f when f > i -> (
      match Yojson.Safe.from_string (String.sub t i (f - i + 1)) with
      | `Assoc _ as j -> Ok j
      | _ -> Error "sin objeto JSON en la respuesta"
      | exception Yojson.Json_error e -> Error ("JSON inválido en la respuesta: " ^ e))
  | _ -> Error "sin objeto JSON en la respuesta"

let desenvolver j esperadas =
  match j with
  | `Assoc kvs when esperadas <> [] && not (List.exists (fun (k, _) -> List.mem k esperadas) kvs) -> (
      match List.assoc_opt "properties" kvs with
      | Some (`Assoc dentro as p) when List.exists (fun (k, _) -> List.mem k esperadas) dentro -> p
      | _ -> j)
  | _ -> j

let entero j k = match member k j with `Int n -> n | _ | (exception Type_error _) -> 0

let mensaje ~id ~modelo ~bloque ~stop ~uso =
  Yojson.Safe.to_string
    (`Assoc
      [ ("id", `String id);
        ("type", `String "message");
        ("role", `String "assistant");
        ("content", `List [ bloque ]);
        ("model", `String modelo);
        ("stop_reason", `String stop);
        ("usage", `Assoc [ ("input_tokens", `Int (entero uso "input_tokens")); ("output_tokens", `Int (entero uso "output_tokens")) ]) ])

let respuesta p ~id salida =
  match Yojson.Safe.from_string salida with
  | exception Yojson.Json_error _ -> Error ("la salida de claude no es JSON: " ^ String.sub salida 0 (min 200 (String.length salida)))
  | cli -> (
      let resultado = match member "result" cli with `String s -> Some s | _ | (exception Type_error _) -> None in
      let uso = match member "usage" cli with `Assoc _ as u -> u | _ | (exception Type_error _) -> `Assoc [] in
      let es_error = match member "is_error" cli with `Bool b -> b | _ | (exception Type_error _) -> false in
      match (es_error, resultado) with
      | true, r -> Error ("claude devolvió is_error: " ^ Option.value ~default:"" r)
      | _, None -> Error "CLI sin campo result"
      | _, Some texto -> (
          match p.herramienta with
          | None ->
              Ok
                (mensaje ~id ~modelo:p.modelo ~stop:"end_turn" ~uso
                   ~bloque:(`Assoc [ ("type", `String "text"); ("text", `String texto) ]))
          | Some (nombre, schema) ->
              Result.map
                (fun j ->
                  mensaje ~id ~modelo:p.modelo ~stop:"tool_use" ~uso
                    ~bloque:
                      (`Assoc
                        [ ("type", `String "tool_use");
                          ("id", `String "toolu_shim");
                          ("name", `String nombre);
                          ("input", desenvolver j (claves_esperadas schema)) ]))
                (extraer_json texto)))

let recortar n s = if String.length s <= n then s else String.sub s 0 n

let motivo_fallo ~err ~out =
  recortar 300
    (if String.trim err <> "" then err
     else
       match Yojson.Safe.from_string out |> member "result" with
       | `String r when String.trim r <> "" -> r
       | _ -> out
       | exception _ -> out)

(* Recorre siempre la cabecera entera: el tiempo no dice cuánto acertó. *)
let iguales a b =
  let n = String.length a in
  let d = ref (n lxor String.length b) in
  for i = 0 to n - 1 do
    let c = if i < String.length b then Char.code b.[i] else 0 in
    d := !d lor (Char.code a.[i] lxor c)
  done;
  !d = 0

let autorizado ~cabecera ~token =
  match (token, cabecera) with None, _ -> true | Some _, None -> false | Some t, Some c -> iguales c t
