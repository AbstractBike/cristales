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
       {|CREATE TABLE IF NOT EXISTS memoria_l1 ("ts" TIMESTAMP(3) NOT NULL, "id" STRING, "version" INT, "vigente" BOOLEAN, "tipo" STRING, "prioridad" INT, "escena" STRING, "contenido" STRING FULLTEXT INDEX, "proyecto" STRING, "origen" STRING, "fechas" STRING, "escrito" TIMESTAMP(3) NULL, TIME INDEX ("ts"), PRIMARY KEY ("id"))|})
  |> Result.map (fun () ->
         (* Una tabla de antes de [escrito]: se le añade (si ya la tiene, el
            error se ignora). *)
         ignore (G.sql g {|ALTER TABLE memoria_l1 ADD COLUMN "escrito" TIMESTAMP(3) NULL|}))

let seleccion = String.concat ", " (List.map (function "escrito" -> {|COALESCE("escrito", "ts")|} | c -> col c) Atomo.columnas)

let desde g cursor =
  (* Todas las versiones de los ids escritos después del cursor: la vigente
     puede ser una anterior solo si la nueva la descarta, y entonces no sale.
     Sobre [escrito], no sobre [ts]: un lote de una sesión vieja escrito hoy
     tiene un [ts] viejo. *)
  G.leer g
    (Printf.sprintf
       {|SELECT %s FROM memoria_l1 WHERE "id" IN (SELECT "id" FROM memoria_l1 WHERE COALESCE("escrito", "ts") > to_timestamp_millis(%d)) ORDER BY "ts"|}
       seleccion cursor)
  |> List.filter_map Atomo.de_fila
  |> Atomo.vigentes
  |> List.filter (fun (a : Atomo.t) -> a.escrito > cursor)

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
  Printf.sprintf "(%d, %s, %d, %b, %s, %d, %s, %s, %s, %s, %s, %d)" a.ts (cadena a.id) a.version a.vigente (cadena a.tipo)
    a.prioridad (cadena a.escena) (cadena a.contenido) (cadena a.proyecto) (cadena a.origen) (cadena a.fechas) a.escrito

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
