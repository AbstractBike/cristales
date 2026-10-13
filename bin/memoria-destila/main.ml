(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* memoria-destila: de los mensajes de L0 a los átomos de L1
   (doc/memoria.md). Por cada sesión inactiva con mensajes posteriores a su
   cursor, lotes de 10 mensajes nuevos y 5 de fondo: memoria-atomos los
   destila, memoria-dedup juzga los parecidos y se escribe en memoria_l1.
   Cada llamada es un encargo de la agencia (y pasa por la forja).

   memoria-destila [--sesion ID] [--seco] [--limite N] [--inactiva MIN]
                   [--desde AAAA-MM-DD|Nd] [--greptime URL] [--db BASE]
                   [--escalera M1,M2…]

   --sesion ID     solo esa sesión, esté o no inactiva o reciente
   --seco          llama a los modelos pero no escribe ni átomos ni cursor
   --limite N      como mucho N lotes en esta pasada
   --inactiva MIN  minutos sin mensajes para dar una sesión por inactiva (10)
   --desde F       solo sesiones con actividad desde F: una fecha o hace N
                   días (30d); el backfill se limita a lo reciente
   --escalera L    la de memoria-atomos y memoria-dedup, del más barato al
                   más capaz (MEMORIA_ESCALERA; por defecto haiku, sonnet,
                   opus: gemma, con 8192 tokens de contexto, no cabe)

   Los flags mandan sobre el entorno:
   MEMORIA_GREPTIME     raíz HTTP de GreptimeDB (o AGENCIA_GREPTIME)
   MEMORIA_GREPTIME_DB  base de la memoria (memoria)
   AGENCIA_GREPTIME_DB  base del archivo de la agencia (agencia)
   AGENCIA_ANTHROPIC, AGENCIA_OPENAI y las claves, como agencia-mcp.

   Sale con 1 si GreptimeDB falla, o si hubo fallos (lotes ilegibles,
   errores) y ninguna sesión avanzó. *)

let entorno k d = Option.value ~default:d (Sys.getenv_opt k)
let var k = match Sys.getenv_opt k with Some v when String.trim v <> "" -> Some (String.trim v) | _ -> None
let bearer v = "Bearer " ^ v

let uso () =
  prerr_endline
    "uso: memoria-destila [--sesion ID] [--seco] [--limite N] [--inactiva MIN] [--desde AAAA-MM-DD|Nd] [--greptime URL] \
     [--db BASE] [--escalera M1,M2…]";
  exit 2

type opciones = {
  sesion : string option;
  seco : bool;
  limite : int option;
  inactiva : int;
  desde : string;
  greptime : string option;
  db : string option;
  escalera : string option;
}

let opciones () =
  let rec leer o = function
    | [] -> o
    | "--sesion" :: s :: r -> leer { o with sesion = Some s } r
    | "--seco" :: r -> leer { o with seco = true } r
    | "--limite" :: n :: r -> ( match int_of_string_opt n with Some n when n > 0 -> leer { o with limite = Some n } r | _ -> uso ())
    | "--inactiva" :: n :: r -> ( match int_of_string_opt n with Some n when n >= 0 -> leer { o with inactiva = n } r | _ -> uso ())
    | "--desde" :: d :: r -> leer { o with desde = d } r
    | "--greptime" :: u :: r -> leer { o with greptime = Some u } r
    | "--db" :: d :: r -> leer { o with db = Some d } r
    | "--escalera" :: e :: r -> leer { o with escalera = Some e } r
    | _ -> uso ()
  in
  leer
    { sesion = None; seco = false; limite = None; inactiva = 10; desde = "30d"; greptime = None; db = None; escalera = None }
    (List.tl (Array.to_list Sys.argv))

(* «30d» (hace 30 días) o «2026-09-15», en ms. *)
let desde_ms ~ahora d =
  let n = String.length d in
  if n > 1 && d.[n - 1] = 'd' then
    Option.map (fun dias -> ahora - (dias * 86_400_000)) (int_of_string_opt (String.sub d 0 (n - 1)))
  else Memoria_l1.Atomo.ms_de_fecha d

let escalera texto =
  String.split_on_char ',' texto
  |> List.map (fun m ->
         match Agencia.Modelo.de_texto (String.trim m) with Ok m -> m | Error e -> failwith ("escalera: " ^ e))

