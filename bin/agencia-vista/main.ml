(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* agencia-vista: la agencia a la vista, por HTTP y de solo lectura
   (doc/agencia.md). Lee el archivo de GreptimeDB que escriben los
   agencia-mcp y sirve /agencia/… (Agencia_vista), de donde tira
   agencia.pin. No llama a ningún modelo ni escribe nada. Por entorno:

   AGENCIA_IP          dirección de escucha   (127.0.0.1)
   AGENCIA_PUERTO      puerto                 (8092)
   AGENCIA_GREPTIME    raíz HTTP de GreptimeDB (obligatoria)
   AGENCIA_GREPTIME_DB base de datos          (agencia) *)

let entorno k d = Option.value ~default:d (Sys.getenv_opt k)

let () =
  Mirage_crypto_rng_unix.use_default ();
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let net = Eio.Stdenv.net env in
  let cliente = Forja_http.Proxy.cliente net in
  let url =
    match Sys.getenv_opt "AGENCIA_GREPTIME" with
    | Some u -> Uri.of_string u
    | None -> failwith "agencia-vista: falta AGENCIA_GREPTIME (el archivo que enseñar)"
  in
  let archivo =
    Agencia_http.Archivo_greptime.crear ~post:(Forja_http.Proxy.post cliente) ~url
      ~db:(entorno "AGENCIA_GREPTIME_DB" "agencia") ()
  in
  let politica = Agencia.Politica.por_defecto in
  let callback _ req _cuerpo =
    let uri = Uri.of_string (Http.Request.resource req) in
    let r =
      try
        match
          Agencia_vista.atender archivo politica ~meth:(Http.Request.meth req) ~ruta:(Uri.path uri)
            ~query:(Uri.query uri)
        with
        | Some r -> r
        | None -> { estado = 404; tipo = "text/plain"; cuerpo = "agencia-vista: solo /agencia/…\n" }
      with e ->
        { Agencia_vista.estado = 502;
          tipo = "application/json";
          cuerpo = Yojson.Safe.to_string (`Assoc [ ("error", `String ("agencia: " ^ Printexc.to_string e)) ]) }
    in
    Cohttp_eio.Server.respond_string
      ~headers:(Http.Header.of_list [ ("content-type", r.tipo) ])
      ~status:(Http.Status.of_int r.estado) ~body:r.cuerpo ()
  in
  let ip =
    match Ipaddr.of_string (entorno "AGENCIA_IP" "127.0.0.1") with
    | Ok ip -> Eio_unix.Net.Ipaddr.of_unix (Ipaddr_unix.to_inet_addr ip)
    | Error (`Msg m) -> failwith m
  in
  let puerto = int_of_string (entorno "AGENCIA_PUERTO" "8092") in
  Printf.eprintf "agencia-vista: escuchando en %s:%d\n%!" (entorno "AGENCIA_IP" "127.0.0.1") puerto;
  let socket = Eio.Net.listen net ~sw ~backlog:128 ~reuse_addr:true (`Tcp (ip, puerto)) in
  Cohttp_eio.Server.run socket (Cohttp_eio.Server.make ~callback ())
    ~on_error:(fun e -> Printf.eprintf "agencia-vista: %s\n%!" (Printexc.to_string e))
