(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Conformidad de un servidor forja-mcp con mcp/CONTRATO.md.

     conformidad -- <orden> [argumentos…]

   Levanta una forja falsa por HTTP en un puerto libre, lanza la orden con
   FORJA_URL apuntando a ella y le habla JSON-RPC por stdio. Después la lanza
   otra vez con FORJA_URL apuntando a un puerto cerrado. Sale con 0 si todo
   cumple. *)

let fallos = ref 0
let comprobadas = ref 0

let comprueba nombre cond detalle =
  incr comprobadas;
  if not cond then (
    incr fallos;
    Printf.printf "FALLA %s\n      %s\n%!" nombre (Lazy.force detalle))
  else Printf.printf "  ok  %s\n%!" nombre

(* {1 La forja falsa} *)

let vitrina =
  {|[{"tarea":"fecha-es","estado":"mixta","descripcion":"Fechas en español a ISO 8601."},{"tarea":"mayus","estado":"cristalina","descripcion":"Pone el texto en mayúsculas."}]|}

let tareas =
  {|[{"tarea":"mayus","fase":"cristalina","muestras":23,"contrastes":2,"coincidencias":2,"madura":true},{"tarea":"t-712d41d0978b","fase":"liquida","muestras":3,"contrastes":0,"coincidencias":0,"madura":false}]|}

let tarea n =
  Printf.sprintf
    {|{"tarea":"mayus","fase":"cristalina","muestras":23,"contrastes":2,"coincidencias":2,"madura":true,"plantilla":"Pon en mayúsculas.","ultimas":%s,"pedidas":%d}|}
    (if n = 0 then "[]" else {|[{"entrada":"hola","salida":"HOLA","contraste":null,"defecto":null}]|})
    n

let semilla = "# Semilla: mayus\n\nPon en mayúsculas.\n"
let nucleacion = "No quiero que resuelvas estos casos. Quiero el **programa**…\n"
let leer b = Eio.Buf_read.(parse_exn take_all) b ~max_size:max_int

let responder ?(tipo = "application/json") estado cuerpo =
  Cohttp_eio.Server.respond_string ~status:estado
    ~headers:(Http.Header.of_list [ ("content-type", tipo) ])
    ~body:cuerpo ()

