(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type respuesta = { estado : Http.Status.t; cabeceras : Http.Header.t; cuerpo : string }

(* Cliente HTTP(S) sobre Eio. Necesita un RNG instalado para TLS
   (Mirage_crypto_rng_unix.use_default). TLS se configura en la primera
   conexión HTTPS: quien solo habla HTTP (la malla, el loopback) no necesita
   certificados raíz. *)
let cliente net =
  let tls =
    lazy
      (let authenticator =
         match Ca_certs.authenticator () with
         | Ok a -> a
         | Error (`Msg m) -> failwith ("forja: sin certificados raíz: " ^ m)
       in
       match Tls.Config.client ~authenticator () with
       | Ok c -> c
       | Error (`Msg m) -> failwith ("forja: TLS: " ^ m))
  in
  let https uri flujo =
    let host =
      Option.bind (Uri.host uri) (fun h ->
          Result.to_option (Result.bind (Domain_name.of_string h) Domain_name.host))
    in
    Tls_eio.client_of_flow (Lazy.force tls) ?host flujo
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

let http cliente meth uri cuerpo =
  let r = llamar cliente meth uri cuerpo ~cabeceras:(Http.Header.of_list [ ("content-type", "application/json") ]) in
  (Http.Status.to_int r.estado, r.cuerpo)

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
  openai : Uri.t option;
  forja : Forja.t;
  madura : Forja.Tarea.t -> Forja.Madurez.informe -> unit;
}

(* Lo que la forja necesita de una API para atender sus tareas: Anthropic y
   Openai lo cumplen igual. *)
module type API = sig
  type forma

  val peticion : tarea:string option -> Yojson.Safe.t -> (Forja.peticion * forma, string) result
  val salida : forma -> Yojson.Safe.t -> string option
  val respuesta : modelo:string -> forma -> string -> (Yojson.Safe.t, string) result
  val error : tipo:string -> string -> Yojson.Safe.t
  val campos : Yojson.Safe.t -> string list
  val restringir : Yojson.Safe.t -> string list -> Yojson.Safe.t
  val uso : Yojson.Safe.t -> (int * int) option
end

(* {1 Métricas}

   Lo que pasa por la forja, para vmagent (GET /metrics). Un registro por
   proceso: hay una forja por proceso. *)

let metricas = Metricas.crear ()
let segundos = [ 0.005; 0.025; 0.1; 0.25; 0.5; 1.; 2.5; 5.; 10.; 30.; 60.; 120.; 300. ]

let () =
  let open Metricas in
  let m = metricas in
  contador m "forja_peticiones_total" ~ayuda:"Peticiones atendidas, por API, fuente (cristal, parcial, liquido, defecto, paso) y tarea.";
  histograma m "forja_peticion_segundos" ~ayuda:"Lo que tarda la forja en responder, por API y fuente." ~cubos:segundos;
  histograma m "forja_llm_segundos" ~ayuda:"Lo que tarda el LLM de detrás, por API y tarea." ~cubos:segundos;
  contador m "forja_llm_respuestas_total" ~ayuda:"Respuestas del LLM de detrás, por API y código HTTP.";
  contador m "forja_llm_tokens_total" ~ayuda:"Tokens que gastó el LLM en las tareas, por API, tarea y tipo (entrada, salida).";
  histograma m "forja_cristal_segundos" ~ayuda:"Lo que tarda un cristal, por tarea." ~cubos:[ 0.0001; 0.0005; 0.001; 0.005; 0.01; 0.05; 0.1; 0.5; 1. ];
  contador m "forja_campos_total" ~ayuda:"Campos de las salidas estructuradas de tareas con cristal, por tarea y quién los dio (cristal, llm).";
  contador m "forja_pasos_total" ~ayuda:"Peticiones que no son tareas, por ruta y motivo.";
  contador m "forja_maduraciones_total" ~ayuda:"Tareas que han madurado (una vez por tarea y proceso)."

let sumar ?etiquetas n = Metricas.sumar metricas n ?etiquetas 1.

