(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red de la destilación L1: JSON de los modelos, extracción, lotes,
   candidatos, juez, plan y la orquestación con efectos falsos. Las
   respuestas de modelo son grabadas (o con la forma de las grabadas). *)

open Memoria_l1

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let t0 = 1_791_885_600_000 (* 2026-10-13 10:00 UTC *)
let min = 60_000

(* {1 Atomo} *)

let () =
  comprueba "fecha de 0" (Atomo.fecha 0 = "1970-01-01");
  comprueba "fecha de un bisiesto" (Atomo.fecha 951_782_400_000 = "2000-02-29");
  comprueba "hora" (Atomo.hora (951_782_400_000 + (13 * 3_600_000) + (5 * min)) = "2000-02-29 13:05");
  comprueba "tipo método con tilde" (Atomo.tipo_de_texto "Método" = Some Atomo.Metodo);
  comprueba "regla absoluta" (Atomo.conservar Atomo.Regla (-1));
  comprueba "hecho -1 no" (not (Atomo.conservar Atomo.Hecho (-1)));
  comprueba "persona 50" (Atomo.conservar Atomo.Persona 50 && not (Atomo.conservar Atomo.Persona 49))

let msg ?(rol = "user") ?(sesion = "s1") i texto =
  { Atomo.sesion; uuid = Printf.sprintf "u%02d" i; ts = t0 + (i * min); proyecto = "/logical-node/nixos-config"; rol; texto }

let () = comprueba "fecha de t0" (Atomo.fecha t0 = "2026-10-13")

(* {1 Json_llm} *)

let () =
  let ok s = match Json_llm.extraer s with Ok _ -> true | Error _ -> false in
  comprueba "json con valla" (ok "```json\n{\"a\":1}\n```");
  comprueba "json con texto alrededor" (ok "Aquí va:\n[{\"a\":\"}\"}]\nEso es todo.");
  comprueba "json tras think" (ok "<think>uso [m1] y {x}</think>{\"escenas\":[]}");
  comprueba "json roto" (not (ok "{\"a\": [1, 2}"));
  comprueba "sin json" (not (ok "no hay nada"))

(* {1 Extraccion} *)

let nuevos =
  [ msg 1 "nunca uses --impure con colmena, si falla haz commit";
    msg ~rol:"assistant" 2 "Entendido. [herramienta Bash: Build a2]\nEl build de a2 pasa.";
    msg 3 "GreptimeDB ya está en c3" ]

(* Grabada (con la forma de la de claude-sonnet-5-5 en la prueba real). *)
let respuesta_atomos =
  {|{"escenas":[{"escena":"Despliegue de a2 con colmena","mensajes":["m1","m2","m3"],"atomos":[
  {"contenido":"Nunca ejecutar colmena con --impure: si la evaluación falla por árbol sucio, se hace commit.","tipo":"regla","prioridad":-1,"origen":["m1"]},
  {"contenido":"GreptimeDB corre en c3.","tipo":"hecho","prioridad":75,"origen":["m3","f2"]},
  {"contenido":"Esto viene del fondo.","tipo":"hecho","prioridad":90,"origen":["f1"]},
  {"contenido":"El usuario saluda.","tipo":"persona","prioridad":20,"origen":["m1"]},
  {"contenido":"Algo raro.","tipo":"tarea","prioridad":90,"origen":["m2"]}]}]}|}

let () =
  let e = Extraccion.entrada ~escena_previa:None ~fondo:[ msg 0 "hola" ] ~nuevos in
  let contiene s sub =
    let n = String.length s and m = String.length sub in
    let rec ir i = i + m <= n && (String.sub s i m = sub || ir (i + 1)) in
    ir 0
  in
  comprueba "entrada: fondo etiquetado" (contiene e "[f1] [usuario] [2026-10-13 10:00 UTC]");
  comprueba "entrada: nuevos etiquetados" (contiene e "[m2] [asistente] [2026-10-13 10:02 UTC]");
  comprueba "entrada: escena anterior" (contiene e "【escena anterior】 ninguna");
  comprueba "recortar respeta UTF-8"
    (let s = Extraccion.recortar 10 (String.concat "" (List.init 20 (fun _ -> "ñ"))) in
     String.length s < 40 && String.is_valid_utf_8 s);
  match Extraccion.leer ~nuevos respuesta_atomos with
  | Error e -> comprueba ("extracción legible: " ^ e) false
  | Ok r ->
      comprueba "extracción: dos átomos válidos" (List.length r.atomos = 2);
      comprueba "extracción: tres descartados" (List.length r.descartados = 3);
      comprueba "extracción: escena" (r.ultima_escena = Some "Despliegue de a2 con colmena");
      let regla = List.hd r.atomos in
      comprueba "extracción: regla absoluta" (regla.tipo = Atomo.Regla && regla.prioridad = -1);
      comprueba "extracción: origen sesion/uuid" (regla.origen = [ "s1/u01" ]);
      comprueba "extracción: fechas del ts" (regla.fechas = [ "2026-10-13" ]);
      let hecho = List.nth r.atomos 1 in
      comprueba "extracción: f2 no cuenta como origen" (hecho.origen = [ "s1/u03" ])

