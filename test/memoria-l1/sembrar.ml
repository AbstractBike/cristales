(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* sembrar: para la prueba real de memoria-destila mientras la ingesta (A)
   no llena memoria_l0. Lee unos transcripts de Claude Code y escribe sus
   mensajes en memoria_l0 de una base DE PRUEBA, con un lector y una
   redacción mínimos (la buena es la de lib/memoria-l0). Se niega a
   escribir en la base memoria.

   MEMORIA_GREPTIME=http://… MEMORIA_GREPTIME_DB=memoria_prueba_b sembrar a.jsonl b.jsonl *)

(* "2026-08-26T08:34:44.004Z" en ms. *)
let ms_de_iso s =
  try
    Scanf.sscanf s "%4d-%2d-%2dT%2d:%2d:%2d.%3d" (fun y m d h mi se ms ->
        let y = if m <= 2 then y - 1 else y in
        let era = (if y >= 0 then y else y - 399) / 400 in
        let yoe = y - (era * 400) in
        let mp = if m > 2 then m - 3 else m + 9 in
        let doy = (((153 * mp) + 2) / 5) + d - 1 in
        let doe = (yoe * 365) + (yoe / 4) - (yoe / 100) + doy in
        let dias = (era * 146097) + doe - 719468 in
        Some ((((((((dias * 24) + h) * 60) + mi) * 60) + se) * 1000) + ms))
  with _ -> None

(* Sin los bloques <system-reminder>…</system-reminder> y similares. *)
let sin_etiquetas s =
  let b = Buffer.create (String.length s) in
  let n = String.length s in
  let rec ir i dentro =
    if i >= n then ()
    else if s.[i] = '<' && i + 1 < n && match s.[i + 1] with 'a' .. 'z' | '/' -> true | _ -> false then (
      let j = try String.index_from s i '>' with Not_found -> n - 1 in
      let cierra = s.[i + 1] = '/' in
      ir (j + 1) (if cierra then dentro - 1 else dentro + 1))
    else (
      if dentro <= 0 then Buffer.add_char b s.[i];
      ir (i + 1) dentro)
  in
  ir 0 0;
  String.trim (Buffer.contents b)

let sospechosa p =
  let n = String.length p in
  let alnum = String.for_all (function 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '-' | '+' | '=' -> true | _ -> false) p in
  let cifras = String.exists (function '0' .. '9' -> true | _ -> false) p in
  let letras = String.exists (function 'A' .. 'Z' | 'a' .. 'z' -> true | _ -> false) p in
  List.exists (fun pre -> String.starts_with ~prefix:pre p) [ "sk-"; "ghp_"; "gho_"; "eyJ"; "xox" ]
  || (n >= 32 && alnum && cifras && letras)

let contiene s k =
  let n = String.length s and m = String.length k in
  let rec en j = j + m <= n && (String.sub s j m = k || en (j + 1)) in
  en 0

let redactar s =
  String.split_on_char '\n' s
  |> List.map (fun l ->
         String.split_on_char ' ' l
         |> List.map (fun p ->
                match String.index_opt p '=' with
                | Some i when List.exists (contiene (String.uppercase_ascii (String.sub p 0 i))) [ "TOKEN"; "KEY"; "PASSWORD"; "SECRET" ] ->
                    String.sub p 0 (i + 1) ^ "[redactado]"
                | _ -> if sospechosa p then "[redactado]" else p)
         |> String.concat " ")
  |> String.concat "\n"

let texto_de j =
  let open Yojson.Safe.Util in
  let rol = j |> member "type" |> to_string in
  match j |> member "message" |> member "content" with
  | `String s when rol = "user" -> sin_etiquetas s
  | `List bloques ->
      List.filter_map
        (fun b ->
          match b |> member "type" with
          | `String "text" -> Some (sin_etiquetas (b |> member "text" |> to_string))
          | `String "tool_use" ->
              let nombre = match b |> member "name" with `String n -> n | _ -> "?" in
              let desc = match b |> member "input" |> member "description" with `String d -> ": " ^ d | _ -> "" in
              Some (Printf.sprintf "[herramienta %s%s]" nombre desc)
          | _ -> None)
        bloques
      |> List.filter (( <> ) "")
      |> String.concat "\n"
  | _ -> ""

let fila j =
  let open Yojson.Safe.Util in
  match (j |> member "type", j |> member "uuid", j |> member "sessionId", j |> member "timestamp") with
  | `String (("user" | "assistant") as rol), `String uuid, `String sesion, `String ts -> (
      match (ms_de_iso ts, redactar (texto_de j)) with
      | Some ts, texto when texto <> "" ->
          let cwd = match j |> member "cwd" with `String c -> c | _ -> "" in
          Some (ts, sesion, uuid, cwd, rol, texto)
      | _ -> None)
  | _ -> None
  | exception _ -> None

let () =
  Mirage_crypto_rng_unix.use_default ();
  let db = Option.value ~default:"" (Sys.getenv_opt "MEMORIA_GREPTIME_DB") in
  if db = "" || db = "memoria" then (
    prerr_endline "sembrar: solo en una base de prueba (MEMORIA_GREPTIME_DB)";
    exit 2);
  let url = Uri.of_string (Option.value ~default:"" (Sys.getenv_opt "MEMORIA_GREPTIME")) in
  Eio_main.run @@ fun env ->
  let post = Forja_http.Proxy.post (Forja_http.Proxy.cliente (Eio.Stdenv.net env)) in
  let g = Forja_http.Greptime.conectar ~post ~url ~db in
  let sql s =
    match Forja_http.Greptime.sql g s with
    | Ok (c, _) when c < 300 -> ()
    | Ok (c, b) -> Printf.eprintf "greptime %d: %s\n%!" c (String.sub b 0 (min 300 (String.length b)))
    | Error e -> prerr_endline e
  in
  sql
    "CREATE TABLE IF NOT EXISTS memoria_l0 (ts TIMESTAMP(3) TIME INDEX, sesion STRING PRIMARY KEY, \"uuid\" STRING, proyecto \
     STRING, nodo STRING, rol STRING, texto STRING FULLTEXT INDEX)";
  let nodo = Unix.gethostname () in
  let lit = Memoria_l1.Almacen.literal in
  List.iter
    (fun f ->
      let filas =
        In_channel.with_open_text f In_channel.input_all
        |> String.split_on_char '\n'
        |> List.filter_map (fun l -> try fila (Yojson.Safe.from_string l) with Yojson.Json_error _ -> None)
      in
      let rec trozos = function
        | [] -> ()
        | l ->
            let a = List.filteri (fun i _ -> i < 200) l and r = List.filteri (fun i _ -> i >= 200) l in
            sql
              (Printf.sprintf "INSERT INTO memoria_l0 (ts, sesion, \"uuid\", proyecto, nodo, rol, texto) VALUES %s"
                 (String.concat ", "
                    (List.map
                       (fun (ts, s, u, p, rol, t) ->
                         Printf.sprintf "(%d, %s, %s, %s, %s, %s, %s)" ts (lit s) (lit u) (lit p) (lit nodo) (lit rol) (lit t))
                       a)));
            trozos r
      in
      trozos filas;
      Printf.printf "%s: %d mensajes\n%!" (Filename.basename f) (List.length filas))
    (List.tl (Array.to_list Sys.argv))
