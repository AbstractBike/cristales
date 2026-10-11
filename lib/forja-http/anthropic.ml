(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

let cabecera_tarea = "x-forja-tarea"
let ( let* ) = Result.bind
let campo k = function `Assoc l -> List.assoc_opt k l | _ -> None

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

let peticion ~tarea j =
  let* () =
    match campo "stream" j with
    | Some (`Bool true) -> Error "streaming"
    | _ -> Ok ()
  in
  let* () =
    match campo "tools" j with
    | Some (`List (_ :: _)) -> Error "herramientas"
    | _ -> Ok ()
  in
  let* entrada =
    match campo "messages" j with
    | Some (`List [ m ]) when campo "role" m = Some (`String "user") -> (
        match Option.bind (campo "content" m) solo_texto with
        | Some t -> Ok t
        | None -> Error "contenido que no es texto")
    | Some (`List _) -> Error "conversación de varios turnos"
    | _ -> Error "sin messages"
  in
  let plantilla =
    Option.value ~default:"" (Option.bind (campo "system" j) solo_texto)
  in
  let* tarea =
    match tarea with
    | Some n -> Forja.Tarea.explicita n
    | None when plantilla = "" -> Error "sin system ni tarea explícita"
    | None -> Ok (Forja.Tarea.de_plantilla plantilla)
  in
  Ok { Forja.tarea; plantilla; entrada }

let texto j =
  match (campo "stop_reason" j, campo "content" j) with
  | Some (`String "end_turn"), Some c -> solo_texto c
  | _ -> None

let respuesta ~modelo t =
  `Assoc
    [ ("id", `String ("msg_forja_" ^ Digest.to_hex (Digest.string t)));
      ("type", `String "message");
      ("role", `String "assistant");
      ("model", `String modelo);
      ("content", `List [ `Assoc [ ("type", `String "text"); ("text", `String t) ] ]);
      ("stop_reason", `String "end_turn");
      ("stop_sequence", `Null);
      ("usage", `Assoc [ ("input_tokens", `Int 0); ("output_tokens", `Int 0) ]) ]

let error ~tipo mensaje =
  `Assoc
    [ ("type", `String "error");
      ("error", `Assoc [ ("type", `String tipo); ("message", `String mensaje) ]) ]
