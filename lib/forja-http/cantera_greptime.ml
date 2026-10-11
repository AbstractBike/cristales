(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type post = Uri.t -> tipo:string -> string -> (int * string, string) result

let columnas =
  [ "tarea"; "plantilla"; "entrada"; "salida"; "contrastada"; "contraste"; "defecto"; "respondida" ]

(* Las columnas opcionales se escriben siempre (cadena vacía si no hay) para
   que existan desde la primera fila y el SELECT no falle. *)
let json (m : Forja.Cantera.muestra) =
  let s x = `String x and o x = `String (Option.value ~default:"" x) in
  `List
    [ `Assoc
        [ ("tarea", s (Forja.Tarea.to_string m.tarea));
          ("plantilla", s m.plantilla);
          ("entrada", s m.entrada);
          ("salida", o m.salida);
          ("contrastada", `Bool (Option.is_some m.contraste));
          ("contraste", o m.contraste);
          ("defecto", o m.defecto);
          ("respondida", `Bool (Option.is_some m.salida)) ] ]

let fila = function
  | `List
      [ `String tarea; `String plantilla; `String entrada; `String salida;
        `Bool contrastada; `String contraste; `String defecto; respondida ] -> (
      match Forja.Tarea.explicita tarea with
      | Error _ -> None
      | Ok tarea ->
          Some
            { Forja.Cantera.tarea; plantilla; entrada;
              (* Las filas de antes de [respondida] la tienen a null: todas
                 venían del LLM. *)
              salida = (if respondida = `Bool false then None else Some salida);
              contraste = (if contrastada then Some contraste else None);
              defecto = (if defecto = "" then None else Some defecto) })
  | _ -> None

(* Las filas de la respuesta de /v1/sql. *)
let crudas j =
  let open Yojson.Safe.Util in
  try
    j |> member "output" |> to_list
    |> List.concat_map (fun o -> o |> member "records" |> member "rows" |> to_list)
  with Type_error _ -> []

let filas j = List.filter_map fila (crudas j)

(* GreptimeDB caído o con error: se cuenta y se sigue. *)
let avisar = function
  | Ok (c, _) when c < 300 -> ()
  | Ok (c, b) -> Printf.eprintf "forja: cantera greptime %d: %s\n%!" c b
  | Error e -> Printf.eprintf "forja: cantera greptime: %s\n%!" e

let crear ~post ~url ?(db = "public") ?(tabla = "forja_cantera") () =
  let con_ruta ruta query = Uri.with_query' (Uri.with_path url ruta) query in
  let ingesta =
    con_ruta "/v1/ingest"
      [ ("db", db); ("table", tabla); ("pipeline_name", "greptime_identity") ]
  in
  let sql en consulta =
    post (con_ruta "/v1/sql" [ ("db", en) ])
      ~tipo:"application/x-www-form-urlencoded"
      (Uri.encoded_of_query [ ("sql", [ consulta ]) ])
  in
  (* La base se crea al arrancar (desde [public], que siempre existe); la
     tabla la crea la primera ingesta. *)
  avisar (sql "public" (Printf.sprintf "CREATE DATABASE IF NOT EXISTS %s" db));
  (* Una tabla de antes no tiene las columnas nuevas hasta la primera
     ingesta que las traiga, y el SELECT de [muestras] fallaría. Si la tabla
     aún no existe, falla sin más: la crea la primera ingesta. *)
  ignore (sql db (Printf.sprintf "ALTER TABLE %s ADD COLUMN IF NOT EXISTS respondida BOOLEAN" tabla));
  let registrar m =
    avisar (post ingesta ~tipo:"application/json" (Yojson.Safe.to_string (json m)))
  in
  (* Lo que se pueda leer; nada si la tabla aún no existe. *)
  let leer consulta =
    match sql db consulta with
    | Ok (c, b) when c < 300 -> ( try crudas (Yojson.Safe.from_string b) with Yojson.Json_error _ -> [])
    | Ok _ | Error _ -> []
  in
  (* La tarea es un nombre validado ([a-z0-9-]): se puede citar sin
     escapar. *)
  let muestras tarea =
    leer
      (Printf.sprintf "SELECT %s FROM %s WHERE tarea = '%s' ORDER BY greptime_timestamp"
         (String.concat ", " columnas) tabla (Forja.Tarea.to_string tarea))
    |> List.filter_map fila
  in
  let tareas () =
    leer (Printf.sprintf "SELECT DISTINCT tarea FROM %s ORDER BY tarea" tabla)
    |> List.filter_map (function
         | `List [ `String t ] -> Result.to_option (Forja.Tarea.explicita t)
         | _ -> None)
  in
  { Forja.Cantera.registrar; muestras; tareas }
