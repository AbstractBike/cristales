(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red del shim: las mismas que tenía ClaudeCodeShimTest.kt en trabajo-kt,
   más el texto llano de la agencia. *)

open Claude_shim

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let campo ruta j = List.fold_left (fun j k -> Yojson.Safe.Util.member k j) j ruta
let ok = function Ok x -> x | Error e -> failwith e

let () =
  (* Con herramienta: lo nuestro en el sistema, lo ajeno aparte. *)
  let p =
    ok
      (peticion
         {|{"model":"claude-3-5-sonnet-20241022","max_tokens":4096,"system":"Eres ranker",
            "messages":[{"role":"user","content":"Puntúa este job"}],
            "tools":[{"name":"rank_tool","description":"d","input_schema":{"type":"object","properties":{"score":{},"tier":{}}}}],
            "tool_choice":{"type":"tool","name":"rank_tool"}}|})
  in
  comprueba "alias sonnet" (p.alias = "sonnet");
  comprueba "el texto ajeno, aparte" (p.prompt.user = "Puntúa este job");
  let contiene sub s =
    let n = String.length sub in
    let rec en i = i + n <= String.length s && (String.sub s i n = sub || en (i + 1)) in
    en 0
  in
  comprueba "lo nuestro, en el sistema" (contiene "Eres ranker" p.prompt.system);
  comprueba "el esqueleto de claves" (contiene {|{"score": ..., "tier": ...}|} p.prompt.system);
  comprueba "y el nombre de la herramienta" (contiene {|"rank_tool"|} p.prompt.system);
  let cli = {|{"is_error":false,"result":"{\"score\":0.7,\"tier\":\"TIER1\"}","usage":{"input_tokens":10,"output_tokens":5}}|} in
  let r = Yojson.Safe.from_string (ok (respuesta p ~id:"x" cli)) in
  comprueba "tool_use" (campo [ "stop_reason" ] r = `String "tool_use");
  (match campo [ "content" ] r with
  | `List [ b ] ->
      comprueba "bloque tool_use" (campo [ "type" ] b = `String "tool_use" && campo [ "name" ] b = `String "rank_tool");
      comprueba "la instancia" (campo [ "input"; "score" ] b = `Float 0.7)
  | _ -> comprueba "un bloque" false);
  comprueba "uso" (campo [ "usage"; "input_tokens" ] r = `Int 10);
  comprueba "el modelo de la petición" (campo [ "model" ] r = `String "claude-3-5-sonnet-20241022");
  (* is_error del CLI. *)
  comprueba "is_error" (Result.is_error (respuesta p ~id:"x" {|{"is_error":true,"result":"Not logged in"}|}));
  (* Sin herramienta: texto llano. *)
  let t =
    ok
      (peticion
         {|{"model":"claude-haiku-5-5","system":"Devuelve en mayúsculas.","messages":[{"role":"user","content":"hola"}]}|})
  in
  comprueba "texto: alias haiku" (t.alias = "haiku");
  comprueba "texto: el prompt tal cual" (t.prompt = { system = "Devuelve en mayúsculas."; user = "hola" });
  let r = Yojson.Safe.from_string (ok (respuesta t ~id:"x" {|{"result":"HOLA","usage":{"output_tokens":2}}|})) in
  comprueba "texto: end_turn" (campo [ "stop_reason" ] r = `String "end_turn");
  comprueba "texto: bloque text"
    (match campo [ "content" ] r with `List [ b ] -> campo [ "text" ] b = `String "HOLA" | _ -> false);
  (* Contenido en bloques. *)
  let b =
    ok (peticion {|{"model":"opus","messages":[{"role":"user","content":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}]}|})
  in
  comprueba "bloques de texto" (b.prompt.user = "a\nb" && b.alias = "opus");
  comprueba "sin mensajes" (Result.is_error (peticion {|{"model":"x"}|}));
  comprueba "no JSON" (Result.is_error (peticion "{"));
  (* extraer_json tolera fences y prosa. *)
  comprueba "fences" (extraer_json "```json\n{\"a\":1}\n```" = Ok (`Assoc [ ("a", `Int 1) ]));
  comprueba "prosa" (extraer_json "Aquí va: {\"a\":1} y ya" = Ok (`Assoc [ ("a", `Int 1) ]));
  comprueba "sin objeto" (Result.is_error (extraer_json "nada"));
  (* El eco del schema. *)
  comprueba "desenvolver"
    (desenvolver (`Assoc [ ("type", `String "object"); ("properties", `Assoc [ ("score", `Int 1) ]) ]) [ "score" ]
    = `Assoc [ ("score", `Int 1) ]);
  comprueba "la instancia se queda" (desenvolver (`Assoc [ ("score", `Int 1) ]) [ "score" ] = `Assoc [ ("score", `Int 1) ]);
  (* Argumentos: sin herramientas, sin MCP, con el sistema aparte. *)
  let a = argumentos ~bin:"claude" ~alias:"haiku" ~system:"S" in
  comprueba "--tools vacío" (List.mem "--strict-mcp-config" a && List.nth a 7 = "" && List.nth a 6 = "--tools");
  comprueba "--system-prompt al final" (List.rev a = "S" :: "--system-prompt" :: List.tl (List.tl (List.rev a)));
  (* Motivos de fallo. *)
  comprueba "stderr manda" (motivo_fallo ~err:"boom" ~out:"{}" = "boom");
  comprueba "si no, el result" (motivo_fallo ~err:"" ~out:{|{"result":"Not logged in"}|} = "Not logged in");
  comprueba "y si no, stdout" (motivo_fallo ~err:"" ~out:"raro" = "raro");
  (* El token. *)
  comprueba "sin token, todo" (autorizado ~cabecera:None ~token:None);
  comprueba "con token, sin cabecera" (not (autorizado ~cabecera:None ~token:(Some "t")));
  comprueba "con token, otra" (not (autorizado ~cabecera:(Some "tt") ~token:(Some "t")));
  comprueba "con token, la suya" (autorizado ~cabecera:(Some "t") ~token:(Some "t"));
  if !fallos > 0 then exit 1
