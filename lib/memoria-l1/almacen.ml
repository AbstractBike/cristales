(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

module G = Forja_http.Greptime

type t = G.t

let ejecutar g consulta =
  match G.sql g consulta with
  | Ok (c, _) when c < 300 -> Ok ()
  | Ok (c, b) -> Error (Printf.sprintf "greptime %d: %s" c b)
  | Error e -> Error ("greptime: " ^ e)

(* Como [G.leer], pero un fallo es un fallo. *)
let leer g consulta =
  match G.sql g consulta with
  | Ok (c, b) when c < 300 -> (
      try Ok (G.crudas (Yojson.Safe.from_string b)) with Yojson.Json_error e -> Error ("greptime: " ^ e))
  | Ok (c, b) -> Error (Printf.sprintf "greptime %d: %s" c (if String.length b > 300 then String.sub b 0 300 else b))
  | Error e -> Error ("greptime: " ^ e)

let ( let* ) = Result.bind

let avisar = function Ok () -> () | Error e -> prerr_endline e

let crear g =
  avisar
    (ejecutar g
       "CREATE TABLE IF NOT EXISTS memoria_l1 (ts TIMESTAMP(3) TIME INDEX, \"id\" STRING PRIMARY KEY, \"version\" INT, \
        vigente BOOLEAN, tipo STRING, prioridad INT, escena STRING, contenido STRING FULLTEXT INDEX WITH (analyzer = \
        'English', case_sensitive = 'false'), proyecto STRING, origen STRING, fechas STRING, escrito TIMESTAMP(3) NULL)");
  (* Las de antes no tenían [escrito]: sus filas quedan con null. *)
  avisar (ejecutar g "ALTER TABLE memoria_l1 ADD COLUMN IF NOT EXISTS escrito TIMESTAMP(3)");
  avisar
    (ejecutar g
       "CREATE TABLE IF NOT EXISTS memoria_cursor (ts TIMESTAMP(3) TIME INDEX, sesion STRING PRIMARY KEY, hasta BIGINT, \
        escena STRING, fallos INT)");
  (* Las de la primera ronda no tenían [fallos]. *)
  avisar (ejecutar g "ALTER TABLE memoria_cursor ADD COLUMN IF NOT EXISTS fallos INT");
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

let valores ~ts ~escrito (a : Atomo.t) =
  Printf.sprintf "(%d, %d, %s, %d, %b, %s, %d, %s, %s, %s, %s, %s)" ts escrito (literal a.id) a.version a.vigente
    (literal (Atomo.tipo_a_texto a.tipo))
    a.prioridad (literal a.escena) (literal a.contenido) (literal a.proyecto)
    (literal (json_lista a.origen))
    (literal (json_lista a.fechas))

let cursor_de_fila = function
  | `List [ `String s; hasta; escena; fallos ] ->
      Option.map
        (fun hasta ->
          ( s,
            { Lote.hasta;
              escena = (match escena with `String e when e <> "" -> Some e | _ -> None);
              fallos = Option.value ~default:0 (entero fallos) } ))
        (entero hasta)
  | _ -> None

(* {1 Lectura} *)

let cursores g =
  let* filas =
    leer g
      "SELECT sesion, last_value(hasta ORDER BY ts), last_value(escena ORDER BY ts), last_value(fallos ORDER BY ts) \
       FROM memoria_cursor GROUP BY sesion"
  in
  Ok (List.filter_map cursor_de_fila filas)

let sesiones g ~cursores ~inactiva_min ~desde =
  let* filas =
    leer g
      (Printf.sprintf
         "SELECT sesion, max(ts) FROM memoria_l0 GROUP BY sesion HAVING max(ts) < now() - INTERVAL '%d minutes' AND \
          max(ts) >= '%s' ORDER BY max(ts)"
         inactiva_min (Atomo.sql_ts desde))
  in
  Ok
    (List.filter_map
       (function
         | `List [ `String s; ts ] -> (
             match ms ts with
             | Some ts when (match List.assoc_opt s cursores with Some (c : Lote.cursor) -> ts > c.hasta | None -> true) ->
                 Some (s, ts)
             | _ -> None)
         | _ -> None)
       filas)

let texto_o_vacio = function `String p -> p | _ -> ""

let mensaje = function
  | `List [ ts; `String sesion; `String uuid; proyecto; `String rol; agente; `String texto ] ->
      Option.map
        (fun ts -> { Atomo.sesion; uuid; ts; proyecto = texto_o_vacio proyecto; rol; agente = texto_o_vacio agente; texto })
        (ms ts)
  | _ -> None

let mensajes g ~sesion ~cursor ~fondo =
  let columnas =
    "SELECT ts, sesion, \"uuid\", proyecto, rol, agente, texto FROM memoria_l0 WHERE sesion = " ^ literal sesion
  in
  let leer_m c = Result.map (List.filter_map mensaje) (leer g c) in
  match cursor with
  | None -> leer_m (columnas ^ " ORDER BY ts, \"uuid\"")
  | Some c ->
      let corte = Printf.sprintf "to_timestamp_millis(%d)" c in
      let* previos = leer_m (Printf.sprintf "%s AND ts <= %s ORDER BY ts DESC LIMIT %d" columnas corte fondo) in
      let* despues = leer_m (Printf.sprintf "%s AND ts > %s ORDER BY ts, \"uuid\"" columnas corte) in
      Ok (previos @ despues)

let rec todos = function [] -> Ok [] | Ok x :: r -> Result.map (List.cons x) (todos r) | Error e :: _ -> Error e

let candidatos g ?(n = 5) ?(por_termino = 20) (nuevo : Atomo.nuevo) =
  let por_termino_filas t =
    Result.map (List.filter_map atomo)
      (leer g
         (Printf.sprintf
            "SELECT %s FROM memoria_l1 WHERE matches(lower(contenido), %s) ORDER BY prioridad DESC, ts DESC LIMIT %d"
            columnas_l1 (literal (Dedup.consulta t)) por_termino))
  in
  let* listas = todos (List.map por_termino_filas (Dedup.terminos nuevo.contenido)) in
  match List.sort_uniq String.compare (List.concat_map (List.map (fun (a : Atomo.t) -> a.id)) listas) with
  | [] -> Ok []
  | ids ->
      let* filas =
        leer g
          (Printf.sprintf "SELECT \"id\", max(\"version\") FROM memoria_l1 WHERE \"id\" IN (%s) GROUP BY \"id\""
             (String.concat ", " (List.map literal ids)))
      in
      let maximas =
        List.filter_map (function `List [ `String id; v ] -> Option.map (fun v -> (id, v)) (entero v) | _ -> None) filas
      in
      Ok (Dedup.mejores ~n (List.map (Dedup.vigentes maximas) listas))

let escrito g ~sesion ~hasta =
  let* filas =
    leer g
      (Printf.sprintf
         "SELECT count(*) FROM memoria_l1 WHERE ts >= to_timestamp_millis(%d) AND ts < to_timestamp_millis(%d) AND \
          origen LIKE %s"
         hasta (hasta + 1000)
         (literal ("%\"" ^ sesion ^ "/%")))
  in
  match filas with [ `List [ n ] ] -> Ok (Option.value ~default:0 (entero n) > 0) | _ -> Ok false

(* {1 Escritura} *)

let escribir g ~escrito ~hasta = function
  | [] -> Ok ()
  | filas ->
      ejecutar g
        (Printf.sprintf "INSERT INTO memoria_l1 (ts, escrito, %s) VALUES %s" columnas_l1
           (String.concat ", " (List.mapi (fun i a -> valores ~ts:(hasta + i) ~escrito a) filas)))

let guardar_cursor g ~ts ~sesion (c : Lote.cursor) =
  ejecutar g
    (Printf.sprintf "INSERT INTO memoria_cursor (ts, sesion, hasta, escena, fallos) VALUES (%d, %s, %d, %s, %d)" ts
       (literal sesion) c.hasta
       (literal (Option.value ~default:"" c.escena))
       c.fallos)
