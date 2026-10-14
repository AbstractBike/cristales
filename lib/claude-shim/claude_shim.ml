(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Yojson.Safe.Util

type prompt = { system : string; user : string }

type peticion = {
  modelo : string;
  alias : string;
  prompt : prompt;
  herramienta : (string * Yojson.Safe.t) option;
  max_tokens : int option;
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

(* Claude Code solo admite un prompt por stdin: una conversación de varios
   turnos (los ejemplos y advertencias que antepone la agencia) va como
   transcripción, cada turno con su rol, y la última entrada al final. Un
   solo turno de user va tal cual, como siempre. *)
let instrucciones_transcripcion =
  "La conversación llega como transcripción: cada turno entre <turno rol=\"user\"> o <turno rol=\"assistant\"> y \
   </turno>. Los turnos anteriores al último son contexto (ejemplos, advertencias, respuestas previas). Responde \
   únicamente al último turno de user, como lo haría el asistente, sin etiquetas <turno>."

let transcripcion turnos =
  String.concat "\n\n" (List.map (fun (rol, t) -> Printf.sprintf "<turno rol=\"%s\">\n%s\n</turno>" rol t) turnos)

let conversacion system mensajes =
  let leer m =
    let rol = match member "role" m with `String r -> r | _ -> "user" in
    Option.map (fun t -> (rol, t)) (texto (member "content" m))
  in
  let turnos = List.filter_map leer mensajes in
  (* El system de estilo Chat Completions, al sistema. *)
  let extra, turnos = List.partition (fun (rol, _) -> rol = "system") turnos in
  let system = String.concat "\n\n" (List.filter (fun s -> String.trim s <> "") (system :: List.map snd extra)) in
  match turnos with
  | [] -> None
  | [ ("user", t) ] -> Some (system, t)
  | _ ->
      let system = if String.trim system = "" then instrucciones_transcripcion else system ^ "\n\n" ^ instrucciones_transcripcion in
      Some (system, transcripcion turnos)

let peticion cuerpo =
  match Yojson.Safe.from_string cuerpo with
  | exception Yojson.Json_error e -> Error ("el cuerpo no es JSON: " ^ e)
  | j -> (
      try
        let modelo = match member "model" j with `String m -> m | _ -> "sonnet" in
        let system = Option.value ~default:"" (texto (member "system" j)) in
        let max_tokens = match member "max_tokens" j with `Int n when n > 0 -> Some n | _ -> None in
        let conv = match member "messages" j with `List ms -> conversacion system ms | _ -> None in
        let system, user = match conv with Some (s, u) -> (s, Some u) | None -> (system, None) in
        let herramienta =
          match member "tools" j with
          | `List (t :: _) ->
              let nombre = match member "name" t with `String n -> n | _ -> "structured_output" in
              let schema = match member "input_schema" t with `Assoc _ as s -> s | _ -> `Assoc [] in
              Some (nombre, schema)
          | _ -> None
        in
        match user with
        | None -> Error "messages sin contenido de texto"
        | Some user ->
            let prompt =
              match herramienta with
              | None -> { system; user }
              | Some (nombre, schema) -> { system = instrucciones_esquema system nombre schema; user }
            in
            Ok { modelo; alias = alias modelo; prompt; herramienta; max_tokens }
      with Type_error (m, _) -> Error m)

(* Una salida larga no cabe en el tope fijo: 20k tokens a ~50 tok/s son
   400 s, y a los 180 s el CLI moría y el cliente se quedaba sin nada. El
   plazo crece con el max_tokens que pide el cliente, sin pasar de [techo]. *)
let plazo ~base ~techo ~tokens_por_s max_tokens =
  let pedido = match max_tokens with Some n -> float_of_int n /. tokens_por_s | None -> 0. in
  Float.min techo (Float.max base pedido)

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
        (* Con los de la caché: el CLI cachea el system, y sin ellos la entrada
           de un encargo largo salía en 2 tokens. *)
        ( "usage",
          `Assoc
            (List.map
               (fun k -> (k, `Int (entero uso k)))
               [ "input_tokens"; "cache_creation_input_tokens"; "cache_read_input_tokens"; "output_tokens" ]) ) ])

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
