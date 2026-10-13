(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

module G = Forja_http.Greptime

let col c = "\"" ^ c ^ "\""
let lista = String.concat ", " (List.map col Atomo.columnas)

let ok = function
  | Ok (c, _) when c < 300 -> Ok ()
  | Ok (c, b) -> Error (Printf.sprintf "greptime %d: %s" c b)
  | Error e -> Error e

let crear_tabla g =
  ok
    (G.sql g
       {|CREATE TABLE IF NOT EXISTS memoria_l1 ("ts" TIMESTAMP(3) NOT NULL, "id" STRING, "version" INT, "vigente" BOOLEAN, "tipo" STRING, "prioridad" INT, "escena" STRING, "contenido" STRING FULLTEXT INDEX, "proyecto" STRING, "origen" STRING, "fechas" STRING, TIME INDEX ("ts"), PRIMARY KEY ("id"))|})

let desde g cursor =
  (* Todas las versiones de los ids que se movieron: la vigente puede ser
     una anterior al cursor solo si la nueva la descarta, y entonces no
     sale. *)
  G.leer g
    (Printf.sprintf
       {|SELECT %s FROM memoria_l1 WHERE "id" IN (SELECT "id" FROM memoria_l1 WHERE "ts" > to_timestamp_millis(%d)) ORDER BY "ts"|}
       lista cursor)
  |> List.filter_map Atomo.de_fila
  |> Atomo.vigentes
  |> List.filter (fun (a : Atomo.t) -> a.ts > cursor)

let ids g =
  G.leer g {|SELECT DISTINCT "id" FROM memoria_l1|}
  |> List.filter_map (function `List [ `String i ] -> Some i | _ -> None)

let cadena s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '\'';
  String.iter (fun c -> if c = '\'' then Buffer.add_string b "''" else Buffer.add_char b c) s;
  Buffer.add_char b '\'';
  Buffer.contents b

let fila (a : Atomo.t) =
  Printf.sprintf "(%d, %s, %d, %b, %s, %d, %s, %s, %s, %s, %s)" a.ts (cadena a.id) a.version a.vigente (cadena a.tipo)
    a.prioridad (cadena a.escena) (cadena a.contenido) (cadena a.proyecto) (cadena a.origen) (cadena a.fechas)

let insertar_sql atomos =
  Printf.sprintf "INSERT INTO memoria_l1 (%s) VALUES %s" lista (String.concat ", " (List.map fila atomos))

let insertar g atomos =
  let rec ir n = function
    | [] -> Ok n
    | l ->
        let lote = List.filteri (fun i _ -> i < 50) l and resto = List.filteri (fun i _ -> i >= 50) l in
        Result.bind (ok (G.sql g (insertar_sql lote))) (fun () -> ir (n + List.length lote) resto)
  in
  ir 0 atomos
