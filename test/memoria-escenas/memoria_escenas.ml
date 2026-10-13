(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red de la consolidación L2/L3: el formato de las escenas, las
   operaciones, las reglas del tope, la persona, las notas importadas y
   una pasada entera con un agente falso. *)

open Memoria_escenas

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let escena ?(calor = 1) ?(bloqueada = false) ?(atomos = []) slug =
  { Escena.slug; titulo = "Título " ^ slug; resumen = "Resumen de " ^ slug; creada = "2026-10-01T00:00:00Z";
    actualizada = "2026-10-01T00:00:00Z"; calor; bloqueada; atomos; extra = []; cuerpo = "## Datos clave\n\n- " ^ slug }

let atomo ?(ts = 1000) ?(version = 1) ?(vigente = true) ?(escena = "flota") id contenido =
  { Atomo.ts; id; version; vigente; tipo = "hecho"; prioridad = 50; escena; contenido; proyecto = "/p"; origen = "[]";
    fechas = {|["2026-10-13"]|} }

let contenido ?(cuerpo = "## Datos clave\n\n- nuevo") ?(atomos = []) slug =
  { Operacion.slug; titulo = "T " ^ slug; resumen = "R " ^ slug; cuerpo; atomos }

let ahora = "2026-10-13T12:00:00Z"

let contiene sub s =
  let n = String.length sub in
  let rec ir i = i + n <= String.length s && (String.sub s i n = sub || ir (i + 1)) in
  ir 0

(* {1 Escenas} *)

let () =
  let e = { (escena ~calor:3 ~atomos:[ "a-1"; "a-2" ] "flota-nixos") with extra = [ ("autor", "silvio") ] } in
  let t = Escena.a_texto e in
  comprueba "ida y vuelta de una escena" (Escena.de_texto ~slug:"flota-nixos" t = Ok e);
  comprueba "vuelta e ida del texto" (Result.map Escena.a_texto (Escena.de_texto ~slug:"flota-nixos" t) = Ok t);
  comprueba "atomos en la cabecera" (String.length t > 0 && Escena.de_texto ~slug:"x" "---\natomos: []\n---\nb" |> function
    | Ok e -> e.atomos = [] && e.cuerpo = "b"
    | Error _ -> false);
  (match Escena.de_texto ~slug:"suelta" "# Sin cabecera\n\ntexto" with
  | Ok e -> comprueba "sin cabecera, todo es cuerpo" (e.titulo = "suelta" && e.cuerpo = "# Sin cabecera\n\ntexto")
  | Error _ -> comprueba "sin cabecera se lee" false);
  comprueba "calor que no es entero"
    (Result.is_error (Escena.de_texto ~slug:"x" "---\ncalor: mucho\n---\nb"));
  (match Escena.de_texto ~slug:"x" "---\nbloqueada: sí\ntitulo: Uno: dos\n---\nb" with
  | Ok e -> comprueba "bloqueada: sí y dos puntos en el valor" (e.bloqueada && e.titulo = "Uno: dos")
  | Error _ -> comprueba "bloqueada: sí se lee" false);
  comprueba "título de varias líneas, a una"
    (Escena.de_texto ~slug:"x" (Escena.a_texto { e with titulo = "a\nb" }) |> function
     | Ok e -> e.titulo = "a b"
     | Error _ -> false);
  comprueba "longitud en caracteres" (Escena.longitud "añoñé" = 5);
  comprueba "slug válido" (Escena.slug_valido "forja-y-agencia-2");
  comprueba "slug con mayúsculas" (not (Escena.slug_valido "Flota"));
  comprueba "slug con tilde" (not (Escena.slug_valido "configuración"));
  comprueba "slug con guion al final" (not (Escena.slug_valido "flota-"));
  comprueba "slug vacío" (not (Escena.slug_valido ""))

(* {1 Operaciones} *)