let o_falla = function Ok v -> v | Error e -> prerr_endline ("memoria-destila: " ^ e); exit 1

let corto s = if String.length s <= 8 then s else String.sub s 0 8

let contar (i : Memoria_l1.Destila.informe) =
  let open Memoria_l1 in
  Printf.printf "\n== sesión %s · lote hasta %s UTC · %d nuevos + %d de fondo\n" (corto i.sesion) (Atomo.hora i.lote.hasta)
    (List.length i.lote.nuevos) (List.length i.lote.fondo);
  List.iter
    (fun (e : Agencia.Encargo.t) ->
      Printf.printf "   encargo %s · %s · %s · %s · %d ms · %d+%d tokens%s\n" e.id (Forja.Tarea.to_string e.agente) e.modelo e.fuente
        e.ms e.tokens_entrada e.tokens_salida
        (match e.salida with Ok _ -> "" | Error err -> " · ERROR " ^ err))
    i.encargos;
  if i.escenas <> [] then Printf.printf "   escenas: %s\n" (String.concat " | " i.escenas);
  List.iter
    (fun ((c : Dedup.caso), (d : Dedup.decision)) ->
      Printf.printf "   %s [%s %d] %s\n" (Dedup.accion_a_texto d.accion) (Atomo.tipo_a_texto c.nuevo.tipo) c.nuevo.prioridad
        c.nuevo.contenido;
      if d.objetivos <> [] then Printf.printf "      → %s\n" (String.concat ", " d.objetivos))
    i.decisiones;
  List.iter (fun (c, m) -> Printf.printf "   descartado (%s): %s\n" m c) i.descartados;
  List.iter
    (fun (a : Atomo.t) ->
      Printf.printf "   fila %s v%d%s [%s %d] %s\n" a.id a.version (if a.vigente then "" else " (absorbido)")
        (Atomo.tipo_a_texto a.tipo) a.prioridad a.contenido)
    i.filas;
  flush stdout

