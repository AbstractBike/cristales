(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let versiones = [ "2025-11-25"; "2025-06-18"; "2025-03-26"; "2024-11-05" ]
let version = List.hd versiones

(* {1 Herramientas} *)

let cadena = `Assoc [ ("type", `String "string") ]
let entero = `Assoc [ ("type", `String "integer") ]

let esquema ?(requeridos = []) props =
  `Assoc
    ([ ("type", `String "object"); ("properties", `Assoc props) ]
    @ if requeridos = [] then [] else [ ("required", `List (List.map (fun r -> `String r) requeridos)) ])

let herramienta nombre descripcion inputSchema =
  `Assoc [ ("name", `String nombre); ("description", `String descripcion); ("inputSchema", inputSchema) ]

let texto ?(error = false) s =
  `Assoc
    [ ("content", `List [ `Assoc [ ("type", `String "text"); ("text", `String s) ] ]);
      ("isError", `Bool error) ]

(* {1 Llamadas} *)

type error = int * string

let invalido m = Error (-32602, m)

let argumento args k =
  match Yojson.Safe.Util.member k args with
  | `Null -> Ok None
  | v -> Ok (Some v)
  | exception Yojson.Safe.Util.Type_error _ -> invalido "arguments no es un objeto"

(* {1 Servidor} *)

type servidor = {
  nombre : string;
  version : string;
  instrucciones : unit -> string;
  herramientas : unit -> Yojson.Safe.t list;
  llamar : string -> Yojson.Safe.t -> (Yojson.Safe.t, error) result;
}

let inicializar s params =
  let pedida = try Yojson.Safe.Util.(params |> member "protocolVersion" |> to_string_option) with _ -> None in
  `Assoc
    [ ( "protocolVersion",
        `String (match pedida with Some v when List.mem v versiones -> v | _ -> version) );
      ("capabilities", `Assoc [ ("tools", `Assoc []) ]);
      ("serverInfo", `Assoc [ ("name", `String s.nombre); ("version", `String s.version) ]);
      ("instructions", `String (s.instrucciones ())) ]

let llamar s params =
  let open Yojson.Safe.Util in
  let args = match params |> member "arguments" with `Null -> `Assoc [] | a -> a in
  match params |> member "name" with
  | `String n -> s.llamar n args
  | _ -> invalido "falta name"
  | exception Type_error _ -> invalido "params no es un objeto"

let resultado s metodo params =
  match metodo with
  | "initialize" -> Ok (inicializar s params)
  | "ping" -> Ok (`Assoc [])
  | "tools/list" -> Ok (`Assoc [ ("tools", `List (s.herramientas ())) ])
  | "tools/call" -> llamar s params
  | m -> Error (-32601, m ^ ": método desconocido")

let respuesta id = function
  | Ok r -> `Assoc [ ("jsonrpc", `String "2.0"); ("id", id); ("result", r) ]
  | Error (codigo, mensaje) ->
      `Assoc
        [ ("jsonrpc", `String "2.0");
          ("id", id);
          ("error", `Assoc [ ("code", `Int codigo); ("message", `String mensaje) ]) ]

let responder s msg =
  let open Yojson.Safe.Util in
  match msg |> member "id" with
  | `Null -> None
  | id -> (
      match msg |> member "method" with
      | `String m -> Some (respuesta id (resultado s m (msg |> member "params")))
      | _ -> Some (respuesta id (Error (-32600, "falta method"))))
  | exception Type_error _ -> Some (respuesta `Null (Error (-32600, "no es un objeto")))

let linea s l =
  if String.trim l = "" then None
  else
    match Yojson.Safe.from_string l with
    | j -> Option.map Yojson.Safe.to_string (responder s j)
    | exception Yojson.Json_error e -> Some (Yojson.Safe.to_string (respuesta `Null (Error (-32700, e))))
