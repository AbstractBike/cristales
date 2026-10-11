(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let versiones = [ "2025-11-25"; "2025-06-18"; "2025-03-26"; "2024-11-05" ]
let version = List.hd versiones

type cristal = { nombre : string; descripcion : string }
type aplicado = Salida of string | Defecto of string | No_existe | Fallo of string

type fuente = {
  cristales : unit -> (cristal list, string) result;
  aplicar : string -> string -> aplicado;
  consultar : (string -> (string, string) result) option;
}

let local vitrina =
  { cristales =
      (fun () ->
        Ok
          (List.map
             (fun (p : Forja.Vitrina.pieza) ->
               { nombre = Forja.Tarea.to_string p.tarea; descripcion = p.descripcion })
             (Forja.Vitrina.listar vitrina)));
    aplicar =
      (fun n e ->
        match Result.to_option (Forja.Tarea.explicita n) |> Option.map (Forja.Vitrina.buscar vitrina) with
        | None | Some None -> No_existe
        | Some (Some (_, c)) -> ( match c.aplicar e with Ok s -> Salida s | Error m -> Defecto m));
    consultar = None }

(* {1 Herramientas} *)

let cadena = `Assoc [ ("type", `String "string") ]

let esquema ?(requeridos = []) props =
  `Assoc
    ([ ("type", `String "object"); ("properties", `Assoc props) ]
    @ if requeridos = [] then [] else [ ("required", `List (List.map (fun r -> `String r) requeridos)) ])

let herramienta nombre descripcion inputSchema =
  `Assoc [ ("name", `String nombre); ("description", `String descripcion); ("inputSchema", inputSchema) ]

(* Las fijas: nombre, descripción, esquema y la ruta de la API a la que
   llaman, a partir de los argumentos ya validados. *)
type fija = { nombre : string; descripcion : string; esquema : Yojson.Safe.t; ruta : string -> int -> string }

let tarea = [ ("tarea", cadena) ]

let fijas =
  [ { nombre = "forja_tareas";
      descripcion =
        "Tareas que han pasado por la forja: fase (liquida, mixta o cristalina), muestras en la \
         cantera, contrastes, coincidencias y si ya está madura para nuclear.";
      esquema = esquema [];
      ruta = (fun _ _ -> "/forja/tareas") };
    { nombre = "forja_tarea";
      descripcion =
        "Detalle de una tarea de la forja: su informe, su plantilla (las instrucciones fijas) y \
         sus últimas muestras de la cantera.";
      esquema = esquema ~requeridos:[ "tarea" ] (tarea @ [ ("muestras", `Assoc [ ("type", `String "integer") ]) ]);
      ruta = (fun t n -> Printf.sprintf "/forja/tareas/%s?muestras=%d" t n) };
    { nombre = "forja_semilla";
      descripcion =
        "SEMILLA.md de una tarea: la plantilla y las muestras de la cantera, en el formato con el \
         que se nuclea un cristal.";
      esquema = esquema ~requeridos:[ "tarea" ] tarea;
      ruta = (fun t _ -> Printf.sprintf "/forja/tareas/%s/semilla" t) };
    { nombre = "forja_nucleacion";
      descripcion =
        "Prompt de nucleación de una tarea: lo que se le pide al LLM para que escriba el cristal \
         (el método, no el resultado).";
      esquema = esquema ~requeridos:[ "tarea" ] tarea;
      ruta = (fun t _ -> Printf.sprintf "/forja/tareas/%s/nucleacion" t) } ]

let listar fuente =
  let fijas =
    if fuente.consultar = None then []
    else List.map (fun f -> herramienta f.nombre f.descripcion f.esquema) fijas
  in
  let cristales =
    match fuente.cristales () with
    | Ok cs ->
        List.map
          (fun (c : cristal) -> herramienta c.nombre c.descripcion (esquema ~requeridos:[ "entrada" ] [ ("entrada", cadena) ]))
          cs
    | Error e ->
        prerr_endline ("forja-mcp: sin vitrina: " ^ e);
        []
  in
  `Assoc [ ("tools", `List (fijas @ cristales)) ]

let texto ?(error = false) s =
  `Assoc
    [ ("content", `List [ `Assoc [ ("type", `String "text"); ("text", `String s) ] ]);
      ("isError", `Bool error) ]

(* {1 Llamadas} *)

