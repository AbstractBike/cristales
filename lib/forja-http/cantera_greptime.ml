(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

type post = Uri.t -> tipo:string -> string -> (int * string, string) result

let columnas = [ "tarea"; "plantilla"; "entrada"; "salida"; "contrastada"; "contraste"; "defecto" ]

(* Las columnas opcionales se escriben siempre (cadena vacía si no hay) para
   que existan desde la primera fila y el SELECT no falle. *)
let json (m : Forja.Cantera.muestra) =
  let s x = `String x and o x = `String (Option.value ~default:"" x) in
  `List
    [ `Assoc
        [ ("tarea", s (Forja.Tarea.to_string m.tarea));
          ("plantilla", s m.plantilla);
          ("entrada", s m.entrada);
          ("salida", s m.salida);
          ("contrastada", `Bool (Option.is_some m.contraste));
          ("contraste", o m.contraste);
          ("defecto", o m.defecto) ] ]

let fila = function
  | `List
      [ `String tarea; `String plantilla; `String entrada; `String salida;
        `Bool contrastada; `String contraste; `String defecto ] -> (
      match Forja.Tarea.explicita tarea with
      | Error _ -> None
      | Ok tarea ->
          Some
            { Forja.Cantera.tarea; plantilla; entrada; salida;
              contraste = (if contrastada then Some contraste else None);
              defecto = (if defecto = "" then None else Some defecto) })
  | _ -> None

let filas j =
  let open Yojson.Safe.Util in
  try
    j |> member "output" |> to_list
    |> List.concat_map (fun o ->
           o |> member "records" |> member "rows" |> to_list)
    |> List.filter_map fila
  with Type_error _ -> []

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
  let registrar m =
    avisar (post ingesta ~tipo:"application/json" (Yojson.Safe.to_string (json m)))
  in
  (* La tarea es un nombre validado ([a-z0-9-]): se puede citar sin
     escapar. *)
  let muestras tarea =
    let consulta =
      Printf.sprintf "SELECT %s FROM %s WHERE tarea = '%s' ORDER BY greptime_timestamp"
        (String.concat ", " columnas) tabla (Forja.Tarea.to_string tarea)
    in
    match sql db consulta with
    | Ok (c, b) when c < 300 -> (
        try filas (Yojson.Safe.from_string b) with Yojson.Json_error _ -> [])
    | Ok _ | Error _ -> []
  in
  { Forja.Cantera.registrar; muestras }