(* Las medidas que se calculan al servir: el estado de cada tarea. *)
let medidas forja =
  let ts = Forja.tareas forja in
  let fase = function `Liquida -> "liquida" | `Mixta -> "mixta" | `Cristalina -> "cristalina" in
  let por f = List.map (fun (r : Forja.resumen) -> ([ ("tarea", Forja.Tarea.to_string r.tarea); ("fase", fase r.fase) ], f r)) ts in
  let medida nombre ayuda f = { Metricas.nombre; ayuda; valores = por f } in
  [ medida "forja_tarea_muestras" "Muestras de la tarea en la cantera." (fun r -> float r.informe.muestras);
    medida "forja_tarea_contrastes" "Contrastes de la tarea (pedida dos veces al LLM)." (fun r -> float r.informe.contrastes);
    medida "forja_tarea_coincidencias" "Contrastes en que el LLM repitió la salida entera." (fun r -> float r.informe.coincidencias);
    medida "forja_tarea_madura" "1 si la tarea está madura para nuclear." (fun r -> if r.madura then 1. else 0.);
    medida "forja_tarea_campos_maduros" "Campos maduros de una tarea estructurada." (fun r -> float (List.length r.campos_maduros));
    { Metricas.nombre = "forja_campo_estabilidad";
      ayuda = "Fracción de contrastes en que el LLM repitió el campo.";
      valores =
        List.concat_map
          (fun (r : Forja.resumen) ->
            List.map
              (fun (k, n) ->
                ( [ ("tarea", Forja.Tarea.to_string r.tarea); ("campo", k) ],
                  float n /. float (max 1 r.informe.estructurados) ))
              r.informe.campos)
          ts };
    { Metricas.nombre = "forja_vitrina_cristales";
      ayuda = "Cristales en la vitrina.";
      valores = [ ([], float (List.length (Forja.Vitrina.listar (Forja.vitrina forja)))) ] } ]


let reenviar p upstream req cuerpo =
  let destino = Uri.of_string (Http.Request.resource req) in
  let uri =
    Uri.with_query (Uri.with_path upstream (Uri.path destino)) (Uri.query destino)
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

(* Por qué la forja deja pasar una petición sin hacerla tarea: streaming,
   herramientas, varios turnos, response_format sin esquema... Antes el motivo
   se descartaba, y un cliente que mandaba json_object pasaba por la forja sin
   dejar una sola muestra sin que nadie lo supiera (log-triage, 2026-10-12).
   Se dice una vez por motivo y cliente (su tarea explícita o, si no, su
   modelo), no en cada petición: el servidor es un solo dominio de Eio, así
   que basta una tabla. *)
let pasos_vistos : (string * string, unit) Hashtbl.t = Hashtbl.create 16

let avisar_paso req j motivo =
  sumar "forja_pasos_total"
    ~etiquetas:[ ("ruta", Uri.path (Uri.of_string (Http.Request.resource req))); ("motivo", motivo) ];
  let quien =
    match Http.Header.get (Http.Request.headers req) Anthropic.cabecera_tarea, j with
    | Some t, _ -> "tarea " ^ t
    | None, Some j -> (
        match Yojson.Safe.Util.member "model" j with
        | `String m -> "modelo " ^ m
        | _ -> "sin tarea ni modelo"
        | exception Yojson.Safe.Util.Type_error _ -> "sin tarea ni modelo")
    | None, None -> "sin tarea ni modelo"
  in
  if not (Hashtbl.mem pasos_vistos (motivo, quien)) then begin
    Hashtbl.replace pasos_vistos (motivo, quien) ();
    Printf.eprintf "forja: %s pasa sin muestra (%s): %s\n%!"
      (Uri.path (Uri.of_string (Http.Request.resource req))) quien motivo
  end

let json estado j =
  { estado;
    cabeceras = Http.Header.of_list [ ("content-type", "application/json") ];
    cuerpo = Yojson.Safe.to_string j }

