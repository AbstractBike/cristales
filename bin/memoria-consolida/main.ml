(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* memoria-consolida: L1 → L2/L3 (doc/memoria.md). Lee los átomos nuevos
   de memoria_l1 desde el cursor del repo, los consolida en escenas con el
   agente memoria-escenas, regenera la persona con memoria-persona si toca
   y hace commit en el repo memoria. Con --importar, antes convierte las
   notas de ~/.claude/projects/*/memory en átomos L1.

   Los encargos van por la agencia en proceso, con el mismo entorno que
   agencia-mcp (AGENCIA_ANTHROPIC, AGENCIA_OPENAI, AGENCIA_ESCALERA,
   AGENCIA_GREPTIME, AGENCIA_GREPTIME_DB y las claves): quedan en su
   archivo y pasan por la forja. *)

open Memoria_escenas

let entorno k d = Option.value ~default:d (Sys.getenv_opt k)
let var k = match Sys.getenv_opt k with Some v when String.trim v <> "" -> Some (String.trim v) | _ -> None
let bearer v = "Bearer " ^ v
let log s = prerr_endline ("memoria-consolida: " ^ s)

let iso t =
  let g = Unix.gmtime t in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (g.tm_year + 1900) (g.tm_mon + 1) g.tm_mday g.tm_hour g.tm_min g.tm_sec

let fecha t = String.sub (iso t) 0 10

(* {1 Opciones} *)

let repo = ref "."
let greptime = ref (entorno "MEMORIA_GREPTIME" "http://[fd00:103::f:2]:4000")
let db = ref "memoria"
let seco = ref false
let push = ref false
let importar = ref false
let notas = ref (Filename.concat (entorno "HOME" "/root") ".claude/projects")
let lote = ref 30
let maximo = ref 0
let solo_importar = ref false

let opciones =
  [ ("--repo", Arg.Set_string repo, "RUTA checkout del repo memoria (.)");
    ("--greptime", Arg.Set_string greptime, "URL raíz HTTP de GreptimeDB (MEMORIA_GREPTIME o el ClusterIP)");
    ("--db", Arg.Set_string db, "BASE base de memoria_l1 (memoria)");
    ("--seco", Arg.Set seco, " encarga y enseña lo que haría, sin escribir nada");
    ("--push", Arg.Set push, " git push al acabar");
    ("--importar", Arg.Set importar, " antes, las notas de --notas como átomos L1");
    ("--notas", Arg.Set_string notas, "RUTA raíz de los proyectos de Claude Code (~/.claude/projects)");
    ("--lote", Arg.Set_int lote, "N átomos por encargo (30)");
    ("--maximo", Arg.Set_int maximo, "N consolidar como mucho N átomos (0: todos)");
    ("--solo-importar", Arg.Set solo_importar, " importar las notas y nada más") ]

(* {1 Importación} *)

let leer f = In_channel.with_open_bin f In_channel.input_all

(* El cwd de un proyecto: el primero que diga alguno de sus JSONL. *)
let cwd_de dir =
  let jsonl =
    try Sys.readdir dir |> Array.to_list |> List.filter (fun f -> Filename.check_suffix f ".jsonl") with Sys_error _ -> []
  in
  List.find_map
    (fun f ->
      try
        In_channel.with_open_bin (Filename.concat dir f) (fun ic ->
            let rec ir n =
              if n = 0 then None
              else
                match In_channel.input_line ic with
                | None -> None
                | Some l -> (
                    match Yojson.Safe.from_string l with
                    | j -> ( match Yojson.Safe.Util.member "cwd" j with `String c -> Some c | _ -> ir (n - 1))
                    | exception _ -> ir (n - 1))
            in
            ir 30)
      with Sys_error _ -> None)
    jsonl

let notas_atomos raiz =
  let ahora = int_of_float (Unix.gettimeofday () *. 1000.) in
  let proyectos = try Sys.readdir raiz |> Array.to_list |> List.sort compare with Sys_error _ -> [] in
  let i = ref 0 in
  List.concat_map
    (fun p ->
      let dir = Filename.concat raiz p in
      let mem = Filename.concat dir "memory" in
      if not (Sys.file_exists mem && Sys.is_directory mem) then []
      else
        (* Sin JSONL, la ruta deshaciendo la codificación de Claude Code (que
           cambia «/» y «.» por «-»: con pérdida, pero legible). *)
        let proyecto =
          match cwd_de dir with Some c -> c | None -> String.map (function '-' -> '/' | c -> c) p
        in
        let escena = Filename.basename proyecto in
        Sys.readdir mem |> Array.to_list |> List.sort compare
        |> List.filter (fun f -> Filename.check_suffix f ".md" && not (Nota.es_indice f))
        |> List.map (fun f ->
               let ruta = p ^ "/" ^ f and fich = Filename.concat mem f in
               incr i;
               let n = Nota.de_texto (leer fich) in
               ( proyecto,
                 Nota.atomo ~ts:(ahora + !i) ~ruta ~proyecto ~escena ~fecha:(fecha (Unix.stat fich).st_mtime) n,
                 ruta )))
    proyectos

let registro_importados atomos =
  let b = Buffer.create 65536 in
  Printf.bprintf b
    "# Átomos importados\n\n\
     %d notas de `~/.claude/projects/*/memory` (sin los `MEMORY.md`), importadas el %s: cada nota es un átomo L1 \
     cuyo contenido es su `description`; el cuerpo sigue en la nota.\n"
    (List.length atomos) (fecha (Unix.gettimeofday ()));
  let proyecto = ref "" in
  List.iter
    (fun (p, (a : Atomo.t), ruta) ->
      if p <> !proyecto then (
        proyecto := p;
        Printf.bprintf b "\n## %s\n\n" p);
      Printf.bprintf b "- `%s` [%s] %s — `%s`\n" a.id a.tipo (String.trim a.contenido) ruta)
    atomos;
  Buffer.contents b

(* {1 Git} *)

let git args =
  let c = String.concat " " ("git" :: "-C" :: Filename.quote !repo :: List.map Filename.quote args) in
  match Sys.command c with 0 -> Ok () | n -> Error (Printf.sprintf "%s: salió con %d" c n)

let commit mensaje =
  let ( let* ) = Result.bind in
  let* () = git [ "add"; "-A" ] in
  if Sys.command (Printf.sprintf "git -C %s diff --cached --quiet" (Filename.quote !repo)) = 0 then (
    log "nada que commitear";
    Ok ())
  else
    let* () =
      git [ "-c"; "user.name=Claude"; "-c"; "user.email=noreply@anthropic.com"; "commit"; "-q"; "-m"; mensaje ]
    in
    if !push then git [ "push"; "-q" ] else Ok ()

(* {1 La agencia} *)

let escalera () =
  String.split_on_char ',' (entorno "AGENCIA_ESCALERA" "claude-haiku-5-5,claude-sonnet-5-5,claude-opus-5-5")
  |> List.map (fun m ->
         match Agencia.Modelo.de_texto m with Ok m -> m | Error e -> failwith ("AGENCIA_ESCALERA: " ^ e))

let () =
  Arg.parse opciones (fun a -> raise (Arg.Bad ("sobra " ^ a))) "memoria-consolida [opciones]";
  Mirage_crypto_rng_unix.use_default ();
  Eio_main.run @@ fun env ->
  let cliente = Forja_http.Proxy.cliente (Eio.Stdenv.net env) in
  let post = Forja_http.Proxy.post cliente in
  let g = Forja_http.Greptime.conectar ~post ~url:(Uri.of_string !greptime) ~db:!db in
  let archivo =
    match var "AGENCIA_GREPTIME" with
    | Some url ->
        let url = Uri.of_string url and adb = entorno "AGENCIA_GREPTIME_DB" "agencia" in
        Agencia_http.Medidas.con_medidas
          (Agencia_http.Medidas.a_greptime (Forja_http.Greptime.conectar ~post ~url ~db:adb))
          (Agencia_http.Archivo_greptime.crear ~post ~url ~db:adb ())
    | None ->
        log "sin AGENCIA_GREPTIME, los encargos no quedan en el archivo de la agencia";
        Agencia.Archivo.en_memoria ()
  in
  let destinos =
    { Agencia_http.Llm.anthropic = Uri.of_string (entorno "AGENCIA_ANTHROPIC" "http://[b1c1:a2::1]:8090");
      openai = Option.map Uri.of_string (var "AGENCIA_OPENAI");
      cabeceras_anthropic =
        List.filter_map Fun.id
          [ Option.map (fun v -> ("x-api-key", v)) (var "ANTHROPIC_API_KEY");
            Option.map (fun v -> ("authorization", bearer v)) (var "ANTHROPIC_AUTH_TOKEN") ];
      cabeceras_openai = Option.to_list (Option.map (fun v -> ("authorization", bearer v)) (var "OPENAI_API_KEY")) }
  in
  let azar = Random.State.make_self_init () in
  let escalera = escalera () in
  let efectos =
    { Agencia_mcp.archivo;
      llamar = Agencia_http.Llm.llamar (Eio.Stdenv.clock env) cliente destinos;
      id = (fun () -> String.init 16 (fun _ -> "0123456789abcdef".[Random.State.int azar 16]));
      escalera;
      politica = Agencia.Politica.por_defecto }
  in
  let escenas_agente = Agentes.escenas ~escalera and persona_agente = Agentes.persona ~escalera in
  if not !seco then (
    Agentes.asegurar archivo escenas_agente;
    Agentes.asegurar archivo persona_agente);
  (* Importación. *)
  let importados = ref [] in
  if !importar then (
    let todas = notas_atomos !notas in
    (match L1.crear_tabla g with Ok () -> () | Error e -> failwith e);
    let hay = L1.ids g in
    let nuevas = List.filter (fun (_, (a : Atomo.t), _) -> not (List.mem a.id hay)) todas in
    importados := List.map (fun (_, a, _) -> a) nuevas;
    log (Printf.sprintf "%d notas, %d ya importadas, %d nuevas" (List.length todas) (List.length todas - List.length nuevas)
           (List.length nuevas));
    if not !seco then (
      (match L1.insertar g (List.map (fun (_, a, _) -> a) nuevas) with
      | Ok n -> log (Printf.sprintf "%d átomos escritos en %s.memoria_l1" n !db)
      | Error e -> failwith e);
      Repo.escribir_fichero !repo "atomos-importados/notas.md" (registro_importados todas)));
  if !solo_importar then exit 0;
  (* Consolidación. *)
  let estado = Repo.estado !repo in
  let escenas = match Repo.escenas !repo with Ok e -> e | Error e -> failwith e in
  let atomos = if !seco && !importar then !importados else L1.desde g estado.cursor in
  let atomos =
    if !maximo > 0 then List.filteri (fun i _ -> i < !maximo) (List.sort (fun (a : Atomo.t) b -> compare a.ts b.ts) atomos)
    else atomos
  in
  log (Printf.sprintf "%d átomos nuevos desde %d; %d escenas" (List.length atomos) estado.cursor (List.length escenas));
  (* Sin átomos nuevos solo se sigue si la persona va atrasada (una pasada
     anterior no logró escribirla). *)
  if atomos = [] && (not !importar)
     && Persona.disparo ~ultima:estado.persona ~escenas ~senal:None ~atomos_desde:estado.atomos_desde_persona = None
  then exit 0;
  let ciclo =
    { Ciclo.encargar = (fun ?modelo a entrada -> Agencia_mcp.encargar efectos a ?modelo entrada);
      juzgar_mal = (fun e nota -> archivo.juzgar e.agente e.id Agencia.Mal nota);
      ahora = (fun () -> iso (Unix.gettimeofday ()));
      log }
  in
  let s =
    Ciclo.consolidar ciclo ~escenas_agente ~persona_agente ~lote:!lote ~estado ~persona:(Repo.persona !repo) escenas
      atomos
  in
  List.iter
    (fun (e : Ciclo.encargo) ->
      Printf.printf "encargo %s %s %s %d ms %d tokens: %s\n" e.agente e.id e.modelo e.ms e.tokens e.resumen)
    s.encargos;
  if s.fallidos > 0 then log (Printf.sprintf "%d lotes sin hacer: el cursor no avanza" s.fallidos);
  Printf.printf "escenas (%d): %s\n" (List.length s.escenas)
    (String.concat ", " (List.map (fun (e : Escena.t) -> Printf.sprintf "%s(%d)" e.slug e.calor) s.escenas));
  if !seco then (
    List.iter
      (fun sl ->
        match List.find_opt (fun (e : Escena.t) -> e.slug = sl) s.escenas with
        | Some e -> Printf.printf "\n==> escenas/%s.md\n%s" sl (Escena.a_texto e)
        | None -> ())
      s.escritas;
    Option.iter (fun p -> Printf.printf "\n==> persona.md\n%s\n" p) s.persona)
  else (
    Repo.escribir !repo ~escenas:s.escenas ~escritas:s.escritas ~borradas:s.borradas ~persona:s.persona s.estado;
    let mensaje =
      Printf.sprintf "memoria: %d átomos consolidados; %d escenas escritas, %d borradas%s%s" s.consolidados
        (List.length s.escritas) (List.length s.borradas)
        (if s.persona = None then "" else ", persona regenerada")
        (if !importar then " (importación de las notas)" else "")
    in
    match commit mensaje with Ok () -> () | Error e -> failwith e)