let () =
  comprueba "extracción: formato de Tencent (array)"
    (match Extraccion.leer ~nuevos {|[{"escena":"x","atomos":[{"contenido":"c","tipo":"metodo","prioridad":70,"origen":["m2"]}]}]|} with
    | Ok r -> List.length r.atomos = 1
    | Error _ -> false);
  comprueba "extracción: basura" (Result.is_error (Extraccion.leer ~nuevos "Lo siento, no puedo."));
  comprueba "extracción: vacía vale"
    (match Extraccion.leer ~nuevos {|{"escenas":[{"escena":"x","mensajes":["m1"],"atomos":[]}]}|} with
    | Ok r -> r.atomos = [] && r.escenas = [ "x" ]
    | Error _ -> false)

(* {1 Lote} *)

let () =
  let herr = msg ~rol:"assistant" 50 "[herramienta Bash: ls]\n[herramienta Read: x]" in
  comprueba "útil: solo herramientas no" (not (Lote.util herr));
  comprueba "útil: vacío no" (not (Lote.util (msg 51 "  ")));
  comprueba "útil: texto sí" (Lote.util (msg 52 "ok, sigue"));
  let sesion = List.init 25 (fun i -> msg i (Printf.sprintf "mensaje %d" i)) in
  (match Lote.siguiente ~cursor:None sesion with
  | Lote.Lote l ->
      comprueba "lote: 10 nuevos" (List.length l.nuevos = 10);
      comprueba "lote: sin fondo al principio" (l.fondo = []);
      comprueba "lote: hasta el décimo" (l.hasta = t0 + (9 * min))
  | _ -> comprueba "lote: primero" false);
  (match Lote.siguiente ~cursor:(Some (t0 + (9 * min))) sesion with
  | Lote.Lote l ->
      comprueba "lote 2: empieza en el 10" ((List.hd l.nuevos).uuid = "u10");
      comprueba "lote 2: 5 de fondo, los últimos" (List.map (fun (m : Atomo.mensaje) -> m.uuid) l.fondo = [ "u05"; "u06"; "u07"; "u08"; "u09" ])
  | _ -> comprueba "lote: segundo" false);
  (match Lote.siguiente ~cursor:(Some (t0 + (20 * min))) sesion with
  | Lote.Lote l -> comprueba "lote: cola de 4" (List.length l.nuevos = 4 && l.hasta = t0 + (24 * min))
  | _ -> comprueba "lote: cola" false);
  comprueba "lote: nada" (Lote.siguiente ~cursor:(Some (t0 + (24 * min))) sesion = Lote.Nada);
  comprueba "lote: solo herramientas avanza"
    (Lote.siguiente ~cursor:(Some (t0 + (24 * min))) (sesion @ [ herr ]) = Lote.Avanzar herr.ts);
  (* Tres con el mismo ts en el corte: van juntos. *)
  let mismo = List.init 3 (fun i -> { (msg 9 (Printf.sprintf "par %d" i)) with uuid = Printf.sprintf "v%d" i }) in
  match Lote.siguiente ~cursor:None (List.filteri (fun i _ -> i < 9) sesion @ mismo) with
  | Lote.Lote l -> comprueba "lote: no parte un ts" (List.length l.nuevos = 12)
  | _ -> comprueba "lote: mismo ts" false

(* {1 Dedup} *)

