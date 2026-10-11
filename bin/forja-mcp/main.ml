(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* forja-mcp: la vitrina como servidor MCP por stdio. Ver doc/forja.md.
   Una línea JSON-RPC por mensaje, en los dos sentidos; stderr es el log. *)

let () =
  Eio_main.run @@ fun env ->
  let entrada = Eio.Buf_read.of_flow ~max_size:(16 * 1024 * 1024) (Eio.Stdenv.stdin env) in
  let salida = Eio.Stdenv.stdout env in
  prerr_endline "forja-mcp: sirviendo la vitrina por stdio";
  let rec bucle () =
    match Eio.Buf_read.line entrada with
    | l ->
        Option.iter
          (fun r -> Eio.Flow.copy_string (r ^ "\n") salida)
          (Forja_mcp.linea Vitrina.vitrina l);
        bucle ()
    | exception End_of_file -> ()
  in
  bucle ()
