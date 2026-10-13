(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red del recall de la memoria: el frontmatter, el contexto del hook
   (estable y acotado), el escape del SQL y el servidor MCP con un GreptimeDB
   falso. *)

open Memoria_recall

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let contiene s sub =
  let n = String.length sub and m = String.length s in
  let rec ir i = i + n <= m && (String.sub s i n = sub || ir (i + 1)) in
  ir 0

let escribir ruta texto = Out_channel.with_open_bin ruta (fun oc -> output_string oc texto)

let repo_de_prueba () =
  let dir = Filename.temp_dir "memoria" "" in
  Sys.mkdir (Filename.concat dir "escenas") 0o755;
  escribir (Filename.concat dir "persona.md") "---\nactualizada: 2026-10-13\n---\n\nSilvio, arquitecto. Español.\n";
  let escena slug fm cuerpo = escribir (Filename.concat dir ("escenas/" ^ slug ^ ".md")) ("---\n" ^ fm ^ "---\n" ^ cuerpo) in
  escena "flota" "titulo: La flota\nresumen: \"Colmena, k0s y la malla\"\ncalor: 3.5\nbloqueada: true\n" "# La flota\n";
  escena "greptime" "titulo: GreptimeDB\nresumen: Una sola base\ncalor: 9\n" "# GreptimeDB\n";
  escena "sin-calor" "titulo: Sin calor\n" "cuerpo";
  escena "b-empate" "titulo: B\ncalor: 3.5\n" "";
  escribir (Filename.concat dir "escenas/NoValida.md") "x";
  escribir (Filename.concat dir "escenas/notas.txt") "x";
  dir

