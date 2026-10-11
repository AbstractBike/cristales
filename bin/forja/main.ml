(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

(* forja: proxy de LLM que cristaliza las tareas que atiende. Ver
   doc/forja.md. Se configura por entorno (lo fija el módulo NixOS):

   FORJA_IP           dirección de escucha        (127.0.0.1)
   FORJA_PUERTO       puerto                      (8090)
   FORJA_UPSTREAM     API real                    (https://api.anthropic.com)
   FORJA_HORNO        dónde dejar tareas maduras  (./horno)
   FORJA_GREPTIME     raíz HTTP de GreptimeDB     (sin ella, cantera en memoria)
   FORJA_GREPTIME_DB  base de datos               (public) *)

let entorno k d = Option.value ~default:d (Sys.getenv_opt k)

let () =
  Mirage_crypto_rng_unix.use_default ();
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let net = Eio.Stdenv.net env in
  let cliente = Forja_http.Proxy.cliente net in
  let cantera =
    match Sys.getenv_opt "FORJA_GREPTIME" with
    | Some url ->
        Forja_http.Cantera_greptime.crear ~post:(Forja_http.Proxy.post cliente)
          ~url:(Uri.of_string url) ~db:(entorno "FORJA_GREPTIME_DB" "public") ()
    | None ->
        prerr_endline "forja: sin FORJA_GREPTIME, la cantera vive en memoria";
        Forja.Cantera.en_memoria ()
  in
  let forja = Forja.crear ~vitrina:Vitrina.vitrina ~cantera () in
  let horno = Eio.Path.(Eio.Stdenv.fs env / entorno "FORJA_HORNO" "horno") in
  let madura tarea informe =
    try
      let d =
        Forja_http.Horno.cocer ~dir:horno ~prompt:Forja_http.Prompt.cristalizar tarea informe
          (cantera.muestras tarea)
      in
      Printf.eprintf "forja: la tarea %s ha madurado, semilla en %s\n%!"
        (Forja.Tarea.to_string tarea) d
    with e -> Printf.eprintf "forja: horno: %s\n%!" (Printexc.to_string e)
  in
  let ip =
    match Ipaddr.of_string (entorno "FORJA_IP" "127.0.0.1") with
    | Ok ip -> Eio_unix.Net.Ipaddr.of_unix (Ipaddr_unix.to_inet_addr ip)
    | Error (`Msg m) -> failwith m
  in
  let puerto = int_of_string (entorno "FORJA_PUERTO" "8090") in
  Printf.eprintf "forja: escuchando en %s:%d\n%!" (entorno "FORJA_IP" "127.0.0.1") puerto;
  Forja_http.Proxy.servir ~sw ~net ~ip ~puerto
    { cliente; upstream = Uri.of_string (entorno "FORJA_UPSTREAM" "https://api.anthropic.com");
      forja; madura }
