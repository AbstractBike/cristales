(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* forja-prueba: batería contra una forja desplegada, con la API real de
   Anthropic detrás. La clave sale de ANTHROPIC_API_KEY y va tal cual en
   x-api-key: la forja no la guarda.

     ANTHROPIC_API_KEY=… forja-prueba [URL de la forja]   (http://[b1c1:a2::1]:8090)

   Cada ejecución usa tareas nuevas (prueba-…-<marca>), así que su madurez
   empieza de cero. Coste: ~50 llamadas cortas a haiku. *)

let modelo = "claude-haiku-5-5"
let fallos = ref 0

let comprueba nombre cond detalle =
  Printf.printf "%s %s%s\n%!" (if cond then "  ok " else "FALLA") nombre
    (if cond then "" else "  — " ^ detalle);
  if not cond then incr fallos

type r = { estado : int; fuente : string; tarea : string; texto : string option; cuerpo : string }

let pedir cliente ~base ~clave ?tarea ?(meth = `POST) ?(ruta = "/v1/messages") cuerpo =
  Eio.Switch.run @@ fun sw ->
  let cabeceras =
    [ ("content-type", "application/json"); ("anthropic-version", "2023-06-01");
      ("x-api-key", clave); ("content-length", string_of_int (String.length cuerpo)) ]
    @ match tarea with Some t -> [ ("x-forja-tarea", t) ] | None -> []
  in
  let resp, b =
    Cohttp_eio.Client.call cliente ~sw ~headers:(Http.Header.of_list cabeceras)
      ~body:(Cohttp_eio.Body.of_string cuerpo) meth (Uri.with_path base ruta)
  in
  let cuerpo = Eio.Buf_read.(parse_exn take_all) b ~max_size:max_int in
  let h k = Option.value ~default:"" (Http.Header.get (Http.Response.headers resp) k) in
  { estado = Http.Status.to_int (Http.Response.status resp);
    fuente = h "x-forja-fuente"; tarea = h "x-forja-tarea";
    texto = (try Forja_http.Anthropic.texto (Yojson.Safe.from_string cuerpo) with _ -> None);
    cuerpo }

let mensaje ?(modelo = modelo) ?(system = "") ?(extra = []) ?(max_tokens = 20) turnos =
  Yojson.Safe.to_string
    (`Assoc
      ([ ("model", `String modelo); ("max_tokens", `Int max_tokens) ]
      @ (if system = "" then [] else [ ("system", `String system) ])
      @ extra
      @ [ ("messages",
            `List
              (List.mapi
                 (fun i t ->
                   `Assoc [ ("role", `String (if i mod 2 = 0 then "user" else "assistant"));
                            ("content", `String t) ])
                 turnos)) ]))

let resenas =
  [ "La comida llegó fría y tardaron una hora."; "Un sitio genial, volveremos.";
    "Abren a las nueve."; "El camarero fue muy amable y todo estaba buenísimo.";
    "Nunca más, el peor servicio que he visto."; "Tienen terraza.";
    "Me encantó el postre."; "La cuenta tenía un error y no lo quisieron corregir.";
    "Está en la calle Mayor."; "Precio razonable y raciones generosas.";
    "Ruido insoportable, no se podía hablar."; "Aceptan tarjeta.";
    "Repetiría sin dudarlo."; "La carne estaba cruda por dentro.";
    "Cierra los lunes."; "Excelente relación calidad-precio.";
    "Esperamos 40 minutos de pie para sentarnos."; "Hay menú del día.";
    "Personal atento y local muy limpio."; "Los baños estaban sucios.";
    "Tiene aparcamiento cerca."; "Una experiencia maravillosa." ]

let () =
  let clave =
    match Sys.getenv_opt "ANTHROPIC_API_KEY" with
    | Some k when k <> "" -> k
    | _ -> prerr_endline "forja-prueba: falta ANTHROPIC_API_KEY"; exit 2
  in
  let base = Uri.of_string (if Array.length Sys.argv > 1 then Sys.argv.(1) else "http://[b1c1:a2::1]:8090") in
  let marca = Printf.sprintf "%.0f" (Unix.time ()) in
  Mirage_crypto_rng_unix.use_default ();
  Eio_main.run @@ fun env ->
  let cliente = Forja_http.Proxy.cliente (Eio.Stdenv.net env) in
  let pedir = pedir cliente ~base ~clave in
  let resumen r = Printf.sprintf "%d %s %s" r.estado r.fuente (String.sub r.cuerpo 0 (min 200 (String.length r.cuerpo))) in

  print_endline "\n# Paso: lo que no es una tarea llega intacto a Anthropic";
  let r = pedir (mensaje ~system:"Responde con una palabra." [ "hola"; "hola"; "¿qué tal?" ]) in
  comprueba "varios turnos → paso, 200" (r.estado = 200 && r.fuente = "paso") (resumen r);
  let r = pedir (mensaje ~extra:[ ("stream", `Bool true) ] ~system:"Responde con una palabra." [ "hola" ]) in
  comprueba "streaming → paso, eventos SSE"
    (r.estado = 200 && r.fuente = "paso"
    && String.length r.cuerpo > 6 && String.sub r.cuerpo 0 6 = "event:") (resumen r);
  let r = pedir ~meth:`GET ~ruta:"/v1/models" "" in
  comprueba "GET /v1/models → paso, 200" (r.estado = 200 && r.fuente = "paso") (resumen r);
  let r = pedir ~tarea:"Nombre No Valido" (mensaje [ "hola" ]) in
  comprueba "tarea con nombre no válido → paso" (r.fuente = "paso") (resumen r);

  print_endline "\n# Cristal: fecha-es, en la vitrina de a2";
  let r = pedir ~tarea:"fecha-es" (mensaje [ "3 de marzo de 2024" ]) in
  comprueba "responde el cristal sin tokens" (r.fuente = "cristal" && r.texto = Some "2024-03-03") (resumen r);
  let r = pedir ~tarea:"fecha-es" (mensaje ~max_tokens:60 ~system:"Convierte la fecha a ISO 8601 (AAAA-MM-DD). Responde solo la fecha." [ "el próximo martes" ]) in
  comprueba "defecto del cristal → responde Claude" (r.estado = 200 && r.fuente = "defecto" && r.texto <> None) (resumen r);

  print_endline "\n# Errores de Anthropic: pasan y no se aprenden";
  let r = pedir (mensaje ~modelo:"modelo-que-no-existe" ~system:"Responde con una palabra." [ "hola" ]) in
  comprueba "modelo inexistente → el 404 de Anthropic" ((r.estado = 404 || r.estado = 400) && r.fuente = "liquido") (resumen r);
  let r = pedir ~tarea:("prueba-corta-" ^ marca) (mensaje ~max_tokens:1 ~system:"Escribe un poema largo." [ "sobre el mar" ]) in
  comprueba "max_tokens → 200 líquido (no se guarda: no es end_turn)" (r.estado = 200 && r.fuente = "liquido") (resumen r);

  let tarea_estable = "prueba-sentimiento-" ^ marca in
  Printf.printf "\n# Tarea estable %s: %d reseñas, temperatura 0\n" tarea_estable (List.length resenas);
  let sistema = "Clasifica el sentimiento de la reseña. Responde solo con una palabra en minúsculas: positivo, negativo o neutro." in
  let rs =
    List.map
      (fun t ->
        let r = pedir ~tarea:tarea_estable (mensaje ~system:sistema ~extra:[ ("temperature", `Float 0.) ] [ t ]) in
        Printf.printf "    %-55s → %s\n%!" t (Option.value ~default:("[" ^ resumen r ^ "]") r.texto);
        r)
      resenas
  in
  comprueba "todas líquidas y con respuesta"
    (List.for_all (fun r -> r.estado = 200 && r.fuente = "liquido" && r.texto <> None) rs) "";
  comprueba "la respuesta está en el conjunto cerrado"
    (List.for_all (fun r -> List.mem (Option.map String.trim r.texto) [ Some "positivo"; Some "negativo"; Some "neutro" ]) rs) "";

  let tarea_inestable = "prueba-inventa-" ^ marca in
  Printf.printf "\n# Tarea inestable %s: 22 peticiones, temperatura 1\n" tarea_inestable;
  let rs =
    List.init 22 (fun i ->
        pedir ~tarea:tarea_inestable
          (mensaje ~system:"Inventa un nombre de pila que no exista. Responde solo el nombre."
             ~extra:[ ("temperature", `Float 1.) ] [ Printf.sprintf "Nombre número %d" (i + 1) ]))
  in
  comprueba "todas líquidas" (List.for_all (fun r -> r.estado = 200 && r.fuente = "liquido") rs) "";

  Printf.printf "\nTareas de esta ejecución: %s (debería madurar), %s (no debería)\n" tarea_estable tarea_inestable;
  Printf.printf "%s\n" (if !fallos = 0 then "Todo bien." else Printf.sprintf "%d fallos." !fallos);
  if !fallos > 0 then exit 1
