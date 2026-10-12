(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let ( let* ) = Result.bind
let campo = Comun.campo

type forma = Texto | Esquema

(* Sin response_format, o con {type: text}, la salida es texto. Con un
   json_schema la salida es el objeto que impone: el esquema pasa a la
   plantilla, como la herramienta en Anthropic. Sin esquema (json_object)
   no hay contrato que cristalizar. *)
let forma_de j =
  match Option.map (fun rf -> (rf, campo "type" rf)) (campo "response_format" j) with
  | None | Some (_, Some (`String "text")) -> Ok (Texto, "")
  | Some (rf, Some (`String "json_schema")) -> (
      match campo "json_schema" rf with
      | Some (`Assoc _ as s) -> Ok (Esquema, "\n\n## Esquema\n\n" ^ Comun.cadena s)
      | _ -> Error "json_schema sin esquema")
  | Some _ -> Error "response_format sin json_schema"

(* Un mensaje de system (o developer) opcional y un turno de usuario. *)
let turnos = function
  | `List [ u ] -> Ok ("", u)
  | `List [ s; u ]
    when List.mem (campo "role" s) [ Some (`String "system"); Some (`String "developer") ] -> (
      match Option.bind (campo "content" s) Comun.solo_texto with
      | Some t -> Ok (t, u)
      | None -> Error "system que no es texto")
  | `List _ -> Error "conversación de varios turnos"
  | _ -> Error "sin messages"

let peticion ~tarea j =
  let* () =
    match campo "stream" j with
    | Some (`Bool true) -> Error "streaming"
    | _ -> Ok ()
  in
  let* () =
    match campo "tools" j with
    | None | Some (`List []) -> Ok ()
    | Some _ -> Error "herramientas"
  in
  let* () =
    match campo "n" j with
    | None | Some (`Int 1) -> Ok ()
    | Some _ -> Error "más de una respuesta (n)"
  in
  let* forma, esquema = forma_de j in
  let* system, u = turnos (Option.value ~default:`Null (campo "messages" j)) in
  let* entrada =
    match (campo "role" u, Option.bind (campo "content" u) Comun.solo_texto) with
    | Some (`String "user"), Some t -> Ok t
    | Some (`String "user"), None -> Error "contenido que no es texto"
    | _ -> Error "el último turno no es del usuario"
  in
  let plantilla = system ^ esquema in
  let* tarea =
    match tarea with
    | Some n -> Forja.Tarea.explicita n
    | None when system = "" -> Error "sin system ni tarea explícita"
    | None -> Ok (Forja.Tarea.de_plantilla plantilla)
  in
  Ok ({ Forja.tarea; plantilla; entrada }, forma)

let salida forma j =
  match campo "choices" j with
  | Some (`List (c :: _)) -> (
      match (campo "finish_reason" c, Option.bind (campo "message" c) (campo "content")) with
      | Some (`String "stop"), Some (`String s) -> (
          match forma with
          | Texto -> Some s
          | Esquema -> Result.to_option (Result.map Comun.cadena (Comun.objeto_json s)))
      | _ -> None)
  | _ -> None

let respuesta ~modelo forma s =
  let* contenido =
    match forma with
    | Texto -> Ok s
    | Esquema -> Result.map Yojson.Safe.to_string (Comun.objeto_json s)
  in
  Ok
    (`Assoc
      [ ("id", `String ("chatcmpl-forja-" ^ String.sub (Digest.to_hex (Digest.string contenido)) 0 16));
        ("object", `String "chat.completion");
        ("created", `Int 0);
        ("model", `String modelo);
        ( "choices",
          `List
            [ `Assoc
                [ ("index", `Int 0);
                  ("message", `Assoc [ ("role", `String "assistant"); ("content", `String contenido) ]);
                  ("finish_reason", `String "stop") ] ] );
        ( "usage",
          `Assoc [ ("prompt_tokens", `Int 0); ("completion_tokens", `Int 0); ("total_tokens", `Int 0) ] ) ])

let error ~tipo mensaje =
  `Assoc [ ("error", `Assoc [ ("message", `String mensaje); ("type", `String tipo); ("code", `Null) ]) ]

(* {1 Cristales parciales} *)

let esquema j = Option.bind (campo "response_format" j) (campo "json_schema")

let campos j =
  match Option.bind (esquema j) (campo "schema") with
  | Some s -> Comun.propiedades s
  | None -> []

let restringir j ks =
  Comun.cambiar "response_format"
    (Comun.cambiar "json_schema" (Comun.cambiar "schema" (Comun.restringir_esquema ks)))
    j
