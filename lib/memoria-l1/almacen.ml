(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

module G = Forja_http.Greptime

type t = G.t

let ejecutar g consulta =
  match G.sql g consulta with
  | Ok (c, _) when c < 300 -> Ok ()
  | Ok (c, b) -> Error (Printf.sprintf "greptime %d: %s" c b)
  | Error e -> Error ("greptime: " ^ e)

let avisar = function Ok () -> () | Error e -> prerr_endline e

let crear g =
  avisar
    (ejecutar g
       "CREATE TABLE IF NOT EXISTS memoria_l1 (ts TIMESTAMP(3) TIME INDEX, \"id\" STRING PRIMARY KEY, \"version\" INT, \
        vigente BOOLEAN, tipo STRING, prioridad INT, escena STRING, contenido STRING FULLTEXT INDEX WITH (analyzer = \
        'English', case_sensitive = 'false'), proyecto STRING, origen STRING, fechas STRING)");
  avisar
    (ejecutar g
       "CREATE TABLE IF NOT EXISTS memoria_cursor (ts TIMESTAMP(3) TIME INDEX, sesion STRING PRIMARY KEY, hasta BIGINT, \
        escena STRING)");
  g

(* {1 SQL} *)

let literal s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '\'';
  String.iter (function '\'' -> Buffer.add_string b "''" | c -> Buffer.add_char b c) s;
  Buffer.add_char b '\'';
  Buffer.contents b

let ms = function
  | `Int n when n > 100_000_000_000_000_000 -> Some (n / 1_000_000)
  | `Int n when n > 100_000_000_000_000 -> Some (n / 1_000)
  | `Int n -> Some n
  | `Intlit s -> Option.map (fun n -> n / 1_000_000) (int_of_string_opt s)
  | `Float f -> Some (int_of_float f)
  | _ -> None

let columnas_l1 = "\"id\", \"version\", vigente, tipo, prioridad, escena, contenido, proyecto, origen, fechas"

let lista_json s =
  match Yojson.Safe.from_string s with
  | `List l -> List.filter_map (function `String s -> Some s | _ -> None) l
  | _ -> []
  | exception Yojson.Json_error _ -> []

let json_lista l = Yojson.Safe.to_string (`List (List.map (fun s -> `String s) l))

let texto = function `String s -> s | `Null -> "" | j -> Yojson.Safe.to_string j
let entero = function `Int n -> Some n | `Float f -> Some (int_of_float f) | _ -> None

let atomo = function
  | `List [ `String id; version; vigente; `String tipo; prioridad; escena; `String contenido; proyecto; origen; fechas ] -> (
      match (entero version, Atomo.tipo_de_texto tipo, entero prioridad) with
      | Some version, Some tipo, Some prioridad ->
          Some
            { Atomo.id;
              version;
              vigente = (match vigente with `Bool b -> b | _ -> false);
              tipo;
              prioridad;
              escena = texto escena;
              contenido;
              proyecto = texto proyecto;
              origen = lista_json (texto origen);
              fechas = lista_json (texto fechas) }
      | _ -> None)
  | _ -> None

let valores ~ts (a : Atomo.t) =
  Printf.sprintf "(%d, %s, %d, %b, %s, %d, %s, %s, %s, %s, %s)" ts (literal a.id) a.version a.vigente
    (literal (Atomo.tipo_a_texto a.tipo))
    a.prioridad (literal a.escena) (literal a.contenido) (literal a.proyecto)
    (literal (json_lista a.origen))
    (literal (json_lista a.fechas))

(* {1 Lectura} *)

let cursores g =
  G.leer g "SELECT sesion, hasta, escena FROM memoria_cursor ORDER BY ts DESC"
  |> List.fold_left
       (fun acc fila ->
         match fila with
         | `List [ `String s; hasta; escena ] when not (List.mem_assoc s acc) -> (
             match entero hasta with
             | Some h -> (s, (h, match escena with `String e when e <> "" -> Some e | _ -> None)) :: acc
             | None -> acc)
         | _ -> acc)
       []

let cursor g sesion = List.assoc_opt sesion (cursores g)

let sesiones g ~inactiva_min =
  let cs = cursores g in
  G.leer g
    (Printf.sprintf
       "SELECT sesion, max(ts) FROM memoria_l0 GROUP BY sesion HAVING max(ts) < now() - INTERVAL '%d minutes' ORDER BY \
        max(ts)"
       inactiva_min)
  |> List.filter_map (function
       | `List [ `String s; ts ] -> (
           match ms ts with
           | Some ts when (match List.assoc_opt s cs with Some (h, _) -> ts > h | None -> true) -> Some (s, ts)
           | _ -> None)
       | _ -> None)

let mensaje = function
  | `List [ ts; `String sesion; `String uuid; proyecto; `String rol; `String texto ] ->
      Option.map (fun ts -> { Atomo.sesion; uuid; ts; proyecto = (match proyecto with `String p -> p | _ -> ""); rol; texto }) (ms ts)
  | _ -> None

let mensajes g ~sesion ~cursor ~fondo =
  let columnas = "SELECT ts, sesion, uuid, proyecto, rol, texto FROM memoria_l0 WHERE sesion = " ^ literal sesion in
  let leer c = List.filter_map mensaje (G.leer g c) in
  match cursor with
  | None -> leer (columnas ^ " ORDER BY ts, uuid")
  | Some c ->
      (* El ts de L0 puede no ser de milisegundos: se compara con la función
         de GreptimeDB, que entiende ms. *)
      let corte = Printf.sprintf "to_timestamp_millis(%d)" c in
      leer (Printf.sprintf "%s AND ts <= %s ORDER BY ts DESC LIMIT %d" columnas corte fondo)
      @ leer (Printf.sprintf "%s AND ts > %s ORDER BY ts, uuid" columnas corte)

let candidatos g ?(n = 5) ?(por_termino = 20) (nuevo : Atomo.nuevo) =
  let por_termino_filas t =
    List.filter_map atomo
      (G.leer g
         (Printf.sprintf "SELECT %s FROM memoria_l1 WHERE matches(contenido, %s) ORDER BY prioridad DESC, ts DESC LIMIT %d"
            columnas_l1 (literal (Dedup.consulta t)) por_termino))
  in
  let listas = List.map por_termino_filas (Dedup.terminos nuevo.contenido) in
  match List.sort_uniq String.compare (List.concat_map (List.map (fun (a : Atomo.t) -> a.id)) listas) with
  | [] -> []
  | ids ->
      let maximas =
        G.leer g
          (Printf.sprintf "SELECT \"id\", max(\"version\") FROM memoria_l1 WHERE \"id\" IN (%s) GROUP BY \"id\""
             (String.concat ", " (List.map literal ids)))
        |> List.filter_map (function `List [ `String id; v ] -> Option.map (fun v -> (id, v)) (entero v) | _ -> None)
      in
      Dedup.mejores ~n (List.map (Dedup.vigentes maximas) listas)

(* {1 Escritura} *)

let escribir g ~ts = function
  | [] -> Ok ()
  | filas ->
      ejecutar g
        (Printf.sprintf "INSERT INTO memoria_l1 (ts, %s) VALUES %s" columnas_l1
           (String.concat ", " (List.mapi (fun i a -> valores ~ts:(ts + i) a) filas)))

let guardar_cursor g ~ts ~sesion ~hasta ~escena =
  ejecutar g
    (Printf.sprintf "INSERT INTO memoria_cursor (ts, sesion, hasta, escena) VALUES (%d, %s, %d, %s)" ts (literal sesion)
       hasta
       (literal (Option.value ~default:"" escena)))