let () =
  let texto =
    {|Aquí va:
```json
{"operaciones": [
  {"op": "actualizar", "slug": "a", "titulo": "A", "resumen": "r", "cuerpo": "c", "atomos": ["a-1"]},
  {"op": "fusionar", "de": ["b", "c"], "slug": "bc", "titulo": "BC", "resumen": "r", "cuerpo": "c"},
  {"op": "crear", "slug": "d", "titulo": "D", "resumen": "r", "cuerpo": "c", "atomos": []},
  {"op": "nada"}],
 "persona": "[ACTUALIZAR_PERSONA] cambia su regla global"}
```|}
  in
  match Operacion.de_texto texto with
  | Error e -> comprueba ("operaciones: " ^ e) false
  | Ok s ->
      comprueba "cuatro operaciones" (List.length s.operaciones = 4);
      comprueba "describir"
        (List.map Operacion.describir s.operaciones = [ "actualizar a"; "fusionar b+c -> bc"; "crear d"; "nada" ]);
      comprueba "señal de persona" (s.persona = Some "cambia su regla global");
      comprueba "sin señal"
        ((Result.get_ok (Operacion.de_texto {|{"operaciones": [], "persona": ""}|})).persona = None);
      comprueba "operación desconocida" (Result.is_error (Operacion.de_texto {|{"operaciones": [{"op": "borrar"}]}|}));
      comprueba "sin JSON" (Result.is_error (Operacion.de_texto "no sé"));
      comprueba "a_json y vuelta"
        (Operacion.de_texto
           (Yojson.Safe.to_string (`Assoc [ ("operaciones", `List (List.map Operacion.a_json s.operaciones)) ]))
         |> function
         | Ok s' -> s'.operaciones = s.operaciones
         | Error _ -> false)

(* {1 Tope y avisos} *)

let () =
  comprueba "sin aviso con 11" (Consolidacion.aviso 11 = None);
  comprueba "aviso con 12" (Consolidacion.aviso 12 <> None);
  comprueba "con 13 se crea" (Consolidacion.puede_crear 13);
  comprueba "con 14 no se crea" (not (Consolidacion.puede_crear 14));
  comprueba "con 15 no se crea" (not (Consolidacion.puede_crear 15))

let n_escenas n = List.init n (fun i -> escena (Printf.sprintf "e%02d" i))
let todas l = List.map (fun (e : Escena.t) -> e.slug) l

(* {1 Aplicar} *)