(* Una tarea por la API [A], con el LLM de [upstream] detrás. *)
let mensajes (module A : API) ~api upstream p req cuerpo =
  let tarea_de = function Some (t : Forja.peticion) -> Forja.Tarea.to_string t.tarea | None -> "" in
  (* Cada llamada al LLM, medida: tiempo, código y, si es una tarea, tokens. *)
  let reenviar ?pet ?(cuerpo = cuerpo) () =
    let t0 = Unix.gettimeofday () in
    let r = reenviar p upstream req cuerpo in
    let tarea = tarea_de pet in
    Metricas.observar metricas "forja_llm_segundos" ~etiquetas:[ ("api", api); ("tarea", tarea) ]
      (Unix.gettimeofday () -. t0);
    sumar "forja_llm_respuestas_total" ~etiquetas:[ ("api", api); ("codigo", string_of_int (Http.Status.to_int r.estado)) ];
    (if pet <> None && Http.Status.to_int r.estado = 200 then
       match A.uso (Yojson.Safe.from_string r.cuerpo) with
       | Some (e, s) ->
           let tok tipo n =
             Metricas.sumar metricas "forja_llm_tokens_total"
               ~etiquetas:[ ("api", api); ("tarea", tarea); ("tipo", tipo) ] (float n)
           in
           tok "entrada" e;
           tok "salida" s
       | None -> ()
       | exception Yojson.Json_error _ -> ());
    r
  in
  let campos (pet : Forja.peticion) de n =
    if n > 0 then
      Metricas.sumar metricas "forja_campos_total"
        ~etiquetas:[ ("tarea", Forja.Tarea.to_string pet.tarea); ("de", de) ] (float n)
  in
  let salida forma r =
    if Http.Status.to_int r.estado = 200 then
      try A.salida forma (Yojson.Safe.from_string r.cuerpo) with Yojson.Json_error _ -> None
    else None
  in
  let aprender (pet : Forja.peticion) ?contraste ?defecto s =
    match Forja.aprender p.forja pet ?contraste ?defecto s with
    | Some informe ->
        sumar "forja_maduraciones_total" ~etiquetas:[ ("tarea", Forja.Tarea.to_string pet.tarea) ];
        p.madura pet.tarea informe
    | None -> ()
  in
  let liquido (pet : Forja.peticion) forma ~contrastar ~defecto =
    let r, contraste =
      if contrastar then Eio.Fiber.pair (reenviar ~pet) (fun () -> Some (reenviar ~pet ()))
      else (reenviar ~pet (), None)
    in
    Option.iter
      (fun s -> aprender pet ?contraste:(Option.bind contraste (salida forma)) ?defecto s)
      (salida forma r);
    con_fuente ~tarea:pet.tarea (if defecto = None then "liquido" else "defecto") r
  in
  (* Los campos del esquema que el cristal no dio. Con todos (o sin esquema,
     o si no dio un objeto), ninguno: el resto es cosa de [A.respuesta]. *)
  let faltan j salida =
    match (A.campos j, Forja.Campos.de salida) with
    | [], _ | _, None -> []
    | ks, Some dados -> List.filter (fun k -> not (List.mem_assoc k dados)) ks
  in
  (* Un cristal parcial: dio unos campos y el LLM pone solo los que faltan,
     con el esquema reducido a ellos (menos que generar). La muestra lleva
     el objeto entero y, como defecto, qué faltaba: sin los campos del LLM
     no habría respuesta, y con ellos la semilla sabe qué aprender. *)
  let parcial (pet : Forja.peticion) forma j ~modelo dada ks =
    let motivo = "parcial: faltan " ^ String.concat ", " ks in
    match Forja.Vitrina.buscar (Forja.vitrina p.forja) pet.tarea with
    | Some (`Cristalina, _) ->
        con_fuente ~tarea:pet.tarea "defecto"
          (json `Unprocessable_entity
             (A.error ~tipo:"invalid_request_error"
                (Printf.sprintf "forja: la tarea %s es cristalina y su cristal no da todo: %s"
                   (Forja.Tarea.to_string pet.tarea) motivo)))
    | _ -> (
        let r = reenviar ~pet ~cuerpo:(Yojson.Safe.to_string (A.restringir j ks)) () in
        let entera =
          match (Option.bind (salida forma r) Forja.Campos.de, Forja.Campos.de dada) with
          | Some llm, Some dados ->
              Some (Comun.cadena (`Assoc (dados @ List.filter (fun (k, _) -> List.mem k ks) llm)))
          | _ -> None
        in
        match Option.map (fun s -> (s, A.respuesta ~modelo forma s)) entera with
        | Some (s, Ok resp) ->
            campos pet "cristal" (List.length (A.campos j) - List.length ks);
            campos pet "llm" (List.length ks);
            aprender pet ~defecto:motivo s;
            con_fuente ~tarea:pet.tarea "parcial" (json `OK resp)
        | Some (_, Error _) | None -> con_fuente ~tarea:pet.tarea "defecto" r)
  in
  let j = try Some (Yojson.Safe.from_string cuerpo) with Yojson.Json_error _ -> None in
  let peticion =
    match j with
    | Some j ->
        let tarea = Http.Header.get (Http.Request.headers req) Anthropic.cabecera_tarea in
        Result.map (fun (pet, forma) -> (pet, forma, j)) (A.peticion ~tarea j)
    | None -> Error "el cuerpo no es JSON"
  in
  match peticion with
  | Error motivo ->
      avisar_paso req j motivo;
      con_fuente "paso" (reenviar ())
  | Ok (pet, forma, j) -> (
      let t0 = Unix.gettimeofday () in
      let decision = Forja.decidir p.forja pet in
      if Option.is_some (Forja.Vitrina.buscar (Forja.vitrina p.forja) pet.tarea) then
        Metricas.observar metricas "forja_cristal_segundos"
          ~etiquetas:[ ("tarea", Forja.Tarea.to_string pet.tarea) ]
          (Unix.gettimeofday () -. t0);
      match decision with
      | Por_cristal salida -> (
          let modelo =
            match Yojson.Safe.Util.member "model" j with `String m -> m | _ -> "forja"
          in
          match faltan j salida with
          | [] -> (
              match A.respuesta ~modelo forma salida with
              | Ok r ->
                  campos pet "cristal" (List.length (A.campos j));
                  con_fuente ~tarea:pet.tarea "cristal" (json `OK r)
              (* Un cristal estructurado que no da JSON tiene una impureza: se
                 trata como defecto y responde el LLM. *)
              | Error motivo -> liquido pet forma ~contrastar:false ~defecto:(Some motivo))
          | ks -> parcial pet forma j ~modelo salida ks)
      | Fallo { etapa; motivo } ->
          con_fuente ~tarea:pet.tarea "defecto"
            (json `Unprocessable_entity
               (A.error ~tipo:"invalid_request_error"
                  (Printf.sprintf "forja: la tarea %s es cristalina y su cristal no sabe: %s"
                     etapa motivo)))
      | Al_liquido { contrastar; defecto } -> liquido pet forma ~contrastar ~defecto)

(* Cada respuesta, contada por su fuente y su tarea (las cabeceras que ya
   lleva) y medida de punta a punta. *)
let medir api r t0 =
  let h k = Option.value ~default:"" (Http.Header.get r.cabeceras k) in
  let fuente = h "x-forja-fuente" in
  sumar "forja_peticiones_total" ~etiquetas:[ ("api", api); ("fuente", fuente); ("tarea", h "x-forja-tarea") ];
  Metricas.observar metricas "forja_peticion_segundos" ~etiquetas:[ ("api", api); ("fuente", fuente) ]
    (Unix.gettimeofday () -. t0);
  r

let atender p req cuerpo =
  let uri = Uri.of_string (Http.Request.resource req) and meth = Http.Request.meth req in
  let t0 = Unix.gettimeofday () in
  match (meth, Uri.path uri) with
  | `GET, "/metrics" ->
      { estado = `OK;
        cabeceras = Http.Header.of_list [ ("content-type", "text/plain; version=0.0.4; charset=utf-8") ];
        cuerpo = Metricas.servir metricas (medidas p.forja) }
  | _ -> (
      match Introspeccion.atender p.forja ~meth ~ruta:(Uri.path uri) ~query:(Uri.query uri) cuerpo with
      | Some r ->
          { estado = Http.Status.of_int r.estado;
            cabeceras = Http.Header.of_list [ ("content-type", r.tipo) ];
            cuerpo = r.cuerpo }
      | None -> (
          match (meth, Uri.path uri, p.openai) with
          | `POST, "/v1/messages", _ ->
              medir "anthropic" (mensajes (module Anthropic) ~api:"anthropic" p.upstream p req cuerpo) t0
          | `POST, "/v1/chat/completions", Some u ->
              medir "openai" (mensajes (module Openai) ~api:"openai" u p req cuerpo) t0
          | _ -> medir "otra" (con_fuente "paso" (reenviar p p.upstream req cuerpo)) t0))

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
