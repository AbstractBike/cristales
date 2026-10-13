(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* claude-shim: la Messages API servida con Claude Code (Claude_shim). Por
   entorno:

   SHIM_IP            dirección de escucha      (::)
   SHIM_PORT          puerto                    (8317)
   SHIM_CONCURRENCY   procesos claude a la vez  (3)
   SHIM_TIMEOUT_S     tope por llamada          (180)
   SHIM_DIR           donde van los HOME efímeros ($TMPDIR/claude-shim)
   SHIM_TOKEN         sin él, abierto a quien llegue; con él, x-api-key
   CLAUDE_BIN         el CLI                    (claude)
   CLAUDE_CODE_OAUTH_TOKEN: la identidad del CLI (`claude setup-token`). *)

let entorno k d = match Sys.getenv_opt k with Some v when String.trim v <> "" -> String.trim v | _ -> d
let entero k d = Option.value ~default:d (int_of_string_opt (entorno k (string_of_int d)))

(* La petición más grande de los clientes no llega a 64 KiB. *)
let max_cuerpo = 512 * 1024

let rec borrar ruta =
  match (Unix.lstat ruta).st_kind with
  | Unix.S_DIR ->
      Array.iter (fun n -> borrar (Filename.concat ruta n)) (Sys.readdir ruta);
      Unix.rmdir ruta
  | _ -> Sys.remove ruta
  | exception Unix.Unix_error _ -> ()

(* Cada llamada en un directorio suyo, su HOME y su cwd, que se borra al
   acabar: una llamada no le deja nada a la siguiente (ajustes, memoria,
   historial) y no se acumulan en disco prompts con CVs y correos. *)
let con_home dir k =
  let home = Filename.temp_dir ~temp_dir:dir "req-" "" in
  Fun.protect ~finally:(fun () -> borrar home) (fun () -> k home)

let entorno_con_home home =
  Array.append [| "HOME=" ^ home |]
    (Array.of_list
       (List.filter (fun kv -> not (String.starts_with ~prefix:"HOME=" kv)) (Array.to_list (Unix.environment ()))))

let ejecutar ~mgr ~fs ~clock ~bin ~timeout ~dir (p : Claude_shim.peticion) =
  con_home dir @@ fun home ->
  Eio.Switch.run @@ fun sw ->
  let out = Buffer.create 4096 and err = Buffer.create 256 in
  let proc =
    Eio.Process.spawn ~sw mgr
      ~cwd:Eio.Path.(fs / home)
      ~env:(entorno_con_home home)
      (* Por stdin y no en la línea de órdenes: no sale en /proc/<pid>/cmdline. *)
      ~stdin:(Eio.Flow.string_source p.prompt.user)
      ~stdout:(Eio.Flow.buffer_sink out) ~stderr:(Eio.Flow.buffer_sink err)
      (Claude_shim.argumentos ~bin ~alias:p.alias ~system:p.prompt.system)
  in
  match Eio.Time.with_timeout clock timeout (fun () -> Ok (Eio.Process.await proc)) with
  | Error `Timeout ->
      Eio.Process.signal proc Sys.sigkill;
      Error (Printf.sprintf "claude -p timeout tras %.0fs" timeout)
  | Ok (`Exited 0) -> Ok (Buffer.contents out)
  | Ok st ->
      let st = match st with `Exited n -> Printf.sprintf "exit=%d" n | `Signaled n -> Printf.sprintf "señal %d" n in
      Error
        (Printf.sprintf "claude -p %s: %s" st
           (Claude_shim.motivo_fallo ~err:(Buffer.contents err) ~out:(Buffer.contents out)))

let json estado cuerpo =
  Cohttp_eio.Server.respond_string ~status:estado
    ~headers:(Http.Header.of_list [ ("content-type", "application/json") ])
    ~body:cuerpo ()

