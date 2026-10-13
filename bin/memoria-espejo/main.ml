(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* memoria-espejo: persona.md y escenas/ del repo memoria a los nodos que no
   lo tienen, a través de GreptimeDB (Memoria_recall.Espejo).

   memoria-espejo publicar   en el nodo del repo (MEMORIA_REPO): si cambió
                             algo desde la última publicación, la sube
   memoria-espejo bajar DIR  en los demás: la última publicación completa a
                             DIR, si no es la que ya hay

   MEMORIA_GREPTIME (https://greptime.pin), MEMORIA_GREPTIME_DB (memoria),
   MEMORIA_REPO (/logical-node/repositories/logical-license/memoria).
   Sale con 1 si GreptimeDB no responde; una publicación a medias no se baja. *)

module E = Memoria_recall.Espejo

let entorno k d = match Sys.getenv_opt k with Some v when String.trim v <> "" -> String.trim v | _ -> d
let log fmt = Printf.ksprintf prerr_endline ("memoria-espejo: " ^^ fmt)

let () =
  Mirage_crypto_rng_unix.use_default ();
  let orden = Array.to_list Sys.argv |> List.tl in
  Eio_main.run @@ fun env ->
  let post = Forja_http.Proxy.post (Forja_http.Proxy.cliente (Eio.Stdenv.net env)) in
  let url = Uri.of_string (entorno "MEMORIA_GREPTIME" "https://greptime.pin")
  and db = entorno "MEMORIA_GREPTIME_DB" "memoria" in
  let g = Forja_http.Greptime.conectar ~post ~url ~db in
  let sql q =
    match Forja_http.Greptime.sql g q with
    | Ok (c, b) when c < 300 -> (
        try Ok (Forja_http.Greptime.crudas (Yojson.Safe.from_string b)) with Yojson.Json_error e -> Error e)
    | Ok (c, b) -> Error (Printf.sprintf "%d: %s" c b)
    | Error e -> Error e
  in
  (* La tabla aún no existe hasta la primera publicación: eso no es fallo. *)
  let ultima () =
    match sql E.ultima with
    | Ok [ `List [ `String h; `Int n ] ] -> Ok (Some (h, n))
    | Ok _ -> Ok None
    | Error e when String.length e > 0 && (try ignore (Str.search_forward (Str.regexp_string "not found") e 0); true with Not_found -> false) -> Ok None
    | Error e -> Error e
  in
  match orden with
  | [ "publicar" ] -> (
      let fs = E.del_repo (entorno "MEMORIA_REPO" "/logical-node/repositories/logical-license/memoria") in
      let h = E.huella fs in
      match ultima () with
      | Error e -> log "GreptimeDB: %s" e; exit 1
      | Ok (Some (h', _)) when h' = h -> log "sin cambios (%s)" h
      | Ok _ when fs = [] -> log "repo vacío: nada que publicar"
      | Ok _ ->
          List.iter (Forja_http.Greptime.ingerir g ~tabla:E.tabla) (E.filas fs);
          log "publicados %d ficheros (%s)" (List.length fs) h)
  | [ "bajar"; dir ] -> (
      match ultima () with
      | Error e -> log "GreptimeDB: %s" e; exit 1
      | Ok None -> log "aún no hay nada publicado"
      | Ok (Some (h, _)) when E.huella_local dir = Some h -> log "al día (%s)" h
      | Ok (Some (h, total)) -> (
          match Result.bind (E.de_huella h) sql with
          | Error e -> log "GreptimeDB: %s" e; exit 1
          | Ok filas ->
              let fs =
                List.filter_map
                  (function `List [ `String ruta; `String contenido ] -> Some { E.ruta; contenido } | _ -> None)
                  filas
              in
              (* Una publicación a medias, o filas repetidas: se espera a la
                 siguiente pasada. *)
              if List.length fs <> total || E.huella fs <> h then (
                log "publicación %s incompleta (%d de %d): se deja la anterior" h (List.length fs) total;
                exit 1)
              else (
                E.escribir dir fs;
                log "bajados %d ficheros (%s) a %s" total h dir)))
  | _ ->
      prerr_endline "uso: memoria-espejo publicar | memoria-espejo bajar DIR";
      exit 2
