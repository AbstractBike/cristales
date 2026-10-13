(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* memoria-mcp: el recall de la memoria como servidor MCP por stdio
   (doc/memoria.md). Una línea JSON-RPC por mensaje; stderr es el log.

   MEMORIA_REPO         checkout del repo memoria (/logical-node/repositories/logical-license/memoria)
   MEMORIA_GREPTIME     raíz HTTP de GreptimeDB (https://greptime.pin)
   MEMORIA_GREPTIME_DB  base (memoria)
   MEMORIA_TABLA_L0     (memoria_l0)
   MEMORIA_TABLA_L1     (memoria_l1)  las dos, para probar contra otras tablas *)

let entorno k d = match Sys.getenv_opt k with Some v when String.trim v <> "" -> String.trim v | _ -> d

(* Un nombre de tabla va tal cual en el SQL: solo [a-z0-9_]. *)
let tabla k d =
  let t = entorno k d in
  if t <> "" && String.for_all (function 'a' .. 'z' | '0' .. '9' | '_' -> true | _ -> false) t then t
  else failwith (k ^ ": nombre de tabla inválido")

let () =
  Mirage_crypto_rng_unix.use_default ();
  let tablas = { Memoria_recall.Consulta.l0 = tabla "MEMORIA_TABLA_L0" "memoria_l0"; l1 = tabla "MEMORIA_TABLA_L1" "memoria_l1" } in
  Eio_main.run @@ fun env ->
  let cliente = Forja_http.Proxy.cliente (Eio.Stdenv.net env) in
  let post = Forja_http.Proxy.post cliente in
  let url = Uri.of_string (entorno "MEMORIA_GREPTIME" "https://greptime.pin")
  and db = entorno "MEMORIA_GREPTIME_DB" "memoria" in
  (* Sin [Greptime.conectar]: no crea la base al arrancar (eso es de la
     ingesta) y así el arranque no espera a la red. *)
  let sql consulta =
    match
      post
        (Uri.with_query' (Uri.with_path url "/v1/sql") [ ("db", db) ])
        ~tipo:"application/x-www-form-urlencoded"
        (Uri.encoded_of_query [ ("sql", [ consulta ]) ])
    with
    | exception e -> Error (Printexc.to_string e)
    | Error e -> Error e
    | Ok (c, b) when c < 300 -> (
        try Ok (Forja_http.Greptime.crudas (Yojson.Safe.from_string b)) with Yojson.Json_error e -> Error e)
    | Ok (c, b) -> Error (Printf.sprintf "%d: %s" c b)
  in
  let efectos =
    { Memoria_recall.Servidor.sql; repo = entorno "MEMORIA_REPO" "/logical-node/repositories/logical-license/memoria"; tablas }
  in
  let servidor = Memoria_recall.Servidor.servidor efectos in
  let entrada = Eio.Buf_read.of_flow ~max_size:(16 * 1024 * 1024) (Eio.Stdenv.stdin env) in
  let salida = Eio.Stdenv.stdout env in
  let rec bucle () =
    match Eio.Buf_read.line entrada with
    | l ->
        Option.iter (fun r -> Eio.Flow.copy_string (r ^ "\n") salida) (Mcp_rpc.linea servidor l);
        bucle ()
    | exception End_of_file -> ()
  in
  bucle ()