let ( let* ) = Result.bind
let invalido m = Error (-32602, m)

let argumento args k =
  match Yojson.Safe.Util.member k args with
  | `Null -> Ok None
  | v -> Ok (Some v)
  | exception Yojson.Safe.Util.Type_error _ -> invalido "arguments no es un objeto"

let nombre_de_tarea n =
  match Forja.Tarea.explicita n with Ok _ -> Ok n | Error _ -> invalido (n ^ ": no es un nombre de tarea")

let llamar_fija consultar (f : fija) args =
  let* t =
    if f.nombre = "forja_tareas" then Ok ""
    else
      match argumento args "tarea" with
      | Ok (Some (`String t)) -> nombre_de_tarea t
      | Ok _ -> invalido (f.nombre ^ ": falta tarea (texto)")
      | Error e -> Error e
  in
  let* n =
    match argumento args "muestras" with
    | Ok None -> Ok 5
    | Ok (Some (`Int n)) when n >= 0 && n <= 1000 -> Ok n
    | Ok (Some _) -> invalido "muestras: entero de 0 a 1000"
    | Error e -> Error e
  in
  Ok (match consultar (f.ruta t n) with Ok s -> texto s | Error e -> texto ~error:true e)

let llamar_cristal fuente n args =
  let* n = nombre_de_tarea n in
  match argumento args "entrada" with
  | Ok (Some (`String e)) -> (
      match fuente.aplicar n e with
      | Salida s -> Ok (texto s)
      (* Un defecto no es un fallo del protocolo: es un resultado con
         isError, para que el modelo lo lea y siga. *)
      | Defecto m -> Ok (texto ~error:true ("defecto: " ^ m))
      | No_existe -> invalido (n ^ ": no hay tal cristal en la vitrina")
      | Fallo e -> Ok (texto ~error:true e))
  | Ok _ -> invalido (n ^ ": falta arguments.entrada (texto)")
  | Error e -> Error e

let llamar fuente params =
  let open Yojson.Safe.Util in
  let args = match params |> member "arguments" with `Null -> `Assoc [] | a -> a in
  match params |> member "name" with
  | `String n -> (
      match (fuente.consultar, List.find_opt (fun f -> f.nombre = n) fijas) with
      | Some consultar, Some f -> llamar_fija consultar f args
      | _ -> llamar_cristal fuente n args)
  | _ -> invalido "falta name"
  | exception Type_error _ -> invalido "params no es un objeto"

(* {1 JSON-RPC} *)

let inicializar params =
  let pedida = try Yojson.Safe.Util.(params |> member "protocolVersion" |> to_string_option) with _ -> None in
  `Assoc
    [ ( "protocolVersion",
        `String (match pedida with Some v when List.mem v versiones -> v | _ -> version) );
      ("capabilities", `Assoc [ ("tools", `Assoc []) ]);
      ("serverInfo", `Assoc [ ("name", `String "forja-mcp"); ("version", `String "0.2.0") ]) ]

let resultado fuente metodo params =
  match metodo with
  | "initialize" -> Ok (inicializar params)
  | "ping" -> Ok (`Assoc [])
  | "tools/list" -> Ok (listar fuente)
  | "tools/call" -> llamar fuente params
  | m -> Error (-32601, m ^ ": método desconocido")

let respuesta id = function
  | Ok r -> `Assoc [ ("jsonrpc", `String "2.0"); ("id", id); ("result", r) ]
  | Error (codigo, mensaje) ->
      `Assoc
        [ ("jsonrpc", `String "2.0");
          ("id", id);
          ("error", `Assoc [ ("code", `Int codigo); ("message", `String mensaje) ]) ]

let responder fuente msg =
  let open Yojson.Safe.Util in
  match msg |> member "id" with
  | `Null -> None
  | id -> (
      match msg |> member "method" with
      | `String m -> Some (respuesta id (resultado fuente m (msg |> member "params")))
      | _ -> Some (respuesta id (Error (-32600, "falta method"))))
  | exception Type_error _ -> Some (respuesta `Null (Error (-32600, "no es un objeto")))

let linea fuente l =
  if String.trim l = "" then None
  else
    match Yojson.Safe.from_string l with
    | j -> Option.map Yojson.Safe.to_string (responder fuente j)
    | exception Yojson.Json_error e -> Some (Yojson.Safe.to_string (respuesta `Null (Error (-32700, e))))
