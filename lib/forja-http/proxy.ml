(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type respuesta = { estado : Http.Status.t; cabeceras : Http.Header.t; cuerpo : string }

(* Cliente HTTP(S) sobre Eio. Necesita un RNG instalado para TLS
   (Mirage_crypto_rng_unix.use_default). *)
let cliente net =
  let authenticator =
    match Ca_certs.authenticator () with
    | Ok a -> a
    | Error (`Msg m) -> failwith ("forja: sin certificados raíz: " ^ m)
  in
  let tls =
    match Tls.Config.client ~authenticator () with
    | Ok c -> c
    | Error (`Msg m) -> failwith ("forja: TLS: " ^ m)
  in
  let https uri flujo =
    let host =
      Option.bind (Uri.host uri) (fun h ->
          Result.to_option (Result.bind (Domain_name.of_string h) Domain_name.host))
    in
    Tls_eio.client_of_flow tls ?host flujo
  in
  Cohttp_eio.Client.make ~https:(Some https) net

let leer cuerpo = Eio.Buf_read.(parse_exn take_all) cuerpo ~max_size:max_int

let llamar cliente meth uri ~cabeceras cuerpo =
  Eio.Switch.run @@ fun sw ->
  let cabeceras =
    Http.Header.replace cabeceras "content-length" (string_of_int (String.length cuerpo))
  in
  let r, b =
    Cohttp_eio.Client.call cliente ~sw ~headers:cabeceras
      ~body:(Cohttp_eio.Body.of_string cuerpo) meth uri
  in
  { estado = Http.Response.status r; cabeceras = Http.Response.headers r; cuerpo = leer b }

(* Para la cantera de GreptimeDB. *)
let post cliente uri ~tipo cuerpo =
  match
    llamar cliente `POST uri cuerpo
      ~cabeceras:(Http.Header.of_list [ ("content-type", tipo) ])
  with
  | r -> Ok (Http.Status.to_int r.estado, r.cuerpo)
  | exception e -> Error (Printexc.to_string e)

(* Cabeceras de salto que no se reenvían. Sin accept-encoding el LLM
   contesta sin comprimir y la forja puede leer la respuesta. *)
let fuera =
  [ "host"; "content-length"; "connection"; "transfer-encoding";
    "accept-encoding"; Anthropic.cabecera_tarea ]

let limpiar h = List.fold_left Http.Header.remove h fuera

type t = {
  cliente : Cohttp_eio.Client.t;
  upstream : Uri.t;
  forja : Forja.t;
  madura : Forja.Tarea.t -> Forja.Madurez.informe -> unit;
}

let reenviar p req cuerpo =
  let destino = Uri.of_string (Http.Request.resource req) in
  let uri =
    Uri.with_query (Uri.with_path p.upstream (Uri.path destino)) (Uri.query destino)
  in
  llamar p.cliente (Http.Request.meth req) uri
    ~cabeceras:(limpiar (Http.Request.headers req)) cuerpo

let con_fuente ?tarea fuente r =
  let h = Http.Header.replace (limpiar r.cabeceras) "x-forja-fuente" fuente in
  let h =
    match tarea with
    | Some t -> Http.Header.replace h "x-forja-tarea" (Forja.Tarea.to_string t)
    | None -> h
  in
  { r with cabeceras = h }

let json estado j =
  { estado;
    cabeceras = Http.Header.of_list [ ("content-type", "application/json") ];
    cuerpo = Yojson.Safe.to_string j }

let liquido p req cuerpo (pet : Forja.peticion) ~contrastar ~defecto =
  let r, contraste =
    if contrastar then
      Eio.Fiber.pair (fun () -> reenviar p req cuerpo) (fun () -> Some (reenviar p req cuerpo))
    else (reenviar p req cuerpo, None)
  in
  let texto r =
    if Http.Status.to_int r.estado = 200 then
      try Anthropic.texto (Yojson.Safe.from_string r.cuerpo) with Yojson.Json_error _ -> None
    else None
  in
  (match texto r with
  | None -> ()
  | Some salida -> (
      let contraste = Option.bind contraste texto in
      match Forja.aprender p.forja pet ?contraste ?defecto salida with
      | Some informe -> p.madura pet.tarea informe
      | None -> ()));
  con_fuente ~tarea:pet.tarea (if defecto = None then "liquido" else "defecto") r

let mensajes p req cuerpo =
  let peticion =
    match Yojson.Safe.from_string cuerpo with
    | j ->
        let tarea = Http.Header.get (Http.Request.headers req) Anthropic.cabecera_tarea in
        Result.map (fun pet -> (pet, j)) (Anthropic.peticion ~tarea j)
    | exception Yojson.Json_error e -> Error e
  in
  match peticion with
  | Error _ -> con_fuente "paso" (reenviar p req cuerpo)
  | Ok (pet, j) -> (
      match Forja.decidir p.forja pet with
      | Por_cristal salida ->
          let modelo =
            match Yojson.Safe.Util.member "model" j with `String m -> m | _ -> "forja"
          in
          con_fuente ~tarea:pet.tarea "cristal"
            (json `OK (Anthropic.respuesta ~modelo salida))
      | Fallo { etapa; motivo } ->
          con_fuente ~tarea:pet.tarea "defecto"
            (json `Unprocessable_entity
               (Anthropic.error ~tipo:"invalid_request_error"
                  (Printf.sprintf "forja: la tarea %s es cristalina y su cristal no sabe: %s"
                     etapa motivo)))
      | Al_liquido { contrastar; defecto } ->
          liquido p req cuerpo pet ~contrastar ~defecto)

let atender p req cuerpo =
  match (Http.Request.meth req, Uri.path (Uri.of_string (Http.Request.resource req))) with
  | `POST, "/v1/messages" -> mensajes p req cuerpo
  | _ -> con_fuente "paso" (reenviar p req cuerpo)

let servir ~sw ~net ~ip ~puerto p =
  let callback _ req cuerpo =
    let r =
      try atender p req (leer cuerpo)
      with e ->
        json `Bad_gateway
          (Anthropic.error ~tipo:"api_error" ("forja: " ^ Printexc.to_string e))
    in
    Cohttp_eio.Server.respond_string ~headers:r.cabeceras ~status:r.estado ~body:r.cuerpo ()
  in
  let socket =
    Eio.Net.listen net ~sw ~backlog:128 ~reuse_addr:true
      (`Tcp (ip, puerto))
  in
  Cohttp_eio.Server.run socket (Cohttp_eio.Server.make ~callback ())
    ~on_error:(fun e -> Printf.eprintf "forja: %s\n%!" (Printexc.to_string e))