let forja _ req cuerpo =
  let uri = Uri.of_string (Http.Request.resource req) in
  let cuerpo = leer cuerpo in
  match (Http.Request.meth req, Uri.path uri) with
  | `GET, "/forja/vitrina" -> responder `OK vitrina
  | `GET, "/forja/tareas" -> responder `OK tareas
  | `GET, "/forja/tareas/mayus" ->
      let n = Option.bind (Uri.get_query_param uri "muestras") int_of_string_opt in
      responder `OK (tarea (Option.value ~default:(-1) n))
  | `GET, "/forja/tareas/mayus/semilla" -> responder ~tipo:"text/markdown" `OK semilla
  | `GET, "/forja/tareas/mayus/nucleacion" -> responder ~tipo:"text/markdown" `OK nucleacion
  | `GET, "/forja/tareas/rota/semilla" -> responder `Internal_server_error {|{"error":"rota"}|}
  | `POST, "/forja/vitrina/mayus" -> (
      match Yojson.Safe.(Util.member "entrada" (from_string cuerpo)) with
      | `String e when String.exists (function '0' .. '9' -> true | _ -> false) e ->
          responder `OK {|{"defecto":"dígitos"}|}
      | `String e -> responder `OK (Yojson.Safe.to_string (`Assoc [ ("salida", `String (String.uppercase_ascii e)) ]))
      | _ -> responder `Bad_request {|{"error":"falta entrada"}|}
      | exception _ -> responder `Bad_request {|{"error":"no es JSON"}|})
  | `POST, "/forja/vitrina/fecha-es" -> responder `OK {|{"salida":"2024-03-03"}|}
  | _ -> responder `Not_found {|{"error":"no existe"}|}

(* {1 El cliente} *)

type servidor = { enviar : string -> unit; recibir : unit -> Yojson.Safe.t option }

let con_servidor env ~sw ~url orden f =
  let mgr = Eio.Stdenv.process_mgr env in
  let r_in, w_in = Eio_unix.pipe sw in
  let r_out, w_out = Eio_unix.pipe sw in
  let entorno =
    Array.append
      (Array.of_list
         (List.filter
            (fun v -> not (String.length v >= 10 && String.sub v 0 10 = "FORJA_URL="))
            (Array.to_list (Unix.environment ()))))
      [| "FORJA_URL=" ^ url |]
  in
  let ejecutable =
    let p = List.hd orden in
    if String.contains p '/' then p
    else
      match
        List.find_opt
          (fun d -> Sys.file_exists (Filename.concat d p))
          (String.split_on_char ':' (Option.value ~default:"" (Sys.getenv_opt "PATH")))
      with
      | Some d -> Filename.concat d p
      | None -> failwith ("conformidad: no encuentro " ^ p)
  in
  let proc =
    Eio.Process.spawn mgr ~sw ~stdin:r_in ~stdout:w_out ~env:entorno ~executable:ejecutable orden
  in
  Eio.Flow.close r_in;
  Eio.Flow.close w_out;
  let lector = Eio.Buf_read.of_flow ~max_size:(64 * 1024 * 1024) r_out in
  let reloj = Eio.Stdenv.clock env in
  let s =
    { enviar = (fun l -> try Eio.Flow.copy_string (l ^ "\n") w_in with _ -> ());
      recibir =
        (fun () ->
          match Eio.Time.with_timeout_exn reloj 15.0 (fun () -> Eio.Buf_read.line lector) with
          | l -> ( try Some (Yojson.Safe.from_string l) with _ -> Some (`String ("NO JSON: " ^ l)))
          | exception (Eio.Time.Timeout | End_of_file) -> None) }
  in
  Fun.protect
    ~finally:(fun () ->
      (try Eio.Flow.close w_in with _ -> ());
      (try Eio.Process.signal proc Sys.sigterm with _ -> ());
      ignore (Eio.Process.await proc))
    (fun () -> f s)

let id = ref 0

let pedir s ?(params = `Assoc []) metodo =
  incr id;
  s.enviar
    (Yojson.Safe.to_string
       (`Assoc [ ("jsonrpc", `String "2.0"); ("id", `Int !id); ("method", `String metodo); ("params", params) ]));
  (!id, s.recibir ())

open Yojson.Safe.Util

let ver = function Some j -> Yojson.Safe.to_string j | None -> "(sin respuesta)"
let resultado = function Some j -> ( match member "result" j with `Null -> None | r -> Some r) | None -> None
let codigo r = match r with Some j -> ( try Some (j |> member "error" |> member "code" |> to_int) with _ -> None) | None -> None
let id_de = function Some j -> member "id" j | None -> `Null

let contenido r =
  match resultado r with
  | Some res -> (
      try
        let c = res |> member "content" |> to_list in
        let t = List.map (fun b -> (to_string (member "type" b), to_string (member "text" b))) c in
        match t with [ ("text", s) ] -> Some (s, to_bool (member "isError" res)) | _ -> None
      with _ -> None)
  | None -> None

let llamar s nombre args =
  pedir s "tools/call" ~params:(`Assoc [ ("name", `String nombre); ("arguments", `Assoc args) ])

let json_igual a b = try Yojson.Safe.(equal (from_string a) (from_string b)) with _ -> false

let empieza p s = String.length s >= String.length p && String.sub s 0 (String.length p) = p

let fijas = [ "forja_tareas"; "forja_tarea"; "forja_semilla"; "forja_nucleacion" ]

let con_forja s =
  print_endline "\n# Ciclo de vida";
  let i, r = pedir s "initialize" ~params:(`Assoc [ ("protocolVersion", `String "2025-06-18"); ("capabilities", `Assoc []); ("clientInfo", `Assoc [ ("name", `String "conformidad"); ("version", `String "1") ]) ]) in
  comprueba "initialize: id de la petición" (id_de r = `Int i) (lazy (ver r));
  (match resultado r with
  | Some res ->
      comprueba "initialize: devuelve la versión pedida" (member "protocolVersion" res = `String "2025-06-18") (lazy (ver r));
      comprueba "initialize: capabilities.tools" (match res |> member "capabilities" |> member "tools" with `Assoc _ -> true | _ -> false) (lazy (ver r));
      comprueba "initialize: serverInfo forja-mcp 0.2.0"
        (res |> member "serverInfo" |> member "name" = `String "forja-mcp" && res |> member "serverInfo" |> member "version" = `String "0.2.0")
        (lazy (ver r))
  | None -> comprueba "initialize: resultado" false (lazy (ver r)));
  let _, r = pedir s "initialize" ~params:(`Assoc [ ("protocolVersion", `String "1999-01-01") ]) in
  comprueba "initialize: versión desconocida → 2025-11-25"
    (Option.map (member "protocolVersion") (resultado r) = Some (`String "2025-11-25")) (lazy (ver r));
  s.enviar {|{"jsonrpc":"2.0","method":"notifications/initialized"}|};
  let i, r = pedir s "ping" in
  comprueba "una notificación no tiene respuesta (la siguiente es la del ping)" (id_de r = `Int i) (lazy (ver r));
  comprueba "ping → {}" (resultado r = Some (`Assoc [])) (lazy (ver r));
  s.enviar {|{"jsonrpc":"2.0","id":"abc","method":"ping"}|};
  let r = s.recibir () in
  comprueba "id de cadena se devuelve tal cual" (id_de r = `String "abc") (lazy (ver r));

  print_endline "\n# Errores JSON-RPC";
  s.enviar "esto no es json";
  let r = s.recibir () in
  comprueba "línea que no es JSON → -32700, id null" (codigo r = Some (-32700) && id_de r = `Null) (lazy (ver r));
  s.enviar {|{"jsonrpc":"2.0","id":77}|};
  let r = s.recibir () in
  comprueba "sin method → -32600" (codigo r = Some (-32600)) (lazy (ver r));
  let _, r = pedir s "no/existe" in
  comprueba "método desconocido → -32601" (codigo r = Some (-32601)) (lazy (ver r));

  print_endline "\n# tools/list";
  let _, r = pedir s "tools/list" in
  let tools = try Option.map (fun res -> res |> member "tools" |> to_list) (resultado r) with _ -> None in
  (match tools with
  | Some ts ->
      let nombres = List.map (fun t -> to_string (member "name" t)) ts in
      comprueba "las cuatro fijas y luego los cristales, en orden"
        (nombres = fijas @ [ "fecha-es"; "mayus" ]) (lazy (String.concat ", " nombres));
      comprueba "cada herramienta tiene description e inputSchema de tipo object"
        (List.for_all
           (fun t ->
             (match member "description" t with `String d -> d <> "" | _ -> false)
             && t |> member "inputSchema" |> member "type" = `String "object")
           ts)
        (lazy (ver r));
      let t n = List.find (fun t -> member "name" t = `String n) ts in
      let requeridos n = try t n |> member "inputSchema" |> member "required" |> to_list |> List.map to_string with _ -> [] in
      comprueba "forja_tareas sin obligatorios" (requeridos "forja_tareas" = []) (lazy (ver r));
      comprueba "forja_tarea: tarea obligatoria, muestras entero opcional"
        (requeridos "forja_tarea" = [ "tarea" ]
        && t "forja_tarea" |> member "inputSchema" |> member "properties" |> member "muestras" |> member "type" = `String "integer")
        (lazy (ver r));
      comprueba "cristal: entrada obligatoria y la descripción de la vitrina"
        (requeridos "mayus" = [ "entrada" ] && member "description" (t "mayus") = `String "Pone el texto en mayúsculas.")
        (lazy (ver r))
  | None -> comprueba "tools/list: resultado con tools" false (lazy (ver r)));

  print_endline "\n# Herramientas fijas";
  let r = snd (llamar s "forja_tareas" []) in
  comprueba "forja_tareas → el cuerpo tal cual"
    (match contenido r with Some (t, false) -> json_igual t tareas | _ -> false) (lazy (ver r));
  let r = snd (llamar s "forja_tarea" [ ("tarea", `String "mayus"); ("muestras", `Int 2) ]) in
  comprueba "forja_tarea con muestras=2"
    (match contenido r with Some (t, false) -> json_igual t (tarea 2) | _ -> false) (lazy (ver r));
  let r = snd (llamar s "forja_tarea" [ ("tarea", `String "mayus") ]) in
  comprueba "forja_tarea: muestras=5 por defecto"
    (match contenido r with Some (t, false) -> json_igual t (tarea 5) | _ -> false) (lazy (ver r));
  let r = snd (llamar s "forja_semilla" [ ("tarea", `String "mayus") ]) in
  comprueba "forja_semilla → el markdown tal cual" (contenido r = Some (semilla, false)) (lazy (ver r));
  let r = snd (llamar s "forja_nucleacion" [ ("tarea", `String "mayus") ]) in
  comprueba "forja_nucleacion → el markdown tal cual" (contenido r = Some (nucleacion, false)) (lazy (ver r));
  let r = snd (llamar s "forja_semilla" [ ("tarea", `String "nada") ]) in
  comprueba "404 de la forja → isError, «forja: …»"
    (match contenido r with Some (t, true) -> empieza "forja: " t | _ -> false) (lazy (ver r));
  let r = snd (llamar s "forja_semilla" [ ("tarea", `String "rota") ]) in
  comprueba "500 de la forja → isError, «forja: …»"
    (match contenido r with Some (t, true) -> empieza "forja: " t | _ -> false) (lazy (ver r));
  List.iter
    (fun (nombre, args, que) ->
      let r = snd (llamar s nombre args) in
      comprueba (que ^ " → -32602") (codigo r = Some (-32602)) (lazy (ver r)))
    [ ("forja_semilla", [ ("tarea", `String "../vitrina") ], "tarea con ../");
      ("forja_semilla", [ ("tarea", `String "Mayus") ], "tarea con mayúsculas");
      ("forja_semilla", [ ("tarea", `String (String.make 65 'a')) ], "tarea de 65 caracteres");
      ("forja_tarea", [], "forja_tarea sin tarea");
      ("forja_tarea", [ ("tarea", `Int 3) ], "tarea que no es string");
      ("forja_tarea", [ ("tarea", `String "mayus"); ("muestras", `String "dos") ], "muestras que no es entero");
      ("forja_tarea", [ ("tarea", `String "mayus"); ("muestras", `Int (-1)) ], "muestras negativo");
      ("forja_tarea", [ ("tarea", `String "mayus"); ("muestras", `Int 1001) ], "muestras > 1000") ];

  print_endline "\n# Cristales";
  let r = snd (llamar s "mayus" [ ("entrada", `String "hola, ñandú") ]) in
  comprueba "salida del cristal" (contenido r = Some ("HOLA, ñandú", false)) (lazy (ver r));
  let r = snd (llamar s "mayus" [ ("entrada", `String "a1") ]) in
  comprueba "defecto → isError, «defecto: …»" (contenido r = Some ("defecto: dígitos", true)) (lazy (ver r));
  let r = snd (llamar s "fecha-es" [ ("entrada", `String "3 de marzo de 2024") ]) in
  comprueba "otro cristal" (contenido r = Some ("2024-03-03", false)) (lazy (ver r));
  List.iter
    (fun (nombre, args, que) ->
      let r = snd (llamar s nombre args) in
      comprueba (que ^ " → -32602") (codigo r = Some (-32602)) (lazy (ver r)))
    [ ("noexiste", [ ("entrada", `String "x") ], "cristal que no está en la vitrina (404)");
      ("mayus", [], "cristal sin entrada");
      ("mayus", [ ("entrada", `Int 1) ], "entrada que no es string");
      ("Rara/../x", [ ("entrada", `String "x") ], "nombre que no es de tarea") ]

let sin_forja s =
  print_endline "\n# Sin forja (FORJA_URL a un puerto cerrado)";
  let _, r = pedir s "tools/list" in
  let nombres = try Option.map (fun res -> res |> member "tools" |> to_list |> List.map (fun t -> to_string (member "name" t))) (resultado r) with _ -> None in
  comprueba "tools/list da solo las fijas" (nombres = Some fijas) (lazy (ver r));
  let r = snd (llamar s "forja_tareas" []) in
  comprueba "forja_tareas → isError, «forja: …»"
    (match contenido r with Some (t, true) -> empieza "forja: " t | _ -> false) (lazy (ver r));
  let r = snd (llamar s "mayus" [ ("entrada", `String "x") ]) in
  comprueba "un cristal → isError, «forja: …»"
    (match contenido r with Some (t, true) -> empieza "forja: " t | _ -> false) (lazy (ver r))

let () =
  let orden =
    match Array.to_list Sys.argv with
    | _ :: "--" :: (_ :: _ as o) -> o
    | _ :: (_ :: _ as o) -> o
    | _ -> prerr_endline "uso: conformidad -- <orden> [argumentos…]"; exit 2
  in
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let net = Eio.Stdenv.net env in
  let socket = Eio.Net.listen net ~sw ~backlog:16 ~reuse_addr:true (`Tcp (Eio.Net.Ipaddr.V4.loopback, 0)) in
  let puerto = match Eio.Net.listening_addr socket with `Tcp (_, p) -> p | _ -> assert false in
  Eio.Fiber.fork_daemon ~sw (fun () ->
      Cohttp_eio.Server.run socket (Cohttp_eio.Server.make ~callback:forja ()) ~on_error:(fun e ->
          Printf.eprintf "conformidad: forja falsa: %s\n%!" (Printexc.to_string e)));
  Printf.printf "Servidor: %s\nForja falsa: http://127.0.0.1:%d\n" (String.concat " " orden) puerto;
  con_servidor env ~sw ~url:(Printf.sprintf "http://127.0.0.1:%d" puerto) orden con_forja;
  (* Un puerto que se abre y se cierra: nadie escucha en él. *)
  let cerrado =
    Eio.Switch.run (fun sw ->
        let s = Eio.Net.listen net ~sw ~backlog:1 (`Tcp (Eio.Net.Ipaddr.V4.loopback, 0)) in
        match Eio.Net.listening_addr s with `Tcp (_, p) -> p | _ -> assert false)
  in
  con_servidor env ~sw ~url:(Printf.sprintf "http://127.0.0.1:%d" cerrado) orden sin_forja;
  Printf.printf "\n%d/%d comprobaciones%s\n" (!comprobadas - !fallos) !comprobadas
    (if !fallos = 0 then ": conforme." else Printf.sprintf ", %d fallos." !fallos);
  exit (if !fallos = 0 then 0 else 1)