let () =
  let nuevos = [ atomo "a-1" "uno"; atomo "a-2" "dos" ] in
  let base = [ escena ~calor:2 ~atomos:[ "a-0" ] "a"; escena ~calor:3 "b"; escena "c"; escena ~bloqueada:true "z" ] in
  let abiertas = [ "a"; "b"; "c"; "z" ] in
  let aplicar ?(abiertas = abiertas) ?(escenas = base) ops = Consolidacion.aplicar ~ahora ~abiertas ~nuevos escenas ops in
  let busca s (r : Consolidacion.resultado) = List.find (fun (e : Escena.t) -> e.slug = s) r.escenas in
  (* Crear. *)
  let r = aplicar [ Operacion.Crear (contenido ~atomos:[ "a-1"; "a-inventado" ] "nueva") ] in
  let e = busca "nueva" r in
  comprueba "crear: calor 1" (e.calor = 1);
  comprueba "crear: fechas" (e.creada = ahora && e.actualizada = ahora);
  comprueba "crear: solo átomos del lote" (e.atomos = [ "a-1" ]);
  comprueba "crear: escrita" (r.escritas = [ "nueva" ]);
  comprueba "crear uno que existe" (List.length (aplicar [ Crear (contenido "a") ]).rechazos = 1);
  (* Actualizar. *)
  let r = aplicar [ Actualizar (contenido ~atomos:[ "a-2" ] "a") ] in
  let e = busca "a" r in
  comprueba "actualizar: calor +1" (e.calor = 3);
  comprueba "actualizar: conserva creada" (e.creada = "2026-10-01T00:00:00Z" && e.actualizada = ahora);
  comprueba "actualizar: une átomos" (e.atomos = [ "a-0"; "a-2" ]);
  comprueba "actualizar una bloqueada" (List.length (aplicar [ Actualizar (contenido "z") ]).rechazos = 1);
  comprueba "actualizar una no abierta"
    (List.length (aplicar ~abiertas:[ "b" ] [ Actualizar (contenido "a") ]).rechazos = 1);
  comprueba "actualizar una que no existe" (List.length (aplicar [ Actualizar (contenido "nop") ]).rechazos = 1);
  let largo = String.concat "" (List.init 1501 (fun _ -> "ñ")) in
  comprueba "cuerpo de más de 1500 caracteres"
    (List.length (aplicar [ Actualizar (contenido ~cuerpo:largo "a") ]).rechazos = 1);
  comprueba "cuerpo de 1500 caracteres"
    ((aplicar [ Actualizar (contenido ~cuerpo:(String.sub largo 0 3000) "a") ]).rechazos = []);
  comprueba "slug inválido" (List.length (aplicar [ Crear (contenido "Mal Slug") ]).rechazos = 1);
  (* Fusionar. *)
  let r = aplicar [ Fusionar ([ "a"; "b" ], contenido ~atomos:[ "a-1" ] "ab") ] in
  let e = busca "ab" r in
  comprueba "fusionar: calor suma+1" (e.calor = 6);
  comprueba "fusionar: une átomos" (e.atomos = [ "a-0"; "a-1" ]);
  comprueba "fusionar: borra las fuentes" (r.borradas = [ "a"; "b" ] && todas r.escenas = [ "ab"; "c"; "z" ]);
  let r = aplicar [ Fusionar ([ "a"; "b" ], contenido "a") ] in
  comprueba "fusionar en una de las fuentes" (r.borradas = [ "b" ] && r.escritas = [ "a" ]);
  comprueba "fusionar con una bloqueada" (List.length (aplicar [ Fusionar ([ "a"; "z" ], contenido "az") ]).rechazos = 1);
  comprueba "fusionar una sola" (List.length (aplicar [ Fusionar ([ "a" ], contenido "a2") ]).rechazos = 1);
  comprueba "fusionar sobre otra que existe"
    (List.length (aplicar [ Fusionar ([ "a"; "b" ], contenido "c") ]).rechazos = 1);
  (* Fusionar y luego actualizar la resultante, aunque no estuviera abierta. *)
  let r = aplicar [ Actualizar (contenido "ab"); Fusionar ([ "a"; "b" ], contenido "ab") ] in
  comprueba "las fusiones van primero" (r.rechazos = [] && (busca "ab" r).calor = 7);
  (* Tope. *)
  let catorce = n_escenas 14 in
  let ab = todas catorce in
  comprueba "con 14 no se crea"
    (List.length (aplicar ~escenas:catorce ~abiertas:ab [ Crear (contenido "nueva") ]).rechazos = 1);
  let r = aplicar ~escenas:catorce ~abiertas:ab [ Crear (contenido "nueva"); Fusionar ([ "e00"; "e01" ], contenido "e00") ] in
  comprueba "fusionar primero deja sitio" (r.rechazos = [] && List.length r.escenas = 14);
  let r = aplicar ~escenas:[] ~abiertas:[] [ Crear (contenido "x1"); Crear (contenido "x2"); Crear (contenido "x3") ] in
  comprueba "como mucho 2 crear por lote" (List.length r.escenas = 2 && List.length r.rechazos = 1)

(* {1 Abiertas e índice} *)

let () =
  let es =
    [ { (escena "flota-nixos") with cuerpo = "colmena despliega la flota nixos en a1 a2 c1" };
      { (escena "cocina") with cuerpo = "recetas de tortilla y gazpacho" };
      { (escena ~bloqueada:true "flota-bloqueada") with cuerpo = "colmena flota nixos" } ]
  in
  let ab = Consolidacion.abiertas es [ atomo "a-1" "colmena apply en la flota nixos" ] in
  comprueba "la más parecida primero" (List.hd ab = "flota-nixos");
  comprueba "sin bloqueadas" (not (List.mem "flota-bloqueada" ab));
  let m = Consolidacion.entrada ~ahora ~escenas:es ~abiertas:ab [ atomo "a-1" "colmena apply" ] in
  let contiene sub = contiene sub m in
  comprueba "el índice marca la bloqueada" (contiene "bloqueada: sí");
  comprueba "el mensaje trae los átomos" (contiene "`a-1` [hecho] 2026-10-13 (/p): colmena apply");
  comprueba "con 12 escenas, aviso en el mensaje"
    (let m = Consolidacion.entrada ~ahora ~escenas:(n_escenas 12) ~abiertas:[] [] in
     String.length m > 0 && String.sub m 0 15 = "## Aviso de top")

(* {1 Persona} *)

