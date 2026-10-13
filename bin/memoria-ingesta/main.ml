(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* memoria-ingesta: los transcripts de Claude Code a la tabla memoria_l0 de
   GreptimeDB (doc/memoria.md, capa L0), limpios y redactados. Incremental
   por un cursor local; --todo vuelve a leerlo todo (es idempotente).

   memoria-ingesta [--raiz DIR] [--greptime URL] [--db BASE] [--cursor F]
                   [--todo] [--seco [--auditar]] *)

open Memoria_l0

let () =
  let home = Option.value ~default:"/tmp" (Sys.getenv_opt "HOME") in
  let raiz = ref (Filename.concat home ".claude/projects") in
  let greptime = ref "https://greptime.pin" in
  let db = ref "memoria" in
  let cursor = ref (Cursor.ruta_por_defecto ()) in
  let todo = ref false and seco = ref false and auditar = ref false in
  Arg.parse
    [ ("--raiz", Arg.Set_string raiz, "DIR  transcripts (~/.claude/projects)");
      ("--greptime", Arg.Set_string greptime, "URL  raíz HTTP de GreptimeDB (https://greptime.pin)");
      ("--db", Arg.Set_string db, "BASE  base de datos (memoria)");
      ("--cursor", Arg.Set_string cursor, "F  fichero del cursor ($XDG_STATE_HOME/memoria/cursor)");
      ("--todo", Arg.Set todo, " leerlo todo desde el principio, sin cursor");
      ("--seco", Arg.Set seco, " no escribir nada: solo contar");
      ( "--auditar",
        Arg.Set auditar,
        " con --seco: una línea por redacción (tipo, silueta, lo que la precede, fichero), sin el secreto" ) ]
    (fun a -> raise (Arg.Bad ("argumento de más: " ^ a)))
    "memoria-ingesta: transcripts de Claude Code a memoria_l0";
  let t0 = Unix.gettimeofday () in
  let estado = if !todo then Cursor.vacio () else Cursor.cargar !cursor in
  let e =
    if !seco then
      let al_redactar =
        if !auditar then
          Some
            (fun f t ~antes forma ->
              Printf.printf "%s\t%s\t%s\t%s\n" (Redaccion.nombre t) forma (String.escaped antes) f)
        else None
      in
      Ingesta.pasar ~raiz:!raiz ~cursor:estado ?al_redactar ()
    else (
      Mirage_crypto_rng_unix.use_default ();
      Eio_main.run @@ fun env ->
      let cliente = Forja_http.Proxy.cliente (Eio.Stdenv.net env) in
      let g =
        Forja_http.Greptime.conectar ~post:(Forja_http.Proxy.post cliente) ~url:(Uri.of_string !greptime) ~db:!db
      in
      let sql s =
        match Forja_http.Greptime.sql g s with
        | Ok (c, _) when c < 300 -> Ok ()
        | Ok (c, b) -> Error (Printf.sprintf "greptime %d: %s" c b)
        | Error m -> Error m
      in
      (match sql Tabla.crear with Ok () -> () | Error m -> failwith m);
      let nodo = Unix.gethostname () in
      Ingesta.pasar ~raiz:!raiz ~cursor:estado
        ~escribir:(fun ms -> sql (Tabla.insertar ~nodo ms))
        ~al_fichero:(fun _ -> Cursor.guardar !cursor estado)
        ())
  in
  print_endline (Ingesta.informe e);
  Printf.printf "tiempo: %.1f s\n" (Unix.gettimeofday () -. t0);
  if e.fallidos > 0 then exit 1
