(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let cabecera_tarea = "x-forja-tarea"
let ( let* ) = Result.bind
let campo k = function `Assoc l -> List.assoc_opt k l | _ -> None

type forma = Texto | Herramienta of string

(* JSON con las claves ordenadas: dos respuestas iguales del LLM dan la
   misma cadena aunque cambie el orden de los campos. *)
let rec canonico = function
  | `Assoc l ->
      `Assoc (List.sort (fun (a, _) (b, _) -> compare a b) (List.map (fun (k, v) -> (k, canonico v)) l))
  | `List l -> `List (List.map canonico l)
  | j -> j

let cadena j = Yojson.Safe.to_string (canonico j)

(* El contenido es una cadena o una lista de bloques; solo vale si todos
   son de texto. *)
let solo_texto = function
  | `String s -> Some s
  | `List bloques ->
      List.fold_right
        (fun b acc ->
          match (acc, campo "type" b, campo "text" b) with
          | Some ts, Some (`String "text"), Some (`String t) -> Some (t :: ts)
          | _ -> None)
        bloques (Some [])
      |> Option.map (String.concat "\n")
  | _ -> None

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
  | Herramienta n -> (
      match Yojson.Safe.from_string s with
      | `Assoc _ as input ->
          Ok
            (mensaje ~modelo ~parada:"tool_use"
               (`Assoc
                 [ ("type", `String "tool_use");
                   ("id", `String ("toolu_forja_" ^ String.sub (Digest.to_hex (Digest.string s)) 0 16));
                   ("name", `String n);
                   ("input", input) ]))
      | _ -> Error "la salida del cristal no es un objeto JSON"
      | exception Yojson.Json_error e -> Error ("la salida del cristal no es JSON: " ^ e))

let error ~tipo mensaje =
  `Assoc
    [ ("type", `String "error");
      ("error", `Assoc [ ("type", `String tipo); ("message", `String mensaje) ]) ]