let atomo ?(version = 1) ?(vigente = true) ?(prioridad = 70) ?(tipo = Atomo.Hecho) id contenido =
  { Atomo.id; version; vigente; tipo; prioridad; escena = "e"; contenido; proyecto = "p"; origen = [ "s0/" ^ id ];
    fechas = [ "2026-09-01" ] }

let nuevo ?(tipo = Atomo.Hecho) ?(prioridad = 80) contenido =
  { Atomo.contenido; tipo; prioridad; escena = "nueva"; proyecto = "p"; origen = [ "s1/u01" ]; fechas = [ "2026-10-13" ] }

let () =
  let t = Dedup.terminos "GreptimeDB corre en c3 desde el 2026-10-13, con la base de la flota y k0s" in
  comprueba "términos: los distintivos primero" (List.hd t = "GreptimeDB");
  comprueba "términos: cifras cortas" (List.mem "c3" t && List.mem "k0s" t);
  comprueba "términos: sin vacías" (not (List.mem "desde" t));
  comprueba "términos: máximo" (List.length t <= 6);
  comprueba "consulta" (Dedup.consulta "GreptimeDB" = "GreptimeDB OR Greptimedb OR greptimedb");
  let r = Dedup.rrf [ [ "a"; "b"; "c" ]; [ "b"; "c" ]; [ "c" ] ] in
  comprueba "rrf: el que más aparece" (fst (List.hd r) = "c");
  comprueba "rrf: k=60" (abs_float (List.assoc "a" r -. (1. /. 61.)) < 1e-9);
  let v = Dedup.vigentes [ ("a-1", 2); ("a-2", 1) ] [ atomo "a-1" "viejo"; atomo ~version:2 "a-1" "nuevo"; atomo ~vigente:false "a-2" "x" ] in
  comprueba "vigentes: la última versión y vigente" (List.map (fun (a : Atomo.t) -> a.contenido) v = [ "nuevo" ]);
  let m = Dedup.mejores ~n:2 [ [ atomo "a-1" "x"; atomo "a-2" "y" ]; [ atomo "a-2" "y"; atomo "a-3" "z" ] ] in
  comprueba "mejores: fusión" (List.map (fun (a : Atomo.t) -> a.id) m = [ "a-2"; "a-1" ])

let casos =
  Dedup.casos
    [ (nuevo "GreptimeDB corre en c3.", [ atomo "a-111111111111" "GreptimeDB corre en c2." ]);
      (nuevo "El usuario prefiere timeouts cortos.", [ atomo "a-222222222222" "El usuario prefiere timeouts cortos." ]);
      ( nuevo ~tipo:Atomo.Metodo "Para migrar un PV, tar antes de borrar el PVC.",
        [ atomo ~prioridad:85 "a-333333333333" "Borrar el PVC borra el origen.";
          atomo ~tipo:Atomo.Episodio "a-444444444444" "El 2026-09-01 se perdió un volumen al borrar su PVC." ] );
      (nuevo "Algo nuevo del todo.", []) ]

(* Grabada (con la forma de la de claude-haiku-5-5 en la prueba real). *)
let respuesta_dedup =
  {|```json
[{"id":"n1","accion":"actualizar","objetivos":["a-111111111111"],"contenido":"Desde el 2026-10-13 GreptimeDB corre en c3 (antes en c2).","tipo":"hecho","prioridad":85,"fechas":["2026-09-01","2026-10-13"]},
 {"id":"n2","accion":"saltar","objetivos":["a-222222222222"]},
 {"id":"n3","accion":"fusionar","objetivos":["a-333333333333","a-444444444444","a-999999999999"],"contenido":"Para migrar un PV local-hostpath, tar del origen antes de borrar el PVC: borrarlo borra los datos (pasó el 2026-09-01).","tipo":"metodo","prioridad":80,"fechas":["2026-09-01","2026-10-13","ayer"]}]
```|}