let () =
  let es = [ { (escena "a") with actualizada = "2026-10-13T00:00:00Z" }; escena "b" ] in
  comprueba "sin persona, la primera" (Persona.disparo ~ultima:None ~escenas:es ~senal:None ~atomos_desde:0 <> None);
  comprueba "escenas posteriores"
    (Persona.cambiadas ~ultima:(Some "2026-10-05T00:00:00Z") es |> List.map (fun (e : Escena.t) -> e.slug) = [ "a" ]);
  comprueba "nada nuevo, nada"
    (Persona.disparo ~ultima:(Some "2026-10-14T00:00:00Z") ~escenas:es ~senal:None ~atomos_desde:49 = None);
  comprueba "50 átomos"
    (Persona.disparo ~ultima:(Some "2026-10-14T00:00:00Z") ~escenas:es ~senal:None ~atomos_desde:50 <> None);
  comprueba "señal"
    (Persona.disparo ~ultima:(Some "2026-10-14T00:00:00Z") ~escenas:es ~senal:(Some "x") ~atomos_desde:0 <> None);
  comprueba "persona en bloque de código" (Persona.validar "```markdown\n# Persona\n```" = Ok "# Persona");
  comprueba "persona larga" (Result.is_error (Persona.validar (String.make 2001 'x')));
  comprueba "persona vacía" (Result.is_error (Persona.validar "  "))

(* {1 Notas} *)

let () =
  let n =
    Nota.de_texto
      "---\nname: a1-caidas\ndescription: \"a1 se reinicia \\\"en seco\\\" desde 2026-08-01\"\nmetadata:\n  type: \
       feedback\n---\n\nCuerpo del 2026-09-14 y 2026-08-01.\n"
  in
  comprueba "nota: nombre" (n.nombre = "a1-caidas");
  comprueba "nota: descripción entre comillas" (n.descripcion = "a1 se reinicia \"en seco\" desde 2026-08-01");
  comprueba "nota: type anidado" (n.tipo = "feedback");
  comprueba "nota: cuerpo" (n.cuerpo = "Cuerpo del 2026-09-14 y 2026-08-01.");
  comprueba "nota: comillas simples"
    ((Nota.de_texto "---\ndescription: 'it''s'\ntype: user\n---\nx").descripcion = "it's");
  comprueba "tipos" (List.map Nota.tipo_atomo [ "feedback"; "user"; "project"; "reference"; "" ]
                    = [ "regla"; "persona"; "hecho"; "hecho"; "hecho" ]);
  comprueba "fechas" (Nota.fechas_en "x 2026-09-14, 2026-08-01 y 2026-09-14; 12026-01-01x" = [ "2026-08-01"; "2026-09-14" ]);
  let a = Nota.atomo ~ts:5 ~ruta:"-p/a1.md" ~proyecto:"/p" ~escena:"p" ~fecha:"2026-10-13" n in
  comprueba "átomo: id estable" (a.id = Nota.id_de "-p/a1.md" && String.length a.id = 14);
  comprueba "átomo: ids distintos" (Nota.id_de "-p/a1.md" <> Nota.id_de "-q/a1.md");
  comprueba "átomo: regla" (a.tipo = "regla" && a.prioridad = 70);
  comprueba "átomo: fechas" (Atomo.fechas a = [ "2026-08-01"; "2026-09-14"; "2026-10-13" ]);
  comprueba "átomo: origen" (a.origen = {|["nota:-p/a1.md"]|});
  comprueba "índice" (Nota.es_indice "/x/memory/MEMORY.md");
  comprueba "sin descripción, primer párrafo"
    ((Nota.atomo ~ts:1 ~ruta:"r" ~proyecto:"" ~escena:"" ~fecha:"" (Nota.de_texto "---\nname: x\n---\n# T\n\nPrimero.\n")).contenido
     = "Primero.")

(* {1 Átomos y L1} *)

let () =
  let l =
    [ atomo ~ts:1 "a-1" "v1"; atomo ~ts:3 ~version:2 "a-1" "v2"; atomo ~ts:2 "a-2" "x";
      atomo ~ts:4 ~version:2 ~vigente:false "a-2" "fuera" ]
  in
  comprueba "vigentes" (List.map (fun (a : Atomo.t) -> a.contenido) (Atomo.vigentes l) = [ "v2" ]);
  let fila = `List [ `Int 7; `String "a-9"; `Int 1; `Bool true; `String "regla"; `Int 70; `String "e"; `String "c";
                     `String "p"; `String "[]"; `String "[]" ] in
  comprueba "de_fila" ((Option.get (Atomo.de_fila fila)).tipo = "regla");
  let sql = L1.insertar_sql [ atomo "a-'1" "it's" ] in
  comprueba "comillas escapadas"
    (contiene "'it''s'" sql)

