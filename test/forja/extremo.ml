(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* De extremo a extremo por HTTP: cliente → forja → LLM falso. La tarea
   empieza líquida, madura y deja su semilla en el horno; con su cristal en
   la vitrina el LLM deja de recibirla. *)

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let puerto_llm = 18_391
let puerto_forja = 18_392
let llamadas = ref 0
let llamadas_openai = ref 0
let pedidos_openai : string list ref = ref []
let leer b = Eio.Buf_read.(parse_exn take_all) b ~max_size:max_int

(* El LLM falso: pone en mayúsculas el texto del usuario; con herramienta
   forzada, lo devuelve como su entrada: {"mayus": …}. *)
let rec llm _ req cuerpo =
  if Http.Request.resource req = "/v1/chat/completions" then llm_openai (leer cuerpo) else
  let () = incr llamadas in
  let open Yojson.Safe.Util in
  let j = Yojson.Safe.from_string (leer cuerpo) in
  let texto = String.uppercase_ascii (j |> member "messages" |> index 0 |> member "content" |> to_string) in
  let forma, salida =
    match j |> member "tool_choice" with
    | `Assoc _ as tc -> let n = tc |> member "name" |> to_string in (Forja_http.Anthropic.Herramienta n, Yojson.Safe.to_string (`Assoc [ ("mayus", `String texto) ]))
    | _ -> (Forja_http.Anthropic.Texto, texto)
  in
  let r = Result.get_ok (Forja_http.Anthropic.respuesta ~modelo:"falso" forma salida) in
  Cohttp_eio.Server.respond_string ~status:`OK ~body:(Yojson.Safe.to_string r) ()

(* Por Chat Completions: lo mismo sobre el último mensaje; con json_schema,
   el objeto {"mayus": …} en el contenido. *)
and llm_openai cuerpo =
  incr llamadas_openai;
  let open Yojson.Safe.Util in
  let j = Yojson.Safe.from_string cuerpo in
  let texto = String.uppercase_ascii (j |> member "messages" |> to_list |> List.rev |> List.hd |> member "content" |> to_string) in
  let forma, salida =
    match j |> member "response_format" with
    | `Assoc _ as rf -> (
        (* Con propiedades, cada una "<campo>:<TEXTO>"; sin ellas, {"mayus": …}. *)
        let ks = Forja_http.Openai.campos (`Assoc [ ("response_format", rf) ]) in
        pedidos_openai := ks;
        let obj = if ks = [] then [ ("mayus", `String texto) ] else List.map (fun k -> (k, `String (k ^ ":" ^ texto))) ks in
        (Forja_http.Openai.Esquema, Yojson.Safe.to_string (`Assoc obj)))
    | _ -> (Forja_http.Openai.Texto, texto)
  in
  let r = Result.get_ok (Forja_http.Openai.respuesta ~modelo:"falso" forma salida) in
  Cohttp_eio.Server.respond_string ~status:`OK ~body:(Yojson.Safe.to_string r) ()

let escuchar ~sw net puerto =
  Eio.Net.listen net ~sw ~backlog:16 ~reuse_addr:true
    (`Tcp (Eio.Net.Ipaddr.V4.loopback, puerto))

let enviar cliente ?(cabeceras = []) ~ruta ~salida cuerpo =
  Eio.Switch.run @@ fun sw ->
  let uri = Uri.of_string (Printf.sprintf "http://127.0.0.1:%d%s" puerto_forja ruta) in
  let headers =
    Http.Header.of_list
      (("content-type", "application/json")
      :: ("content-length", string_of_int (String.length cuerpo))
      :: cabeceras)
  in
  let r, b =
    Cohttp_eio.Client.post cliente ~sw ~headers ~body:(Cohttp_eio.Body.of_string cuerpo) uri
  in
  let fuente = Option.value ~default:"" (Http.Header.get (Http.Response.headers r) "x-forja-fuente") in
  let texto = salida (Yojson.Safe.from_string (leer b)) in
  (Http.Status.to_int (Http.Response.status r), fuente, texto)

let pedir cliente ?cabeceras ?(forma = Forja_http.Anthropic.Texto) cuerpo =
  enviar cliente ?cabeceras ~ruta:"/v1/messages" ~salida:(Forja_http.Anthropic.salida forma) cuerpo

let pedir_openai cliente ?(forma = Forja_http.Openai.Esquema) cuerpo =
  enviar cliente ~ruta:"/v1/chat/completions" ~salida:(Forja_http.Openai.salida forma) cuerpo

let mensaje ?(extra = "") t =
  Printf.sprintf
    {|{"model":"m","max_tokens":10,"system":"Pon en mayúsculas.",%s"messages":[{"role":"user","content":%S}]}|}
    extra t

let politica =
  { Forja.Madurez.minimo = 3; contrastar_cada = 2; contrastes = 1; estabilidad = 1.0 }

let mayus =
  Cristal.cristal "mayus" (fun s ->
      if String.exists (function '0' .. '9' -> true | _ -> false) s then Error "dígitos"
      else Ok (String.uppercase_ascii s))

let () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let net = Eio.Stdenv.net env in
  let cliente = Cohttp_eio.Client.make ~https:None net in
  let horno = Eio.Path.(Eio.Stdenv.cwd env / "horno-prueba") in
  let tarea = Forja.Tarea.de_plantilla "Pon en mayúsculas." in
  let maduras = ref [] in
  let llm_uri = Uri.of_string (Printf.sprintf "http://127.0.0.1:%d" puerto_llm) in
  let proxy ?(openai = true) vitrina cantera =
    { Forja_http.Proxy.cliente;
      upstream = llm_uri;
      openai = (if openai then Some llm_uri else None);
      forja = Forja.crear ~politica ~vitrina ~cantera ();
      madura =
        (fun t i ->
          maduras := t :: !maduras;
          ignore
            (Forja_http.Horno.cocer ~dir:horno ~prompt:Forja_http.Prompt.cristalizar t i
               (cantera.muestras t))) }
  in
  let con_forja p f =
    Eio.Switch.run @@ fun sw' ->
    Eio.Fiber.first
      (fun () ->
        Forja_http.Proxy.servir ~sw:sw' ~net ~ip:Eio.Net.Ipaddr.V4.loopback
          ~puerto:puerto_forja p)
      f
  in
  Eio.Fiber.fork_daemon ~sw (fun () ->
      Cohttp_eio.Server.run (escuchar ~sw net puerto_llm)
        (Cohttp_eio.Server.make ~callback:llm ())
        ~on_error:raise);
  let cantera = Forja.Cantera.en_memoria () in
  (* Fase líquida. *)
  con_forja (proxy Forja.Vitrina.vacia cantera) (fun () ->
      let r = List.map (fun t -> pedir cliente (mensaje t)) [ "uno"; "dos"; "tres" ] in
      comprueba "líquido responde lo del LLM"
        (r = [ (200, "liquido", Some "UNO"); (200, "liquido", Some "DOS"); (200, "liquido", Some "TRES") ]);
      comprueba "una contrastada: 4 llamadas al LLM para 3 peticiones" (!llamadas = 4);
      comprueba "la tarea madura" (!maduras = [ tarea ]);
      comprueba "el horno tiene la semilla"
        (Eio.Path.is_file Eio.Path.(horno / Forja.Tarea.to_string tarea / "SEMILLA.md")
        && Eio.Path.is_file Eio.Path.(horno / Forja.Tarea.to_string tarea / "nucleacion.md"));
      let antes = !llamadas in
      comprueba "streaming pasa sin tocar"
        (match pedir cliente (mensaje ~extra:{|"stream":true,|} "x") with
        | 200, "paso", _ -> true
        | _ -> false);
      comprueba "el paso llega al LLM" (!llamadas = antes + 1));
  (* Fase mixta: el cristal nucleado entra en la vitrina. *)
  let vitrina = Forja.Vitrina.(vacia |> con tarea `Mixta mayus) in
  con_forja (proxy vitrina cantera) (fun () ->
      let antes = !llamadas in
      comprueba "responde el cristal" (pedir cliente (mensaje "cuatro") = (200, "cristal", Some "CUATRO"));
      comprueba "el cristal no llama al LLM" (!llamadas = antes);
      comprueba "el defecto cae al LLM" (pedir cliente (mensaje "a1") = (200, "defecto", Some "A1"));
      comprueba "el defecto llama al LLM" (!llamadas = antes + 1);
      comprueba "el defecto queda en la cantera"
        (List.exists
           (fun (m : Forja.Cantera.muestra) -> m.defecto = Some "dígitos")
           (cantera.muestras tarea)));
  (* Fase cristalina: el defecto es un error visible. *)
  let vitrina = Forja.Vitrina.(vacia |> con tarea `Cristalina mayus) in
  con_forja (proxy vitrina cantera) (fun () ->
      let antes = !llamadas in
      comprueba "defecto cristalino es 422"
        (match pedir cliente (mensaje "b2") with 422, "defecto", None -> true | _ -> false);
      comprueba "sin LLM" (!llamadas = antes));
  (* Herramienta forzada: la forma de las pipelines con salida estructurada. *)
  let herramienta t =
    Printf.sprintf
      {|{"model":"m","max_tokens":10,"system":"Extrae en mayúsculas.","tools":[{"name":"mayus","input_schema":{"type":"object"}}],"tool_choice":{"type":"tool","name":"mayus"},"messages":[{"role":"user","content":%S}]}|}
      t
  in
  let forma = Forja_http.Anthropic.Herramienta "mayus" in
  let json t = Printf.sprintf {|{"mayus":"%s"}|} t in
  let cantera = Forja.Cantera.en_memoria () in
  maduras := [];
  con_forja (proxy Forja.Vitrina.vacia cantera) (fun () ->
      let r = List.map (fun t -> pedir cliente ~forma (herramienta t)) [ "uno"; "dos"; "tres" ] in
      comprueba "herramienta líquida: sale el JSON del LLM"
        (List.map (fun (c, f, _) -> (c, f)) r = List.init 3 (fun _ -> (200, "liquido"))
        && List.map (fun (_, _, s) -> s) r = [ Some (json "UNO"); Some (json "DOS"); Some (json "TRES") ]);
      comprueba "la tarea de herramienta madura" (List.length !maduras = 1));
  let tarea_h = List.hd !maduras in
  let cristal_h =
    Cristal.cristal "mayus-h" (fun s ->
        if s = "roto" then Ok "esto no es json"
        else if String.exists (function '0' .. '9' -> true | _ -> false) s then Error "dígitos"
        else Ok (json (String.uppercase_ascii s)))
  in
  con_forja (proxy Forja.Vitrina.(vacia |> con tarea_h `Mixta cristal_h) cantera) (fun () ->
      let antes = !llamadas in
      comprueba "el cristal responde tool_use"
        (pedir cliente ~forma (herramienta "cuatro") = (200, "cristal", Some (json "CUATRO")));
      comprueba "sin LLM" (!llamadas = antes);
      comprueba "cristal que no da JSON: defecto, responde el LLM"
        (pedir cliente ~forma (herramienta "roto") = (200, "defecto", Some (json "ROTO"))));
  (* Chat Completions con json_schema: la forma de buzon-kt sobre llama-server. *)
  let completions ?(extra = "") t =
    Printf.sprintf
      {|{"model":"gemma","temperature":0,%s"messages":[{"role":"system","content":"Extrae en mayúsculas."},{"role":"user","content":%S}],"response_format":{"type":"json_schema","json_schema":{"name":"mayus","strict":true,"schema":{"type":"object"}}}}|}
      extra t
  in
  let cantera = Forja.Cantera.en_memoria () in
  maduras := [];
  con_forja (proxy Forja.Vitrina.vacia cantera) (fun () ->
      let r = List.map (fun t -> pedir_openai cliente (completions t)) [ "uno"; "dos"; "tres" ] in
      comprueba "openai líquido: sale el objeto del LLM"
        (r = [ (200, "liquido", Some (json "UNO")); (200, "liquido", Some (json "DOS")); (200, "liquido", Some (json "TRES")) ]);
      comprueba "openai: una contrastada, 4 llamadas" (!llamadas_openai = 4);
      comprueba "la tarea de openai madura" (List.length !maduras = 1);
      comprueba "openai: otra tarea que la de Anthropic con el mismo system"
        (List.hd !maduras <> tarea_h);
      let antes = !llamadas_openai in
      comprueba "openai: streaming pasa"
        (match pedir_openai cliente (completions ~extra:{|"stream":true,|} "x") with
        | 200, "paso", _ -> true
        | _ -> false);
      comprueba "openai: el paso llega al LLM de openai" (!llamadas_openai = antes + 1));
  let tarea_o = List.hd !maduras in
  con_forja (proxy Forja.Vitrina.(vacia |> con tarea_o `Mixta cristal_h) cantera) (fun () ->
      let antes = !llamadas_openai in
      comprueba "openai: responde el cristal"
        (pedir_openai cliente (completions "cuatro") = (200, "cristal", Some (json "CUATRO")));
      comprueba "openai: sin LLM" (!llamadas_openai = antes);
      comprueba "openai: el defecto cae al LLM"
        (pedir_openai cliente (completions "a1") = (200, "defecto", Some (json "A1"))));
  con_forja (proxy ~openai:false Forja.Vitrina.vacia cantera) (fun () ->
      let antes = !llamadas_openai in
      comprueba "sin upstream openai: pasa sin tocar"
        (match pedir_openai cliente (completions "uno") with _, "paso", _ -> true | _ -> false);
      comprueba "sin upstream openai: va al upstream de siempre" (!llamadas_openai = antes + 1));
  (* Cristal parcial: da "a" y el LLM pone "b", pidiéndole solo "b". *)
  let dos t =
    Printf.sprintf
      {|{"model":"gemma","messages":[{"role":"system","content":"Dos campos."},{"role":"user","content":%S}],"response_format":{"type":"json_schema","json_schema":{"name":"dos","strict":true,"schema":{"type":"object","properties":{"a":{"type":"string"},"b":{"type":"string"}},"required":["a","b"],"additionalProperties":false}}}}|}
      t
  in
  let ab t = Printf.sprintf {|{"a":"a:%s","b":"b:%s"}|} t t in
  let solo_a =
    Cristal.cristal "solo-a" (fun s ->
        if s = "todo" then Ok (ab "TODO")
        else Ok (Printf.sprintf {|{"a":"a:%s"}|} (String.uppercase_ascii s)))
  in
  let cantera = Forja.Cantera.en_memoria () in
  maduras := [];
  con_forja (proxy Forja.Vitrina.vacia cantera) (fun () ->
      ignore (List.map (fun t -> pedir_openai cliente (dos t)) [ "uno"; "dos"; "tres" ]));
  let tarea_d = List.hd !maduras in
  comprueba "dos campos: por campo en el informe"
    ((Forja.informe (Forja.crear ~politica ~vitrina:Forja.Vitrina.vacia ~cantera ()) tarea_d).campos
    = [ ("a", 1); ("b", 1) ]);
  con_forja (proxy Forja.Vitrina.(vacia |> con tarea_d `Mixta solo_a) cantera) (fun () ->
      let antes = !llamadas_openai in
      comprueba "parcial: el objeto entero, con fuente parcial"
        (pedir_openai cliente (dos "cuatro") = (200, "parcial", Some (ab "CUATRO")));
      comprueba "parcial: una llamada al LLM" (!llamadas_openai = antes + 1);
      comprueba "parcial: al LLM solo se le pide b" (!pedidos_openai = [ "b" ]);
      comprueba "parcial: queda en la cantera, con qué faltaba"
        (List.exists
           (fun (m : Forja.Cantera.muestra) ->
             m.defecto = Some "parcial: faltan b" && m.salida = Some (ab "CUATRO"))
           (cantera.muestras tarea_d));
      comprueba "con todos los campos, responde el cristal solo"
        (pedir_openai cliente (dos "todo") = (200, "cristal", Some (ab "TODO")));
      comprueba "y sin LLM" (!llamadas_openai = antes + 1));
  con_forja (proxy Forja.Vitrina.(vacia |> con tarea_d `Cristalina solo_a) cantera) (fun () ->
      let antes = !llamadas_openai in
      comprueba "parcial cristalino es 422"
        (match pedir_openai cliente (dos "cinco") with 422, "defecto", None -> true | _ -> false);
      comprueba "parcial cristalino, sin LLM" (!llamadas_openai = antes));
  if !fallos > 0 then exit 1