let error_shim m =
  Yojson.Safe.to_string
    (`Assoc [ ("type", `String "error"); ("error", `Assoc [ ("type", `String "shim_error"); ("message", `String m) ]) ])

let () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let net = Eio.Stdenv.net env and clock = Eio.Stdenv.clock env in
  let mgr = Eio.Stdenv.process_mgr env and fs = Eio.Stdenv.fs env in
  let bin = entorno "CLAUDE_BIN" "claude" in
  let timeout = float_of_int (entero "SHIM_TIMEOUT_S" 180) in
  let dir = entorno "SHIM_DIR" (Filename.concat (Filename.get_temp_dir_name ()) "claude-shim") in
  (try Unix.mkdir dir 0o700 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  let token = Sys.getenv_opt "SHIM_TOKEN" |> Option.map String.trim |> Option.map (function "" -> None | t -> Some t) |> Option.join in
  let concurrencia = entero "SHIM_CONCURRENCY" 3 in
  let turno = Eio.Semaphore.make concurrencia in
  let n = ref 0 in
  let callback _ req cuerpo =
    let ruta = Uri.path (Uri.of_string (Http.Request.resource req)) in
    match (Http.Request.meth req, ruta) with
    | _, "/healthz" -> json `OK {|{"ok":true}|}
    | `POST, "/v1/messages" -> (
        let cabecera = Http.Header.get (Http.Request.headers req) "x-api-key" in
        if not (Claude_shim.autorizado ~cabecera ~token) then
          json `Unauthorized {|{"type":"error","error":{"type":"authentication_error","message":"x-api-key"}}|}
        else
          match Eio.Buf_read.(parse_exn take_all) cuerpo ~max_size:max_cuerpo with
          | exception Failure _ -> json `Request_entity_too_large {|{"error":"body too large"}|}
          | cuerpo -> (
              match Claude_shim.peticion cuerpo with
              | Error m -> json `Bad_request (error_shim m)
              | Ok p ->
                  let t0 = Eio.Time.now clock in
                  let r =
                    Eio.Semaphore.acquire turno;
                    Fun.protect ~finally:(fun () -> Eio.Semaphore.release turno) @@ fun () ->
                    incr n;
                    let id = Printf.sprintf "shim_%d_%d" (int_of_float (t0 *. 1000.)) !n in
                    try Result.bind (ejecutar ~mgr ~fs ~clock ~bin ~timeout ~dir p) (Claude_shim.respuesta p ~id)
                    with e -> Error (Printexc.to_string e)
                  in
                  match r with
                  | Ok resp ->
                      Printf.eprintf "claude-shim: ok en %.0fms (%dB -> %dB)\n%!"
                        ((Eio.Time.now clock -. t0) *. 1000.) (String.length cuerpo) (String.length resp);
                      json `OK resp
                  | Error m ->
                      Printf.eprintf "claude-shim: ERROR %s\n%!" (String.sub m 0 (min 200 (String.length m)));
                      json `Bad_gateway (error_shim m)))
    | _, "/v1/messages" -> json `Method_not_allowed {|{"error":"POST only"}|}
    | _ -> json `Not_found {|{"error":"no existe"}|}
  in
  let ip =
    match Ipaddr.of_string (entorno "SHIM_IP" "::") with
    | Ok ip -> Eio_unix.Net.Ipaddr.of_unix (Ipaddr_unix.to_inet_addr ip)
    | Error (`Msg m) -> failwith m
  in
  let puerto = entero "SHIM_PORT" 8317 in
  Printf.eprintf "claude-shim: escuchando en [%s]:%d (concurrencia=%d, timeout=%.0fs%s)\n%!" (entorno "SHIM_IP" "::")
    puerto concurrencia timeout (if token = None then ", SIN token" else "");
  let socket = Eio.Net.listen net ~sw ~backlog:128 ~reuse_addr:true (`Tcp (ip, puerto)) in
  Cohttp_eio.Server.run socket (Cohttp_eio.Server.make ~callback ())
    ~on_error:(fun e -> Printf.eprintf "claude-shim: %s\n%!" (Printexc.to_string e))