(* {1 Estado} *)

let () =
  let e = { Estado.cursor = 42; persona = Some ahora; atomos_desde_persona = 3 } in
  comprueba "estado: ida y vuelta" (Estado.de_texto (Estado.a_texto e) = e);
  comprueba "estado: basura" (Estado.de_texto "x" = Estado.inicial)

(* {1 Una pasada con un agente falso} *)

let () =
  let escalera = [ Result.get_ok (Agencia.Modelo.de_texto "claude-haiku-5-5") ] in
  let escenas_agente = Agentes.escenas ~escalera and persona_agente = Agentes.persona ~escalera in
  let respuestas = ref [] and malos = ref [] and pedidos = ref [] in
  let n = ref 0 in
  let encargar ?modelo:_ (a : Agencia.Agente.t) entrada =
    incr n;
    pedidos := entrada :: !pedidos;
    let salida = match !respuestas with r :: resto -> respuestas := resto; r | [] -> Ok "{}" in
    { Agencia.Encargo.id = Printf.sprintf "%016d" !n; agente = a.nombre; version = Agencia.Agente.version a;
      modelo = "claude-haiku-5-5"; motivo = ""; fuente = "directo"; entrada; salida; ms = 1; tokens_entrada = 1;
      tokens_salida = 1; veredicto = None; nota = ""; corregida = None }
  in
  let ef =
    { Ciclo.encargar; juzgar_mal = (fun e nota -> malos := (e.id, nota) :: !malos); ahora = (fun () -> ahora);
      log = (fun _ -> ()) }
  in
  let crear slug cuerpo =
    Printf.sprintf {|{"op": "crear", "slug": "%s", "titulo": "T", "resumen": "R", "cuerpo": "%s", "atomos": ["a-1"]}|}
      slug cuerpo
  in
  respuestas :=
    [ Ok (Printf.sprintf {|{"operaciones": [%s]}|} (crear "Mal" "c"));  (* rechazada: slug *)
      Ok (Printf.sprintf {|{"operaciones": [%s], "persona": ""}|} (crear "bien" "c"));  (* el reintento *)
      Ok "no es JSON";  (* segundo lote: mal... *)
      Ok {|{"operaciones": [{"op": "nada"}]}|};  (* ...y bien con el de por defecto *)
      Ok "# Persona\n\nNueva." ];
  let s =
    Ciclo.consolidar ef ~escenas_agente ~persona_agente ~lote:1 ~estado:Estado.inicial ~persona:"" []
      [ atomo ~ts:10 "a-1" "uno"; atomo ~ts:20 ~escena:"zeta" "a-2" "dos" ]
  in
  comprueba "pasada: la escena del reintento" (todas s.escenas = [ "bien" ] && s.escritas = [ "bien" ]);
  comprueba "pasada: el reintento lleva los rechazos"
    (List.exists (contiene "## Rechazos") !pedidos);
  comprueba "pasada: el que no es JSON, juzgado mal" (List.length !malos = 1);
  comprueba "pasada: persona" (s.persona = Some "# Persona\n\nNueva.");
  comprueba "pasada: cursor" (s.estado.cursor = 20 && s.estado.persona = Some ahora && s.estado.atomos_desde_persona = 0);
  comprueba "pasada: cinco encargos" (List.length s.encargos = 5 && s.fallidos = 0);
  (* Dos salidas inservibles: el lote queda sin hacer y el cursor quieto. *)
  respuestas := [ Ok "x"; Error "caído"; Ok "# P" ];
  let s =
    Ciclo.consolidar ef ~escenas_agente ~persona_agente ~estado:Estado.inicial ~persona:"" [] [ atomo ~ts:30 "a-3" "tres" ]
  in
  comprueba "lote fallido: cursor quieto" (s.fallidos = 1 && s.estado.cursor = 0 && s.estado.atomos_desde_persona = 0);
  comprueba "lotes por escena" (List.map List.length (Ciclo.lotes 2 [ atomo "a" "x"; atomo "b" "y"; atomo "c" "z" ]) = [ 2; 1 ])

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos\n" !fallos;
    exit 1)