let () =
  (* {1 Frontmatter} *)
  let fm = Escenas.frontmatter "---\ntitulo: Hola: mundo\nresumen: 'x'\n---\ncuerpo" in
  comprueba "frontmatter con dos puntos en el valor" (List.assoc_opt "titulo" fm = Some "Hola: mundo");
  comprueba "frontmatter sin comillas" (List.assoc_opt "resumen" fm = Some "x");
  comprueba "sin frontmatter, nada" (Escenas.frontmatter "# título\n" = []);
  comprueba "frontmatter sin cerrar, nada" (Escenas.frontmatter "---\ntitulo: x\n" = []);
  let e = Escenas.de_texto ~slug:"s" "---\ncalor: mucho\n---\n" in
  comprueba "campos que faltan" (e.titulo = "s" && e.resumen = "" && e.calor = 0.);
  comprueba "slug con ruta, inválido" (not (Escenas.slug_valido "../persona"));
  comprueba "slug con punto, inválido" (not (Escenas.slug_valido "a.b"));

  (* {1 Índice y contexto del hook} *)
  let repo = repo_de_prueba () in
  let slugs = List.map (fun (e : Escenas.t) -> e.slug) (Escenas.indice repo) in
  comprueba "índice por calor y, a igual calor, por slug"
    (slugs = [ "greptime"; "b-empate"; "flota"; "sin-calor" ]);
  let salida = Contexto.de_repo repo in
  comprueba "hook estable byte a byte" (salida = Contexto.de_repo repo);
  (match Yojson.Safe.from_string salida with
  | `Assoc [ ("hookSpecificOutput", `Assoc [ ("hookEventName", `String "SessionStart"); ("additionalContext", `String c) ]) ] ->
      comprueba "contexto con la persona" (contiene c "Silvio, arquitecto");
      comprueba "persona sin frontmatter" (not (contiene c "actualizada"));
      comprueba "escena con título, slug y resumen" (contiene c "- **La flota** (`flota`): Colmena, k0s y la malla");
      comprueba "apunta al MCP" (contiene c "memoria_escena");
      comprueba "greptime antes que flota"
        (let i s = let rec ir k = if String.sub c k (String.length s) = s then k else ir (k + 1) in ir 0 in
         i "(`greptime`)" < i "(`flota`)")
  | _ -> comprueba "JSON del hook" false);
  comprueba "sin repo, salida vacía" (Contexto.de_repo "/no/existe" = "");
  (* Muchas escenas largas: se queda en el presupuesto y cuenta las que faltan. *)
  let muchas =
    List.init 60 (fun i ->
        { Escenas.slug = Printf.sprintf "e%02d" i; titulo = "Título"; resumen = String.make 400 'x' ^ "ñ";
          calor = 1.; actualizada = "" })
  in
  let c = Contexto.texto ~repo:"/r" ~persona:(Some (String.concat "" (List.init 900 (fun _ -> "ñá")))) muchas in
  comprueba "dentro del presupuesto" (String.length c <= Contexto.presupuesto);
  comprueba "cuenta las que no caben" (contiene c "escenas más");
  comprueba "UTF-8 válido tras recortar" (String.is_valid_utf_8 c);
  comprueba "recortar no parte caracteres" (String.is_valid_utf_8 (Contexto.recortar 10 "ñññññññññññ"));

  (* {1 SQL} *)
  comprueba "literal dobla comillas" (Consulta.literal "x') OR 1=1 --" = "'x'') OR 1=1 --'");
  comprueba "literal quita barras invertidas" (Consulta.literal "a\\' OR 1=1" = "'a'' OR 1=1'");
  comprueba "literal sin saltos" (Consulta.literal "a\nb" = "'a b'");
  comprueba "términos" (Consulta.terminos "GreptimeDB, --impure; ÁRBOL 'x' sucio sucio" = [ "greptimedb"; "impure"; "árbol"; "sucio" ]);
  comprueba "términos sin comillas ni operadores" (Consulta.terminos "+a' OR \"b\" -c" = [ "or" ]);
  comprueba "operadores entre comillas" (contiene (Consulta.atomos { Consulta.l0 = "l0"; l1 = "l1" } ~terminos:[ "or" ] ()) "'\"or\"'");
  comprueba "fecha día" (Consulta.fecha "2026-10-01" = Ok "2026-10-01 00:00:00");
  comprueba "fecha con hora" (Consulta.fecha "2026-10-01T09:30" = Ok "2026-10-01 09:30:00");
  comprueba "fecha mala" (Result.is_error (Consulta.fecha "2026-10-01'; DROP"));
  let t = { Consulta.l0 = "l0"; l1 = "l1" } in
  let q = Consulta.atomos t ~terminos:[ "colmena" ] ~tipo:"regla" ~proyecto:"o'k" () in
  comprueba "atomos" (contiene q "matches(lower(contenido), '\"colmena\"')" && contiene q "strpos(proyecto, 'o''k')"
                      && contiene q "vigente = true");
  comprueba "extracto alrededor del término"
    (contiene (Consulta.extracto ~ancho:40 [ "aguja" ] (String.make 200 'a' ^ " aguja " ^ String.make 200 'b')) "aguja");

  (* {1 Servidor, con un GreptimeDB falso} *)
  let consultas = ref [] in
  let sql q =
    consultas := q :: !consultas;
    if contiene q "GROUP BY" then Ok [ `List [ `String "a-1"; `Int 2 ]; `List [ `String "a-2"; `Int 3 ] ]
    else if contiene q "FROM l1" then
      Ok
        [ (* a-1: la v2 es la última y casa. *)
          `List [ `Int 1790848800000; `String "a-1"; `Int 2; `String "regla"; `Int (-1); `String "flota";
                  `String "Nunca colmena con impure"; `String "/n"; `String "[]" ];
          `List [ `Int 1790848700000; `String "a-1"; `Int 1; `String "regla"; `Int (-1); `String "flota";
                  `String "Nunca colmena"; `String "/n"; `String "[]" ];
          (* a-2: casa la v2, pero hay una v3 más nueva: fuera. *)
          `List [ `Int 1790848800000; `String "a-2"; `Int 2; `String "hecho"; `Int 50; `String "g";
                  `String "colmena vieja"; `String "/n"; `String "[]" ] ]
    else if contiene q "FROM l0" then
      Ok [ `List [ `Int 1790848800000; `String "s1"; `String "/n"; `String "user"; `String "usa colmena" ] ]
    else Error "?"
  in
  let s = Servidor.servidor { Servidor.sql; repo; tablas = t } in
  let llamar nombre args =
    match s.llamar nombre (`Assoc args) with
    | Ok r -> Yojson.Safe.Util.(r |> member "content" |> index 0 |> member "text" |> to_string)
    | Error (_, m) -> "ERROR " ^ m
  in
  let r = llamar "memoria_buscar" [ ("consulta", `String "colmena impure") ] in
  comprueba "buscar devuelve la vigente" (contiene r "[a-1 v2]" && contiene r "Nunca colmena con impure");
  comprueba "buscar descarta la superada" (not (contiene r "a-2"));
  comprueba "buscar valida el tipo" (contiene (llamar "memoria_buscar" [ ("consulta", `String "x1"); ("tipo", `String "x") ]) "ERROR");
  comprueba "buscar sin términos" (contiene (llamar "memoria_buscar" [ ("consulta", `String "' -- ;") ]) "ERROR");
  let r = llamar "memoria_conversacion" [ ("consulta", `String "colmena"); ("desde", `String "2026-10-01") ] in
  comprueba "conversacion" (contiene r "sesión s1" && contiene r "usa colmena");
  comprueba "conversacion con desde" (List.exists (fun q -> contiene q "ts >= '2026-10-01 00:00:00'") !consultas);
  comprueba "escena" (contiene (llamar "memoria_escena" [ ("slug", `String "flota") ]) "# La flota");
  comprueba "escena fuera del repo"
    (contiene (llamar "memoria_escena" [ ("slug", `String "../persona") ]) "no es un slug");
  comprueba "tres herramientas" (List.length (s.herramientas ()) = 3);
  if !fallos > 0 then exit 1
