(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* agencia-hook: los hooks de Claude Code de la agencia (doc/agencia.md).

   agencia-hook inicio   SessionStart: el catálogo de agentes del archivo
                         (GreptimeDB), menos los ocultos, como contexto
   agencia-hook fin      Stop: si la transcripción tiene encargos sin juzgar,
                         para la sesión una vez para pedir los veredictos

   AGENCIA_GREPTIME, AGENCIA_GREPTIME_DB (agencia) como agencia-mcp;
   AGENCIA_HOOK_OCULTOS, agentes separados por comas que no se anuncian (los
   de los pipelines).

   No falla nunca: con cualquier error no escribe nada y sale con 0; una
   sesión no se rompe por la agencia. *)

let var k = match Sys.getenv_opt k with Some v when String.trim v <> "" -> Some (String.trim v) | _ -> None
let imprimir = Option.iter print_string

let inicio () =
  match var "AGENCIA_GREPTIME" with
  | None -> ()
  | Some url ->
      let ocultos = String.split_on_char ',' (Option.value ~default:"" (var "AGENCIA_HOOK_OCULTOS")) |> List.map String.trim in
      Eio_main.run @@ fun env ->
      let post = Forja_http.Proxy.post (Forja_http.Proxy.cliente (Eio.Stdenv.net env)) in
      let archivo =
        Agencia_http.Archivo_greptime.crear ~post ~url:(Uri.of_string url)
          ~db:(Option.value ~default:"agencia" (var "AGENCIA_GREPTIME_DB")) ()
      in
      (* Por debajo del timeout del hook: sin GreptimeDB, sin catálogo. *)
      Eio.Time.with_timeout_exn (Eio.Stdenv.clock env) 3.0 (fun () -> archivo.agentes ())
      |> List.filter_map (fun (a : Agencia.Agente.t) ->
             let n = Forja.Tarea.to_string a.nombre in
             if List.mem n ocultos then None else Some (n, a.descripcion))
      |> Agencia_hook.contexto |> imprimir

let fin () =
  let entrada = Yojson.Safe.from_channel stdin in
  let campo k = Yojson.Safe.Util.member k entrada in
  match (campo "stop_hook_active", campo "transcript_path") with
  | `Bool true, _ -> ()  (* ya se pidió una vez: no se insiste *)
  | _, `String ruta ->
      let lineas =
        In_channel.with_open_text ruta In_channel.input_lines
        |> List.filter_map (fun l -> try Some (Yojson.Safe.from_string l) with _ -> None)
      in
      imprimir (Agencia_hook.bloqueo (Agencia_hook.pendientes lineas))
  | _ -> ()

let () =
  (try
     match Sys.argv with
     | [| _; "inicio" |] -> inicio ()
     | [| _; "fin" |] -> fin ()
     | _ -> prerr_endline "uso: agencia-hook inicio|fin"
   with e -> prerr_endline ("agencia-hook: " ^ Printexc.to_string e));
  exit 0
