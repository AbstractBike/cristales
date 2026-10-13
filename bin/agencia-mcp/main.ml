(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* agencia-mcp: la agencia como servidor MCP por stdio (doc/agencia.md).
   Una línea JSON-RPC por mensaje, en los dos sentidos; stderr es el log.
   Se configura por entorno:

   AGENCIA_ANTHROPIC   Messages API          (la forja: http://[b1c1:a2::1]:8090)
   AGENCIA_OPENAI      Chat Completions      (sin ella, no hay modelos openai:)
   AGENCIA_ESCALERA    la de los agentes nuevos, del más barato al más capaz
                       (claude-haiku-5-5,claude-sonnet-5-5,claude-opus-5-5)
   AGENCIA_GREPTIME    raíz HTTP de GreptimeDB (sin ella, archivo en memoria)
   AGENCIA_GREPTIME_DB base de datos         (agencia)
   ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN, OPENAI_API_KEY: pasan tal cual. *)

let entorno k d = Option.value ~default:d (Sys.getenv_opt k)

(* Una variable con algo dentro. *)
let var k = match Sys.getenv_opt k with Some v when String.trim v <> "" -> Some (String.trim v) | _ -> None

let bearer v = "Bearer " ^ v

let escalera () =
  String.split_on_char ',' (entorno "AGENCIA_ESCALERA" "claude-haiku-5-5,claude-sonnet-5-5,claude-opus-5-5")
  |> List.map (fun m ->
         match Agencia.Modelo.de_texto m with Ok m -> m | Error e -> failwith ("AGENCIA_ESCALERA: " ^ e))

let () =
  Mirage_crypto_rng_unix.use_default ();
  Eio_main.run @@ fun env ->
  let cliente = Forja_http.Proxy.cliente (Eio.Stdenv.net env) in
  let archivo =
    match Sys.getenv_opt "AGENCIA_GREPTIME" with
    | Some url ->
        let post = Forja_http.Proxy.post cliente and url = Uri.of_string url
        and db = entorno "AGENCIA_GREPTIME_DB" "agencia" in
        (* Y cada encargo y veredicto, medido (Medidas): las métricas de la
           agencia, en la misma base. *)
        Agencia_http.Medidas.con_medidas
          (Agencia_http.Medidas.a_greptime (Forja_http.Greptime.conectar ~post ~url ~db))
          (Agencia_http.Archivo_greptime.crear ~post ~url ~db ())
    | None ->
        prerr_endline "agencia-mcp: sin AGENCIA_GREPTIME, el archivo vive en memoria y se pierde al salir";
        Agencia.Archivo.en_memoria ()
  in
  let destinos =
    { Agencia_http.Llm.anthropic = Uri.of_string (entorno "AGENCIA_ANTHROPIC" "http://[b1c1:a2::1]:8090");
      openai = Option.map Uri.of_string (Sys.getenv_opt "AGENCIA_OPENAI");
      cabeceras_anthropic =
        List.filter_map Fun.id
          [ Option.map (fun v -> ("x-api-key", v)) (var "ANTHROPIC_API_KEY");
            Option.map (fun v -> ("authorization", bearer v)) (var "ANTHROPIC_AUTH_TOKEN") ];
      cabeceras_openai = Option.to_list (Option.map (fun v -> ("authorization", bearer v)) (var "OPENAI_API_KEY")) }
  in
  let azar = Random.State.make_self_init () in
  let efectos =
    { Agencia_mcp.archivo;
      llamar = Agencia_http.Llm.llamar (Eio.Stdenv.clock env) cliente destinos ~archivo;
      id = (fun () -> String.init 16 (fun _ -> "0123456789abcdef".[Random.State.int azar 16]));
      escalera = escalera ();
      politica = Agencia.Politica.por_defecto }
  in
  let servidor = Agencia_mcp.servidor efectos in
  let entrada = Eio.Buf_read.of_flow ~max_size:(64 * 1024 * 1024) (Eio.Stdenv.stdin env) in
  let salida = Eio.Stdenv.stdout env in
  let rec bucle () =
    match Eio.Buf_read.line entrada with
    | l ->
        Option.iter (fun r -> Eio.Flow.copy_string (r ^ "\n") salida) (Mcp_rpc.linea servidor l);
        bucle ()
    | exception End_of_file -> ()
  in
  bucle ()
