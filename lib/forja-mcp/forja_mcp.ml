(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let versiones = [ "2025-11-25"; "2025-06-18"; "2025-03-26"; "2024-11-05" ]
let version = List.hd versiones

let herramienta (p : Forja.Vitrina.pieza) =
  `Assoc
    [ ("name", `String (Forja.Tarea.to_string p.tarea));
      ("description", `String p.descripcion);
      ( "inputSchema",
        `Assoc
          [ ("type", `String "object");
            ( "properties",
              `Assoc [ ("entrada", `Assoc [ ("type", `String "string") ]) ] );
            ("required", `List [ `String "entrada" ]) ] ) ]

let texto ?(error = false) s =
  `Assoc
    [ ("content", `List [ `Assoc [ ("type", `String "text"); ("text", `String s) ] ]);
      ("isError", `Bool error) ]

(* Un defecto no es un fallo del protocolo: es un resultado con isError,
   para que el modelo lo lea y siga. *)
let llamar vitrina params =
  let open Yojson.Safe.Util in
  let nombre = params |> member "name" |> to_string_option in
  let entrada = params |> member "arguments" |> member "entrada" |> to_string_option in
  match nombre, entrada with
  | None, _ -> Error (-32602, "falta name")
  | Some n, None -> Error (-32602, n ^ ": falta arguments.entrada (texto)")
  | Some n, Some e -> (
      match Result.to_option (Forja.Tarea.explicita n) |> Option.map (Forja.Vitrina.buscar vitrina) with
      | None | Some None -> Error (-32602, n ^ ": no hay tal cristal en la vitrina")
      | Some (Some (_, c)) -> (
          match c.aplicar e with
          | Ok s -> Ok (texto s)
          | Error motivo -> Ok (texto ~error:true ("defecto: " ^ motivo))))

let inicializar params =
  let pedida = Yojson.Safe.Util.(params |> member "protocolVersion" |> to_string_option) in
  `Assoc
    [ ( "protocolVersion",
        `String (match pedida with Some v when List.mem v versiones -> v | _ -> version) );
      ("capabilities", `Assoc [ ("tools", `Assoc []) ]);
      ("serverInfo", `Assoc [ ("name", `String "forja-mcp"); ("version", `String "0.1.0") ]) ]

let resultado vitrina metodo params =
  match metodo with
  | "initialize" -> Ok (inicializar params)
  | "ping" -> Ok (`Assoc [])
  | "tools/list" ->
      Ok (`Assoc [ ("tools", `List (List.map herramienta (Forja.Vitrina.listar vitrina))) ])
  | "tools/call" -> llamar vitrina params
  | m -> Error (-32601, m ^ ": método desconocido")

let respuesta id = function
  | Ok r -> `Assoc [ ("jsonrpc", `String "2.0"); ("id", id); ("result", r) ]
  | Error (codigo, mensaje) ->
      `Assoc
        [ ("jsonrpc", `String "2.0");
          ("id", id);
          ("error", `Assoc [ ("code", `Int codigo); ("message", `String mensaje) ]) ]

let responder vitrina msg =
  let open Yojson.Safe.Util in
  match msg |> member "id" with
  | `Null -> None
  | id -> (
      match msg |> member "method" |> to_string_option with
      | None -> Some (respuesta id (Error (-32600, "falta method")))
      | Some m -> Some (respuesta id (resultado vitrina m (msg |> member "params"))))
  | exception Type_error _ -> Some (respuesta `Null (Error (-32600, "no es un objeto")))

let linea vitrina l =
  if String.trim l = "" then None
  else
  match Yojson.Safe.from_string l with
  | j -> Option.map Yojson.Safe.to_string (responder vitrina j)
  | exception Yojson.Json_error e ->
      Some (Yojson.Safe.to_string (respuesta `Null (Error (-32700, e))))
