(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red del servidor MCP: la vitrina como herramientas. *)

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let tarea n = Result.get_ok (Forja.Tarea.explicita n)

let mayus =
  Cristal.cristal "mayus" (fun s ->
      if s = "" then Error "entrada vacía" else Ok (String.uppercase_ascii s))

let vitrina = Forja.Vitrina.(vacia |> con (tarea "mayus") `Mixta mayus ~descripcion:"Mayúsculas.")

let pide l =
  Option.map Yojson.Safe.from_string (Forja_mcp.linea (Forja_mcp.local vitrina) l)

let campo ruta j =
  List.fold_left (fun j k -> Yojson.Safe.Util.member k j) j ruta

let llamada id args =
  Printf.sprintf
    {|{"jsonrpc":"2.0","id":%d,"method":"tools/call","params":{"name":"mayus","arguments":%s}}|}
    id args

let () =
  (match pide {|{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}|} with
  | Some r ->
      comprueba "initialize acepta una versión conocida"
        (campo [ "result"; "protocolVersion" ] r = `String "2025-06-18");
      comprueba "initialize anuncia herramientas"
        (campo [ "result"; "capabilities"; "tools" ] r <> `Null)
  | None -> comprueba "initialize responde" false);
  (match pide {|{"jsonrpc":"2.0","id":2,"method":"initialize","params":{"protocolVersion":"1999-01-01"}}|} with
  | Some r ->
      comprueba "versión desconocida: ofrece la suya"
        (campo [ "result"; "protocolVersion" ] r = `String Forja_mcp.version)
  | None -> ());
  comprueba "las notificaciones no se responden"
    (pide {|{"jsonrpc":"2.0","method":"notifications/initialized"}|} = None);
  comprueba "las líneas vacías se ignoran" (pide "" = None);
  (match pide {|{"jsonrpc":"2.0","id":3,"method":"tools/list"}|} with
  | Some r -> (
      match campo [ "result"; "tools" ] r with
      | `List [ h ] ->
          comprueba "la herramienta se llama como la tarea" (campo [ "name" ] h = `String "mayus");
          comprueba "lleva la descripción de la vitrina"
            (campo [ "description" ] h = `String "Mayúsculas.")
      | _ -> comprueba "tools/list da un cristal" false)
  | None -> ());
  (match pide (llamada 4 {|{"entrada":"hola"}|}) with
  | Some r ->
      comprueba "el cristal responde"
        (campo [ "result"; "content" ] r
        = `List [ `Assoc [ ("type", `String "text"); ("text", `String "HOLA") ] ]);
      comprueba "sin error" (campo [ "result"; "isError" ] r = `Bool false)
  | None -> ());
  (match pide (llamada 5 {|{"entrada":""}|}) with
  | Some r ->
      comprueba "un defecto es un resultado con isError"
        (campo [ "result"; "isError" ] r = `Bool true && campo [ "error" ] r = `Null)
  | None -> ());
  (match pide (llamada 6 {|{}|}) with
  | Some r -> comprueba "sin entrada: parámetros inválidos" (campo [ "error"; "code" ] r = `Int (-32602))
  | None -> ());
  (match pide {|{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"otro","arguments":{"entrada":"x"}}}|} with
  | Some r -> comprueba "cristal inexistente" (campo [ "error"; "code" ] r = `Int (-32602))
  | None -> ());
  (match pide {|{"jsonrpc":"2.0","id":8,"method":"resources/list"}|} with
  | Some r -> comprueba "método desconocido" (campo [ "error"; "code" ] r = `Int (-32601))
  | None -> ());
  (match pide "no es json" with
  | Some r -> comprueba "error de análisis" (campo [ "error"; "code" ] r = `Int (-32700))
  | None -> comprueba "responde al JSON roto" false);
  if !fallos > 0 then exit 1