let () =
  comprueba "juez: hace falta" (Dedup.hace_falta_juez casos);
  comprueba "juez: no hace falta sin candidatos" (not (Dedup.hace_falta_juez (Dedup.casos [ (nuevo "x", []) ])));
  match Dedup.leer casos respuesta_dedup with
  | Error e -> comprueba ("juez legible: " ^ e) false
  | Ok ds ->
      comprueba "juez: una por caso" (List.length ds = 4);
      let d n = List.find (fun (d : Dedup.decision) -> d.caso = n) ds in
      comprueba "juez: n4 sin decisión se guarda" ((d "n4").accion = Dedup.Guardar);
      comprueba "juez: objetivo ajeno fuera" ((d "n3").objetivos = [ "a-333333333333"; "a-444444444444" ]);
      comprueba "juez: fecha inválida fuera" (not (List.mem "ayer" (d "n3").fechas));
      let filas = Dedup.plan casos ds in
      comprueba "plan: 4 filas (act, fus, absorbido, nuevo)" (List.length filas = 4);
      let f id = List.find (fun (a : Atomo.t) -> a.id = id) filas in
      let act = f "a-111111111111" in
      comprueba "plan: actualizar sube versión" (act.version = 2 && act.vigente && act.prioridad = 85);
      comprueba "plan: actualizar une origen y fechas"
        (act.origen = [ "s0/a-111111111111"; "s1/u01" ] && act.fechas = [ "2026-09-01"; "2026-10-13" ]);
      let fus = f "a-333333333333" in
      comprueba "plan: fusionar no baja de la mayor" (fus.prioridad = 85 && fus.tipo = Atomo.Metodo);
      let abs = f "a-444444444444" in
      comprueba "plan: absorbido no vigente" (abs.version = 2 && not abs.vigente);
      comprueba "plan: el nuevo sin candidatos, versión 1"
        (List.exists (fun (a : Atomo.t) -> a.contenido = "Algo nuevo del todo." && a.version = 1) filas)

let () =
  comprueba "juez: basura es error" (Result.is_error (Dedup.leer casos "No sé."));
  comprueba "juez: objeto en vez de array es error" (Result.is_error (Dedup.leer casos {|{"id":"n1"}|}));
  (match Dedup.leer casos {|[{"id":"n1","accion":"fusionar","objetivos":["a-nada"]},{"id":"n2","accion":"borrar"}]|} with
  | Ok ds -> comprueba "juez: sin objetivos válidos y acción rara, guardar" (List.for_all (fun (d : Dedup.decision) -> d.accion = Dedup.Guardar) ds)
  | Error _ -> comprueba "juez: corregible" false);
  let todo = Dedup.plan casos (Dedup.guardar_todo casos) in
  comprueba "guardar todo: uno por nuevo" (List.length todo = 4 && List.for_all (fun (a : Atomo.t) -> a.version = 1) todo);
  (* Una regla absoluta fusionada sigue siéndolo. *)
  let c = Dedup.casos [ (nuevo ~tipo:Atomo.Regla ~prioridad:90 "Nunca --impure.", [ atomo ~tipo:Atomo.Regla ~prioridad:(-1) "a-5" "Nunca impure." ]) ] in
  let ds = [ { (List.hd (Dedup.guardar_todo c)) with accion = Dedup.Fusionar; objetivos = [ "a-5" ]; prioridad = Some 95 } ] in
  comprueba "plan: -1 se conserva" ((List.hd (Dedup.plan c ds)).prioridad = -1);
  (* Dos nuevos contra el mismo objetivo: el segundo parte del primero. *)
  let c = Dedup.casos [ (nuevo "A", [ atomo "a-6" "X" ]); (nuevo "B", [ atomo "a-6" "X" ]) ] in
  let ds = List.map (fun (d : Dedup.decision) -> { d with accion = Dedup.Actualizar; objetivos = [ "a-6" ] }) (Dedup.guardar_todo c) in
  comprueba "plan: versiones encadenadas" (List.map (fun (a : Atomo.t) -> a.version) (Dedup.plan c ds) = [ 2; 3 ])

(* Grabado de la prueba real (gemma, memoria-dedup): un episodio de
   retirada que se come un método, un hecho y un episodio. Con los frenos,
   solo cae el episodio. *)
