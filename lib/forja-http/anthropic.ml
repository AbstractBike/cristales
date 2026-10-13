(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let cabecera_tarea = "x-forja-tarea"
let ( let* ) = Result.bind
let campo = Comun.campo
let cadena = Comun.cadena
let solo_texto = Comun.solo_texto

type forma = Texto | Herramienta of string

(* Sin herramientas, la salida es texto. Con herramientas, solo vale una
   forzada: la definición de la herramienta pasa a la plantilla. *)
let forma_de j =
  match (campo "tools" j, campo "tool_choice" j) with
  | (None | Some (`List [])), _ -> Ok (Texto, "")
  | Some (`List tools), Some tc when campo "type" tc = Some (`String "tool") -> (
      match campo "name" tc with
      | Some (`String n) -> (
          match List.find_opt (fun t -> campo "name" t = Some (`String n)) tools with
          | Some t -> Ok (Herramienta n, "\n\n## Herramienta\n\n" ^ cadena t)
          | None -> Error "tool_choice nombra una herramienta que no está")
      | _ -> Error "tool_choice sin nombre")
  | Some _, _ -> Error "herramientas sin tool_choice forzado"

let peticion ~tarea j =
  let* () =
    match campo "stream" j with
    | Some (`Bool true) -> Error "streaming"
    | _ -> Ok ()
  in
  let* forma, herramienta = forma_de j in
  let* entrada =
    match campo "messages" j with
    | Some (`List [ m ]) when campo "role" m = Some (`String "user") -> (
        match Option.bind (campo "content" m) solo_texto with
        | Some t -> Ok t
        | None -> Error "contenido que no es texto")
    (* Con tarea explícita, los turnos previos son ejemplos (few-shot, como
       los que pone la agencia): ni son la entrada ni van a la plantilla.
       Sin ella, una conversación no es una tarea. *)
    | Some (`List (_ :: _ :: _ as turnos)) when Option.is_some tarea -> (
        match Option.bind (Comun.ultimo_de_ejemplos turnos) (fun m -> Option.bind (campo "content" m) solo_texto) with
        | Some t -> Ok t
        | None -> Error "conversación de varios turnos")
    | Some (`List _) -> Error "conversación de varios turnos"
    | _ -> Error "sin messages"
  in
  let system = Option.value ~default:"" (Option.bind (campo "system" j) solo_texto) in
  let plantilla = system ^ herramienta in
  let* tarea =
    match tarea with
    | Some n -> Forja.Tarea.explicita n
    | None when system = "" -> Error "sin system ni tarea explícita"
    | None -> Ok (Forja.Tarea.de_plantilla plantilla)
  in
  Ok ({ Forja.tarea; plantilla; entrada }, forma)

let salida forma j =
  match (forma, campo "stop_reason" j, campo "content" j) with
  | Texto, Some (`String "end_turn"), Some c -> solo_texto c
  | Herramienta n, Some (`String "tool_use"), Some (`List bloques) ->
      List.find_map
        (fun b ->
          match (campo "type" b, campo "name" b, campo "input" b) with
          | Some (`String "tool_use"), Some (`String m), Some (`Assoc _ as i) when m = n ->
              Some (cadena i)
          | _ -> None)
        bloques
  | _ -> None

let texto = salida Texto

let mensaje ~modelo ~parada contenido =
  `Assoc
    [ ("id", `String ("msg_forja_" ^ Digest.to_hex (Digest.string (Yojson.Safe.to_string contenido))));
      ("type", `String "message");
      ("role", `String "assistant");
      ("model", `String modelo);
      ("content", `List [ contenido ]);
      ("stop_reason", `String parada);
      ("stop_sequence", `Null);
      ("usage", `Assoc [ ("input_tokens", `Int 0); ("output_tokens", `Int 0) ]) ]

let respuesta ~modelo forma s =
  match forma with
  | Texto ->
      Ok (mensaje ~modelo ~parada:"end_turn" (`Assoc [ ("type", `String "text"); ("text", `String s) ]))
  | Herramienta n ->
      Result.map
        (fun input ->
          mensaje ~modelo ~parada:"tool_use"
            (`Assoc
              [ ("type", `String "tool_use");
                ("id", `String ("toolu_forja_" ^ String.sub (Digest.to_hex (Digest.string s)) 0 16));
                ("name", `String n);
                ("input", input) ]))
        (Comun.objeto_json s)

let error ~tipo mensaje =
  `Assoc
    [ ("type", `String "error");
      ("error", `Assoc [ ("type", `String tipo); ("message", `String mensaje) ]) ]

(* {1 Cristales parciales} *)

let forzada j =
  match campo "tool_choice" j with
  | Some tc when campo "type" tc = Some (`String "tool") -> (
      match campo "name" tc with Some (`String n) -> Some n | _ -> None)
  | _ -> None

let es n t = campo "name" t = Some (`String n)

let campos j =
  match (forzada j, campo "tools" j) with
  | Some n, Some (`List tools) -> (
      match List.find_opt (es n) tools with
      | Some t -> Option.fold ~none:[] ~some:Comun.propiedades (campo "input_schema" t)
      | None -> [])
  | _ -> []

let restringir j ks =
  match forzada j with
  | None -> j
  | Some n ->
      Comun.cambiar "tools"
        (function
          | `List tools ->
              `List
                (List.map
                   (fun t -> if es n t then Comun.cambiar "input_schema" (Comun.restringir_esquema ks) t else t)
                   tools)
          | x -> x)
        j

let uso j =
  match Option.map (fun u -> (campo "input_tokens" u, campo "output_tokens" u)) (campo "usage" j) with
  | Some (Some (`Int e), Some (`Int s)) -> Some (e, s)
  | _ -> None

(* {1 Ejemplos} *)

let con_ejemplos j = match campo "messages" j with Some (`List (_ :: _ :: _)) -> true | _ -> false
let sin_ejemplos = Comun.sin_ejemplos_en (fun _ -> false)
