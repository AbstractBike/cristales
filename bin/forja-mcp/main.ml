(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* forja-mcp: la forja como servidor MCP por stdio (mcp/CONTRATO.md).
   Una línea JSON-RPC por mensaje, en los dos sentidos; stderr es el log.

     forja-mcp            la forja de FORJA_URL (http://[b1c1:a2::1]:8090)
     forja-mcp --local    solo los cristales de la vitrina, en este proceso,
                          sin red (Claude Desktop fuera de la malla) *)

let url_por_defecto = "http://[b1c1:a2::1]:8090"

(* La forja por su API de introspección (/forja/…). *)
let remota cliente base =
  let base = Uri.to_string base in
  let base = if String.ends_with ~suffix:"/" base then String.sub base 0 (String.length base - 1) else base in
  let llamar meth ruta cuerpo =
    match Forja_http.Proxy.http cliente meth (Uri.of_string (base ^ ruta)) cuerpo with
    | r -> Ok r
    | exception e -> Error ("forja: " ^ Printexc.to_string e)
  in
  let fallo (c, b) = Printf.sprintf "forja: %d: %s" c b in
  let consultar ruta =
    match llamar `GET ruta "" with
    | Ok (c, b) when c >= 200 && c < 300 -> Ok b
    | Ok r -> Error (fallo r)
    | Error e -> Error e
  in
  let cristales () =
    let open Yojson.Safe.Util in
    Result.bind (consultar "/forja/vitrina") (fun b ->
        try
          Ok
            (Yojson.Safe.from_string b |> to_list
            |> List.map (fun c ->
                   { Forja_mcp.nombre = c |> member "tarea" |> to_string;
                     descripcion = c |> member "descripcion" |> to_string }))
        with e -> Error ("forja: vitrina ilegible: " ^ Printexc.to_string e))
  in
  let aplicar t e =
    let cuerpo = Yojson.Safe.to_string (`Assoc [ ("entrada", `String e) ]) in
    match llamar `POST ("/forja/vitrina/" ^ t) cuerpo with
    | Ok (404, _) -> Forja_mcp.No_existe
    | Ok (200, b) -> (
        match Yojson.Safe.from_string b with
        | `Assoc l -> (
            match (List.assoc_opt "salida" l, List.assoc_opt "defecto" l) with
            | Some (`String s), _ -> Salida s
            | _, Some (`String m) -> Defecto m
            | _ -> Fallo ("forja: respuesta sin salida ni defecto: " ^ b))
        | _ | (exception Yojson.Json_error _) -> Fallo ("forja: respuesta ilegible: " ^ b))
    | Ok r -> Fallo (fallo r)
    | Error e -> Fallo e
  in
  { Forja_mcp.cristales; aplicar; consultar = Some consultar }

let () =
  Mirage_crypto_rng_unix.use_default ();
  Eio_main.run @@ fun env ->
  let fuente =
    if Array.mem "--local" Sys.argv then (
      prerr_endline "forja-mcp: la vitrina de este proceso, sin forja";
      Forja_mcp.local Vitrina.vitrina)
    else
      let url = Option.value ~default:url_por_defecto (Sys.getenv_opt "FORJA_URL") in
      prerr_endline ("forja-mcp: forja en " ^ url);
      remota (Forja_http.Proxy.cliente (Eio.Stdenv.net env)) (Uri.of_string url)
  in
  let entrada = Eio.Buf_read.of_flow ~max_size:(64 * 1024 * 1024) (Eio.Stdenv.stdin env) in
  let salida = Eio.Stdenv.stdout env in
  let rec bucle () =
    match Eio.Buf_read.line entrada with
    | l ->
        Option.iter (fun r -> Eio.Flow.copy_string (r ^ "\n") salida) (Forja_mcp.linea fuente l);
        bucle ()
    | exception End_of_file -> ()
  in
  bucle ()