let () =
  let c =
    Dedup.casos
      [ ( nuevo ~tipo:Atomo.Episodio "El 2026-08-28 se completó la retirada de gefs de la flota.",
          [ atomo ~tipo:Atomo.Metodo "a-9515109a6d91" "Réplica DRBD del pool gefs de a2 hacia a1: protocolo C, failover manual.";
            atomo ~tipo:Atomo.Episodio "a-ca3750963c05" "El 2026-08-26 gh se añadió a los paquetes comunes.";
            atomo "a-54984a69f0a9" "gefs-client.nix tiene selfHeal por defecto.";
            atomo ~tipo:Atomo.Episodio "a-1" "uno";
            atomo ~tipo:Atomo.Episodio "a-2" "dos" ] ) ]
  in
  let respuesta =
    {|[{"id":"n1","accion":"fusionar","objetivos":["a-9515109a6d91","a-ca3750963c05","a-54984a69f0a9","a-1","a-2"],"contenido":"El 2026-08-28 se completó la retirada de gefs.","tipo":"episodio","prioridad":80}]|}
  in
  match Dedup.leer c respuesta with
  | Error _ -> comprueba "freno: legible" false
  | Ok ds ->
      let filas = Dedup.plan c ds in
      comprueba "freno: el método y el hecho no se tocan"
        (not (List.exists (fun (a : Atomo.t) -> a.id = "a-9515109a6d91" || a.id = "a-54984a69f0a9") filas));
      comprueba "freno: como mucho tres objetivos" (List.length filas = 3);
      comprueba "freno: el resultado vive en el primer episodio"
        ((List.hd filas).id = "a-ca3750963c05" && (List.hd filas).vigente)

(* {1 Almacen (sin red)} *)

