(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type post = Uri.t -> tipo:string -> string -> (int * string, string) result
type t = { post : post; url : Uri.t; db : string }

let con_ruta g ruta query = Uri.with_query' (Uri.with_path g.url ruta) query

let sql_en g en consulta =
  g.post (con_ruta g "/v1/sql" [ ("db", en) ])
    ~tipo:"application/x-www-form-urlencoded"
    (Uri.encoded_of_query [ ("sql", [ consulta ]) ])

let sql g = sql_en g g.db

(* GreptimeDB caído o con error: se cuenta y se sigue. *)
let avisar = function
  | Ok (c, _) when c < 300 -> ()
  | Ok (c, b) -> Printf.eprintf "greptime %d: %s\n%!" c b
  | Error e -> Printf.eprintf "greptime: %s\n%!" e

let conectar ~post ~url ~db =
  let g = { post; url; db } in
  avisar (sql_en g "public" (Printf.sprintf "CREATE DATABASE IF NOT EXISTS %s" db));
  g

let ingerir g ~tabla fila =
  avisar
    (g.post
       (con_ruta g "/v1/ingest"
          [ ("db", g.db); ("table", tabla); ("pipeline_name", "greptime_identity") ])
       ~tipo:"application/json"
       (Yojson.Safe.to_string (`List [ fila ])))

let crudas j =
  let open Yojson.Safe.Util in
  try
    j |> member "output" |> to_list
    |> List.concat_map (fun o -> o |> member "records" |> member "rows" |> to_list)
  with Type_error _ -> []

let leer g consulta =
  match sql g consulta with
  | Ok (c, b) when c < 300 -> ( try crudas (Yojson.Safe.from_string b) with Yojson.Json_error _ -> [])
  | Ok _ | Error _ -> []

(* Protocolo de línea de InfluxDB: las etiquetas pasan a ser columnas de la
   clave, y la tabla se puede consultar por PromQL agrupando por ellas. *)
let lineas g texto =
  if texto <> "" then
    avisar
      (g.post (con_ruta g "/v1/influxdb/write" [ ("db", g.db); ("precision", "ms") ])
         ~tipo:"text/plain; charset=utf-8" texto)