let () =
  let o = opciones () in
  Mirage_crypto_rng_unix.use_default ();
  Eio_main.run @@ fun env ->
  let clock = Eio.Stdenv.clock env in
  let ahora () = int_of_float (Eio.Time.now clock *. 1000.) in
  let desde = match desde_ms ~ahora:(ahora ()) o.desde with Some d -> d | None -> uso () in
  let cliente = Forja_http.Proxy.cliente (Eio.Stdenv.net env) in
  let post = Forja_http.Proxy.post cliente in
  let url =
    match (o.greptime, var "MEMORIA_GREPTIME", var "AGENCIA_GREPTIME") with
    | Some u, _, _ | None, Some u, _ | None, None, Some u -> Uri.of_string u
    | None, None, None -> prerr_endline "memoria-destila: falta --greptime o MEMORIA_GREPTIME"; exit 2
  in
  let db = match o.db with Some d -> d | None -> entorno "MEMORIA_GREPTIME_DB" "memoria" in
  let almacen = Memoria_l1.Almacen.crear (Forja_http.Greptime.conectar ~post ~url ~db) in
  let db_agencia = entorno "AGENCIA_GREPTIME_DB" "agencia" in
  let archivo =
    Agencia_http.Medidas.con_medidas
      (Agencia_http.Medidas.a_greptime (Forja_http.Greptime.conectar ~post ~url ~db:db_agencia))
      (Agencia_http.Archivo_greptime.crear ~post ~url ~db:db_agencia ())
  in
  let destinos =
    { Agencia_http.Llm.anthropic = Uri.of_string (entorno "AGENCIA_ANTHROPIC" "http://[b1c1:a2::1]:8090");
      openai = Some (Uri.of_string (entorno "AGENCIA_OPENAI" "http://[b1c1:a2::1]:8090"));
      cabeceras_anthropic =
        List.filter_map Fun.id
          [ Option.map (fun v -> ("x-api-key", v)) (var "ANTHROPIC_API_KEY");
            Option.map (fun v -> ("authorization", bearer v)) (var "ANTHROPIC_AUTH_TOKEN") ];
      cabeceras_openai = Option.to_list (Option.map (fun v -> ("authorization", bearer v)) (var "OPENAI_API_KEY")) }
  in
  let azar = Random.State.make_self_init () in
  let escalera =
    escalera
      (match o.escalera with
      | Some e -> e
      | None -> entorno "MEMORIA_ESCALERA" "claude-haiku-5-5,claude-sonnet-5-5,claude-opus-5-5")
  in
  let ef_agencia =
    { Agencia_mcp.archivo;
      llamar = Agencia_http.Llm.llamar clock cliente destinos;
      id = (fun () -> String.init 16 (fun _ -> "0123456789abcdef".[Random.State.int azar 16]));
      escalera;
      politica = Agencia.Politica.por_defecto }
  in
  let agentes =
    { Memoria_l1.Destila.atomos = o_falla (Memoria_l1.Agentes.atomos ~escalera);
      dedup = o_falla (Memoria_l1.Agentes.dedup ~escalera) }
  in
  List.iter
    (fun (a : Agencia.Agente.t) ->
      if Memoria_l1.Agentes.asegurar archivo a then
        Printf.eprintf "memoria-destila: agente %s (versión %s) guardado en la agencia\n%!" (Forja.Tarea.to_string a.nombre)
          (Agencia.Agente.version a))
    [ agentes.atomos; agentes.dedup ];
  let avisar m = prerr_endline ("memoria-destila: " ^ m) in
  let ef =
    { Memoria_l1.Destila.encargar = (fun a ?modelo entrada -> Agencia_mcp.encargar ef_agencia a ?modelo entrada);
      juzgar_mal = (fun e nota -> archivo.juzgar e.agente e.id Agencia.Mal nota);
      candidatos = Memoria_l1.Almacen.candidatos almacen;
      escrito = (fun ~sesion ~hasta -> if o.seco then Ok false else Memoria_l1.Almacen.escrito almacen ~sesion ~hasta);
      escribir = (fun ~hasta filas -> if o.seco then Ok () else Memoria_l1.Almacen.escribir almacen ~escrito:(ahora ()) ~hasta filas);
      guardar_cursor =
        (fun ~sesion c -> if o.seco then Ok () else Memoria_l1.Almacen.guardar_cursor almacen ~ts:(ahora ()) ~sesion c);
      avisar }
  in
  (* Una consulta para todos los cursores; si falla, no se sigue: sin
     cursor se reprocesaría todo. *)
  let cursores = o_falla (Memoria_l1.Almacen.cursores almacen) in
  let sesiones =
    match o.sesion with
    | Some s -> [ s ]
    | None -> List.map fst (o_falla (Memoria_l1.Almacen.sesiones almacen ~cursores ~inactiva_min:o.inactiva ~desde))
  in
  Printf.eprintf "memoria-destila: %d sesiones por destilar desde %s%s\n%!" (List.length sesiones)
    (Memoria_l1.Atomo.fecha desde)
    (if o.seco then " (en seco)" else "");
  let lotes = ref 0 and avanzaron = ref 0 and ilegibles = ref 0 and saltados = ref 0 in
  let rec recorrer = function
    | [] -> ()
    | sesion :: resto ->
        let limite = Option.map (fun l -> l - !lotes) o.limite in
        if match limite with Some l -> l > 0 | None -> true then (
          let cursor = List.assoc_opt sesion cursores in
          let mensajes =
            o_falla
              (Memoria_l1.Almacen.mensajes almacen ~sesion
                 ~cursor:(Option.map (fun (c : Memoria_l1.Lote.cursor) -> c.hasta) cursor)
                 ~fondo:50)
          in
          let r = Memoria_l1.Destila.sesion ef agentes ?limite ~sesion ~cursor mensajes in
          List.iter contar r.informes;
          lotes := !lotes + List.length r.informes + r.recuperados + r.saltados;
          if Memoria_l1.Destila.avanzo r then incr avanzaron;
          ilegibles := !ilegibles + r.ilegibles;
          saltados := !saltados + r.saltados;
          if r.ilegibles > 0 then avisar (Printf.sprintf "sesión %s: lote ilegible, se reintentará en la próxima pasada" sesion);
          match r.error with
          | Some e ->
              avisar (Printf.sprintf "sesión %s: %s; se para la pasada" sesion e);
              Printf.eprintf "memoria-destila: %d lotes antes del error\n%!" !lotes;
              exit 1
          | None -> recorrer resto)
  in
  recorrer sesiones;
  Printf.eprintf "memoria-destila: %d lotes en %d sesiones; %d ilegibles, %d saltados\n%!" !lotes !avanzaron !ilegibles
    !saltados;
  if !ilegibles > 0 && !avanzaron = 0 then exit 1