let () =
  comprueba "literal" (Almacen.literal "it's a\\b" = "'it''s a\\b'");
  comprueba "ms de ns" (Almacen.ms (`Int 1_791_885_600_000_000_000) = Some t0);
  comprueba "ms de ms" (Almacen.ms (`Int t0) = Some t0);
  let a = atomo "a-1" "con 'comillas'" in
  comprueba "fila de vuelta"
    (Almacen.atomo
       (`List
         [ `String "a-1"; `Int 1; `Bool true; `String "hecho"; `Int 70; `String "e"; `String "con 'comillas'"; `String "p";
           `String {|["s0/a-1"]|}; `String {|["2026-09-01"]|} ])
    = Some a);
  comprueba "valores" (String.starts_with ~prefix:"(5, 'a-1', 1, true, 'hecho', 70" (Almacen.valores ~ts:5 a))

(* {1 Destila, con efectos falsos} *)

let modelo s = Result.get_ok (Agencia.Modelo.de_texto s)
let escalera = [ modelo "openai:gemma-4-12b"; modelo "claude-haiku-5-5"; modelo "claude-sonnet-5-5"; modelo "claude-opus-5-5" ]
let agentes = { Destila.atomos = Result.get_ok (Agentes.atomos ~escalera); dedup = Result.get_ok (Agentes.dedup ~escalera) }

let () =
  comprueba "agentes: atomos por defecto sonnet" (Agencia.Modelo.to_string agentes.atomos.defecto = "claude-sonnet-5-5");
  comprueba "agentes: dedup por defecto haiku" (Agencia.Modelo.to_string agentes.dedup.defecto = "claude-haiku-5-5");
  let archivo = Agencia.Archivo.en_memoria () in
  comprueba "asegurar: la primera vez guarda" (Agentes.asegurar archivo agentes.atomos);
  comprueba "asegurar: la segunda no" (not (Agentes.asegurar archivo agentes.atomos))

let falsos ?(escribir = fun _ -> Ok ()) respuestas =
  let cola = ref respuestas and encargados = ref [] and malos = ref [] and escrito = ref [] and cursores = ref [] in
  let n = ref 0 in
  let ef =
    { Destila.encargar =
        (fun a ?modelo entrada ->
          incr n;
          let salida = match !cola with r :: resto -> cola := resto; r | [] -> Error "sin más" in
          let m = match modelo with Some m -> Agencia.Modelo.to_string m | None -> Agencia.Modelo.to_string a.defecto in
          encargados := (Forja.Tarea.to_string a.nombre, m) :: !encargados;
          { Agencia.Encargo.id = Printf.sprintf "%016d" !n; agente = a.nombre; version = Agencia.Agente.version a; modelo = m;
            motivo = ""; fuente = "directo"; entrada; salida; ms = 1; tokens_entrada = 1; tokens_salida = 1; veredicto = None;
            nota = ""; corregida = None });
      juzgar_mal = (fun e nota -> malos := (e.id, nota) :: !malos);
      candidatos = (fun (n : Atomo.nuevo) -> if n.tipo = Atomo.Hecho then [ atomo "a-111111111111" "GreptimeDB corre en c2." ] else []);
      escribir = (fun f -> match escribir f with Ok () -> escrito := !escrito @ f; Ok () | e -> e);
      guardar_cursor = (fun ~sesion:_ ~hasta ~escena -> cursores := (hasta, escena) :: !cursores; Ok ());
      avisar = (fun _ -> ()) }
  in
  (ef, encargados, malos, escrito, cursores)

let () =
  (* Lote normal: extracción, juez y escritura; el cursor avanza. *)
  let ef, encargados, malos, escrito, cursores =
    falsos [ Ok respuesta_atomos; Ok {|[{"id":"n2","accion":"actualizar","objetivos":["a-111111111111"],"contenido":"GreptimeDB corre en c3."}]|} ]
  in
  let informes, error = Destila.sesion ef agentes ~sesion:"s1" ~cursor:None nuevos in
  comprueba "destila: sin error" (error = None);
  comprueba "destila: un lote" (List.length informes = 1);
  comprueba "destila: dos encargos" (List.rev !encargados = [ ("memoria-atomos", "claude-sonnet-5-5"); ("memoria-dedup", "claude-haiku-5-5") ]);
  comprueba "destila: nada juzgado mal" (!malos = []);
  comprueba "destila: regla nueva y hecho actualizado"
    (List.map (fun (a : Atomo.t) -> a.version) !escrito = [ 1; 2 ]);
  comprueba "destila: cursor al último" (!cursores = [ ((List.nth nuevos 2).ts, Some "Despliegue de a2 con colmena") ])

let () =
  (* Basura del extractor: mal, y reintento con el siguiente más capaz. *)
  let ef, encargados, malos, _, cursores = falsos [ Ok "no sé"; Ok {|{"escenas":[{"escena":"x","atomos":[]}]}|} ] in
  let _, error = Destila.sesion ef agentes ~sesion:"s1" ~cursor:None nuevos in
  comprueba "reintento: sin error" (error = None);
  comprueba "reintento: a opus" (List.rev !encargados = [ ("memoria-atomos", "claude-sonnet-5-5"); ("memoria-atomos", "claude-opus-5-5") ]);
  comprueba "reintento: el primero, mal" (List.length !malos = 1);
  comprueba "reintento: avanza" (List.length !cursores = 1)

let () =
  (* Sin respuesta: la sesión se para y el cursor no se mueve. *)
  let ef, _, malos, _, cursores = falsos [ Error "503" ] in
  let _, error = Destila.sesion ef agentes ~sesion:"s1" ~cursor:None nuevos in
  comprueba "sin respuesta: error" (error <> None);
  comprueba "sin respuesta: no se juzga" (!malos = []);
  comprueba "sin respuesta: cursor quieto" (!cursores = [])

let () =
  (* Juez ilegible: mal, y se guarda todo. *)
  let ef, _, malos, escrito, _ = falsos [ Ok respuesta_atomos; Ok "<think>mmm" ] in
  let _ = Destila.sesion ef agentes ~sesion:"s1" ~cursor:None nuevos in
  comprueba "juez basura: mal" (List.length !malos = 1);
  comprueba "juez basura: todo guardado" (List.length !escrito = 2 && List.for_all (fun (a : Atomo.t) -> a.version = 1) !escrito)

let () =
  (* GreptimeDB no escribe: error y el cursor quieto. *)
  let ef, _, _, _, cursores = falsos ~escribir:(fun _ -> Error "greptime 500") [ Ok respuesta_atomos; Ok "[]" ] in
  let _, error = Destila.sesion ef agentes ~sesion:"s1" ~cursor:None nuevos in
  comprueba "sin escribir: error" (error = Some "greptime 500");
  comprueba "sin escribir: cursor quieto" (!cursores = [])

let () =
  (* Límite de lotes. *)
  let ef, encargados, _, _, _ = falsos (List.init 10 (fun _ -> Ok {|{"escenas":[]}|})) in
  let sesion = List.init 35 (fun i -> msg i (Printf.sprintf "mensaje %d" i)) in
  let informes, _ = Destila.sesion ef agentes ~limite:2 ~sesion:"s1" ~cursor:None sesion in
  comprueba "límite: 2 lotes" (List.length informes = 2 && List.length !encargados = 2)

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos\n" !fallos;
    exit 1)
