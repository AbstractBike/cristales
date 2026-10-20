(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red del núcleo de la forja y de la traducción de la Messages API. *)

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let contiene s sub =
  let n = String.length sub in
  let rec ir i = i + n <= String.length s && (String.sub s i n = sub || ir (i + 1)) in
  ir 0

let tarea n = Result.get_ok (Forja.Tarea.explicita n)
let pet ?(t = "mayus") e = { Forja.tarea = tarea t; plantilla = "Pon en mayúsculas."; entrada = e }

let politica =
  { Forja.Madurez.minimo = 4; contrastar_cada = 2; contrastes = 2; estabilidad = 1.0 }

(* Tareas *)
let () =
  comprueba "nombre explícito válido" (Result.is_ok (Forja.Tarea.explicita "fecha-es"));
  comprueba "nombre explícito con mayúsculas" (Result.is_error (Forja.Tarea.explicita "Fecha"));
  comprueba "nombre vacío" (Result.is_error (Forja.Tarea.explicita ""));
  let a = Forja.Tarea.de_plantilla "Clasifica el correo." in
  comprueba "misma plantilla, misma tarea" (a = Forja.Tarea.de_plantilla "Clasifica el correo.");
  comprueba "otra plantilla, otra tarea" (a <> Forja.Tarea.de_plantilla "Resume el correo.");
  comprueba "tarea derivada es un nombre válido"
    (Result.is_ok (Forja.Tarea.explicita (Forja.Tarea.to_string a)))

(* Una tarea nueva es líquida; contrasta una de cada dos; madura una vez. *)
let () =
  let cantera = Forja.Cantera.en_memoria () in
  let eventos = ref [] in
  let f =
    Forja.crear ~politica ~observar:(fun e -> eventos := e :: !eventos)
      ~vitrina:Forja.Vitrina.vacia ~cantera ()
  in
  let ronda e =
    match Forja.decidir f (pet e) with
    | Al_liquido { contrastar; defecto = None } ->
        let s = String.uppercase_ascii e in
        let contraste = if contrastar then Some s else None in
        (contrastar, Forja.aprender f (pet e) ?contraste s)
    | _ ->
        comprueba "tarea nueva va al líquido" false;
        (false, None)
  in
  let r = List.map ronda [ "a"; "b"; "c"; "d"; "e"; "f" ] in
  comprueba "contrasta las llamadas pares" (List.map fst r = [ false; true; false; true; false; true ]);
  let maduras = List.filter_map snd r in
  comprueba "madura exactamente una vez" (List.length maduras = 1);
  comprueba "madura al cumplir la política (4 muestras, 2 contrastes)"
    (snd (List.nth r 3) <> None);
  comprueba "la cantera lo guarda todo en orden"
    (List.map (fun (m : Forja.Cantera.muestra) -> m.entrada) (cantera.muestras (tarea "mayus"))
    = [ "a"; "b"; "c"; "d"; "e"; "f" ]);
  comprueba "eventos líquidos"
    (List.for_all (function Cristal.Por_liquido { etapa = "mayus"; _ } -> true | _ -> false) !eventos);
  (* La madurez sobrevive a un reinicio: otra forja sobre la misma cantera
     recupera el informe. *)
  let g = Forja.crear ~politica ~vitrina:Forja.Vitrina.vacia ~cantera () in
  let i = Forja.informe g (tarea "mayus") in
  comprueba "informe recuperado de la cantera" (i.muestras = 6 && i.contrastes = 3 && i.coincidencias = 3)

(* Un LLM inestable no madura. *)
let () =
  let f = Forja.crear ~politica ~vitrina:Forja.Vitrina.vacia ~cantera:(Forja.Cantera.en_memoria ()) () in
  let madura = ref false in
  for i = 1 to 20 do
    let e = string_of_int i in
    match Forja.decidir f (pet e) with
    | Al_liquido { contrastar; _ } ->
        let contraste = if contrastar then Some ("otra " ^ e) else None in
        if Forja.aprender f (pet e) ?contraste e <> None then madura := true
    | _ -> ()
  done;
  comprueba "lo que el LLM no repite no madura" (not !madura)

(* Vitrina: mixta y cristalina. *)
let () =
  let mayus =
    Cristal.cristal "mayus" Cristal.texto (fun s ->
        if String.exists (function '0' .. '9' -> true | _ -> false) s then Error "dígitos"
        else Ok (String.uppercase_ascii s))
  in
  let con estado = Forja.Vitrina.(vacia |> con (tarea "mayus") estado mayus) in
  let mixta = Forja.crear ~politica ~vitrina:(con `Mixta) ~cantera:(Forja.Cantera.en_memoria ()) () in
  comprueba "el cristal resuelve" (Forja.decidir mixta (pet "hola") = Por_cristal "HOLA");
  comprueba "defecto mixto cae al líquido"
    (Forja.decidir mixta (pet "a1") = Al_liquido { contrastar = false; defecto = Some "dígitos" });
  comprueba "una tarea en vitrina no vuelve a madurar"
    (List.for_all
       (fun _ -> Forja.aprender mixta (pet "a1") ~contraste:"A1" ~defecto:"dígitos" "A1" = None)
       (List.init 10 Fun.id));
  let cristalina =
    Forja.crear ~politica ~vitrina:(con `Cristalina) ~cantera:(Forja.Cantera.en_memoria ()) ()
  in
  comprueba "defecto cristalino es fallo"
    (Forja.decidir cristalina (pet "a1") = Fallo { etapa = "mayus"; motivo = "dígitos" });
  comprueba "otra tarea sigue líquida"
    (match Forja.decidir cristalina (pet ~t:"otra" "x") with Al_liquido _ -> true | _ -> false)

(* Semilla y nucleación. *)
let () =
  let muestras =
    [ { Forja.Cantera.tarea = tarea "mayus"; plantilla = "Pon en mayúsculas.";
        entrada = "hola"; salida = Some "HOLA"; contraste = None; defecto = None; ejemplos = false } ]
  in
  let prompt = Forja_http.Prompt.cristalizar in
  let n = Forja.Semilla.nucleacion ~prompt muestras in
  comprueba "la nucleación no deja huecos" (not (contiene n "{{"));
  comprueba "la nucleación lleva la plantilla" (contiene n "Pon en mayúsculas.");
  comprueba "la nucleación lleva los ejemplos" (contiene n "HOLA");
  let s = Forja.Semilla.markdown (tarea "mayus") Forja.Madurez.vacio muestras in
  comprueba "la semilla se titula con la tarea" (contiene s "# Semilla: mayus")

(* Messages API. *)
let () =
  let j = Yojson.Safe.from_string in
  let p ?tarea s = Result.map fst (Forja_http.Anthropic.peticion ~tarea (j s)) in
  (match p {|{"model":"m","system":"Pon en mayúsculas.","messages":[{"role":"user","content":"hola"}]}|} with
  | Ok { tarea; entrada; plantilla } ->
      comprueba "tarea de la plantilla" (tarea = Forja.Tarea.de_plantilla "Pon en mayúsculas.");
      comprueba "entrada" (entrada = "hola" && plantilla = "Pon en mayúsculas.")
  | Error e -> comprueba ("petición simple: " ^ e) false);
  comprueba "bloques de texto"
    (match
       p {|{"system":[{"type":"text","text":"S"}],"messages":[{"role":"user","content":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}]}|}
     with
    | Ok { entrada = "a\nb"; plantilla = "S"; _ } -> true
    | _ -> false);
  comprueba "tarea explícita sin system"
    (match p ~tarea:"mayus" {|{"messages":[{"role":"user","content":"x"}]}|} with
    | Ok { tarea = t; _ } -> t = tarea "mayus"
    | Error _ -> false);
  let paso s = Result.is_error (p s) in
  comprueba "sin system ni tarea es paso" (paso {|{"messages":[{"role":"user","content":"x"}]}|});
  comprueba "varios turnos es paso"
    (paso {|{"system":"S","messages":[{"role":"user","content":"x"},{"role":"assistant","content":"y"},{"role":"user","content":"z"}]}|});
  comprueba "con tarea explícita, los turnos previos son ejemplos"
    (match
       p ~tarea:"mayus"
         {|{"system":"S","messages":[{"role":"user","content":"x"},{"role":"assistant","content":"X"},{"role":"user","content":"z"}]}|}
     with
    | Ok { entrada = "z"; plantilla = "S"; _ } -> true
    | _ -> false);
  comprueba "con tarea explícita, una conversación que no alterna es paso"
    (Result.is_error
       (p ~tarea:"mayus"
          {|{"system":"S","messages":[{"role":"user","content":"x"},{"role":"user","content":"z"}]}|}));
  comprueba "con tarea explícita, acabar en el asistente es paso"
    (Result.is_error
       (p ~tarea:"mayus"
          {|{"system":"S","messages":[{"role":"user","content":"x"},{"role":"assistant","content":"X"}]}|}));
  comprueba "streaming es paso" (paso {|{"system":"S","stream":true,"messages":[{"role":"user","content":"x"}]}|});
  comprueba "herramientas sin tool_choice forzado es paso"
    (paso {|{"system":"S","tools":[{"name":"t"}],"messages":[{"role":"user","content":"x"}]}|});
  comprueba "imagen es paso"
    (paso {|{"system":"S","messages":[{"role":"user","content":[{"type":"image","source":{}}]}]}|});
  comprueba "texto de end_turn"
    (Forja_http.Anthropic.texto (j {|{"stop_reason":"end_turn","content":[{"type":"text","text":"HOLA"}]}|})
    = Some "HOLA");
  comprueba "max_tokens no es una salida"
    (Forja_http.Anthropic.texto (j {|{"stop_reason":"max_tokens","content":[{"type":"text","text":"HO"}]}|})
    = None);
  comprueba "respuesta del cristal es legible como respuesta"
    (Forja_http.Anthropic.texto (Result.get_ok (Forja_http.Anthropic.respuesta ~modelo:"m" Texto "HOLA")) = Some "HOLA")

(* Herramienta forzada: la forma de las pipelines con salida estructurada. *)
let () =
  let module A = Forja_http.Anthropic in
  let j = Yojson.Safe.from_string in
  let pet herr =
    Printf.sprintf
      {|{"model":"m","system":"Extrae.","tools":[{"name":"otra","input_schema":{}},{"name":"extrae","input_schema":{"type":"object"}}],"tool_choice":{"type":"tool","name":"%s"},"messages":[{"role":"user","content":"x"}]}|}
      herr
  in
  (match A.peticion ~tarea:None (j (pet "extrae")) with
  | Ok (p, A.Herramienta "extrae") ->
      comprueba "la plantilla lleva system y herramienta"
        (contiene p.plantilla "Extrae." && contiene p.plantilla {|"name":"extrae"|} && not (contiene p.plantilla "otra"))
  | _ -> comprueba "herramienta forzada es tarea" false);
  comprueba "otra herramienta, otra tarea"
    (match (A.peticion ~tarea:None (j (pet "extrae")), A.peticion ~tarea:None (j (pet "otra"))) with
    | Ok (a, _), Ok (b, _) -> a.tarea <> b.tarea
    | _ -> false);
  comprueba "tool_choice a una herramienta que no está es paso"
    (Result.is_error (A.peticion ~tarea:None (j (pet "nada"))));
  comprueba "tool_choice auto es paso"
    (Result.is_error
       (A.peticion ~tarea:None
          (j {|{"system":"S","tools":[{"name":"t"}],"tool_choice":{"type":"auto"},"messages":[{"role":"user","content":"x"}]}|})));
  let resp orden =
    j (Printf.sprintf {|{"stop_reason":"tool_use","content":[{"type":"text","text":"va"},{"type":"tool_use","id":"t1","name":"extrae","input":%s}]}|} orden)
  in
  let a = A.salida (A.Herramienta "extrae") (resp {|{"b":1,"a":{"d":2,"c":3}}|}) in
  let b = A.salida (A.Herramienta "extrae") (resp {|{"a":{"c":3,"d":2},"b":1}|}) in
  comprueba "salida de herramienta canónica" (a = Some {|{"a":{"c":3,"d":2},"b":1}|} && a = b);
  comprueba "otra herramienta no es salida" (A.salida (A.Herramienta "otra") (resp "{}") = None);
  comprueba "end_turn no es salida de herramienta"
    (A.salida (A.Herramienta "extrae") (j {|{"stop_reason":"end_turn","content":[{"type":"text","text":"x"}]}|}) = None);
  (match A.respuesta ~modelo:"m" (A.Herramienta "extrae") {|{"b":1}|} with
  | Ok r -> comprueba "respuesta del cristal es tool_use legible" (A.salida (A.Herramienta "extrae") r = Some {|{"b":1}|})
  | Error e -> comprueba ("respuesta de herramienta: " ^ e) false);
  comprueba "cristal que no da JSON es error"
    (Result.is_error (A.respuesta ~modelo:"m" (A.Herramienta "extrae") "no es json")
    && Result.is_error (A.respuesta ~modelo:"m" (A.Herramienta "extrae") "[1]"))

(* Filas de GreptimeDB. *)
let () =
  let r =
    Yojson.Safe.from_string
      {|{"output":[{"records":{"schema":{},"rows":[
          ["mayus","P","hola","HOLA",true,"HOLA","",true],
          ["mayus","P","a1","A1",false,"","dígitos",null],
          ["mayus","","b2","",false,"","dígitos",false],
          ["mayus","P","c3","C3",false,"","",true,true],
          ["mayus","P","d4","D4",false,"","",true,null]]}}]}|}
  in
  match Forja_http.Cantera_greptime.filas r with
  | [ a; b; c; d; e ] ->
      comprueba "fila con ejemplos" (d.ejemplos && not e.ejemplos && not a.ejemplos);
      comprueba "fila contrastada" (a.contraste = Some "HOLA" && a.defecto = None);
      comprueba "fila con defecto" (b.contraste = None && b.defecto = Some "dígitos");
      comprueba "fila de antes de respondida: vino del LLM" (b.salida = Some "A1");
      comprueba "fila de un defecto por MCP: sin salida" (c.salida = None && c.defecto = Some "dígitos")
  | _ -> comprueba "cinco filas de greptime" false

(* Un defecto directo (forja-mcp): no cuenta para la madurez y la semilla lo dice. *)
let () =
  let m = Forja.Cantera.defecto_directo (tarea "mayus") ~entrada:"b2" "dígitos" in
  comprueba "sin salida no suma" (Forja.Madurez.sumar Forja.Madurez.vacio m = Forja.Madurez.vacio);
  let llm = { m with plantilla = "Pon en mayúsculas."; entrada = "a"; salida = Some "A"; defecto = None } in
  let s = Forja.Semilla.markdown (tarea "mayus") Forja.Madurez.vacio [ m; llm ] in
  comprueba "la semilla toma la plantilla de quien la tenga" (contiene s "Pon en mayúsculas.");
  comprueba "la semilla dice que no hubo respuesta" (contiene s "Sin respuesta")

(* Campo a campo: el LLM repite el salario y no las habilidades. *)
let () =
  let muestra i =
    let s = Printf.sprintf {|{"salario":%d,"skills":["a"]}|} i
    and c = Printf.sprintf {|{"salario":%d,"skills":["b"]}|} i in
    { Forja.Cantera.tarea = tarea "oferta"; plantilla = "Extrae."; entrada = string_of_int i;
      salida = Some s; contraste = Some c; defecto = None; ejemplos = false }
  in
  let ms = List.init 4 muestra in
  let i = Forja.Madurez.informe ms in
  comprueba "estructurados cuenta los contrastes de objetos" (i.estructurados = 4);
  comprueba "el objeto entero no coincide nunca" (i.coincidencias = 0);
  comprueba "por campo" (i.campos = [ ("salario", 4); ("skills", 0) ]);
  comprueba "no madura entera" (not (Forja.Madurez.entera politica i));
  comprueba "el salario está maduro" (Forja.Madurez.campos_maduros politica i = [ "salario" ]);
  comprueba "con un campo maduro, madura" (Forja.Madurez.madura politica i);
  comprueba "sin muestras bastantes, ningún campo"
    (Forja.Madurez.campos_maduros politica (Forja.Madurez.informe [ muestra 1 ]) = []);
  let texto = Forja.Madurez.informe [ { (muestra 1) with salida = Some "hola"; contraste = Some "hola" } ] in
  comprueba "el texto no tiene campos" (texto.estructurados = 0 && texto.campos = []);
  let s = Forja.Semilla.markdown (tarea "oferta") i ms in
  comprueba "la semilla trae los campos" (contiene s "## Campos" && contiene s "`salario`: 4 de 4");
  comprueba "y dice que el cristal puede ser parcial" (contiene s "parcial");
  let n = Forja.Semilla.nucleacion ~prompt:"{{descripción en una frase}} / {{tipo de salida}}" ms in
  comprueba "la nucleación también" (contiene n "`skills`: 0 de 4" && contiene n "solo los que sepas")

(* El esquema reducido a lo que falta, por las dos APIs. *)
let () =
  let j = Yojson.Safe.from_string in
  let a =
    j {|{"tools":[{"name":"otra","input_schema":{"properties":{"z":{}}}},{"name":"x","input_schema":{"type":"object","properties":{"a":{},"b":{}},"required":["a","b"]}}],"tool_choice":{"type":"tool","name":"x"}}|}
  in
  comprueba "anthropic: campos de la forzada" (Forja_http.Anthropic.campos a = [ "a"; "b" ]);
  comprueba "anthropic: sin forzada, ninguno"
    (Forja_http.Anthropic.campos (j {|{"tools":[{"name":"x"}]}|}) = []);
  let r = Forja_http.Anthropic.restringir a [ "b" ] in
  comprueba "anthropic: solo b"
    (Yojson.Safe.Util.(r |> member "tools" |> index 1 |> member "input_schema")
    = j {|{"type":"object","properties":{"b":{}},"required":["b"]}|});
  comprueba "anthropic: la otra herramienta no cambia"
    (Yojson.Safe.Util.(r |> member "tools" |> index 0) = Yojson.Safe.Util.(a |> member "tools" |> index 0));
  let o =
    j {|{"response_format":{"type":"json_schema","json_schema":{"name":"x","strict":true,"schema":{"type":"object","properties":{"a":{},"b":{}},"required":["a","b"],"additionalProperties":false}}}}|}
  in
  comprueba "openai: campos" (Forja_http.Openai.campos o = [ "a"; "b" ]);
  comprueba "openai: solo a"
    (Forja_http.Openai.restringir o [ "a" ]
    = j {|{"response_format":{"type":"json_schema","json_schema":{"name":"x","strict":true,"schema":{"type":"object","properties":{"a":{}},"required":["a"],"additionalProperties":false}}}}|})

(* Chat Completions: la forma de buzon-kt sobre llama-server. *)
let () =
  let module O = Forja_http.Openai in
  let j = Yojson.Safe.from_string in
  let p ?tarea s = Result.map fst (O.peticion ~tarea (j s)) in
  let esquema = {|"response_format":{"type":"json_schema","json_schema":{"name":"x","schema":{"type":"object"}}}|} in
  (match
     p (Printf.sprintf {|{"messages":[{"role":"system","content":"Extrae."},{"role":"user","content":"hola"}],%s}|} esquema)
   with
  | Ok { entrada; plantilla; _ } ->
      comprueba "openai: entrada" (entrada = "hola");
      comprueba "openai: el esquema entra en la plantilla"
        (plantilla = {|Extrae.

## Esquema

{"name":"x","schema":{"type":"object"}}|})
  | Error e -> comprueba ("openai: petición con esquema: " ^ e) false);
  comprueba "openai: texto sin response_format"
    (match p {|{"messages":[{"role":"system","content":"S"},{"role":"user","content":"x"}]}|} with
    | Ok { plantilla = "S"; _ } -> true
    | _ -> false);
  let paso s = Result.is_error (p s) in
  comprueba "openai: sin system ni tarea es paso" (paso {|{"messages":[{"role":"user","content":"x"}]}|});
  comprueba "openai: varios turnos es paso"
    (paso {|{"messages":[{"role":"system","content":"S"},{"role":"user","content":"x"},{"role":"assistant","content":"y"},{"role":"user","content":"z"}]}|});
  comprueba "openai: con tarea explícita, los turnos previos son ejemplos"
    (match
       p ~tarea:"mayus"
         {|{"messages":[{"role":"system","content":"S"},{"role":"user","content":"x"},{"role":"assistant","content":"y"},{"role":"user","content":"z"}]}|}
     with
    | Ok { entrada = "z"; plantilla = "S"; _ } -> true
    | _ -> false);
  comprueba "openai: ejemplos sin system"
    (match
       p ~tarea:"mayus" {|{"messages":[{"role":"user","content":"x"},{"role":"assistant","content":"y"},{"role":"user","content":"z"}]}|}
     with
    | Ok { entrada = "z"; plantilla = ""; _ } -> true
    | _ -> false);
  comprueba "openai: herramientas es paso"
    (paso {|{"tools":[{}],"messages":[{"role":"system","content":"S"},{"role":"user","content":"x"}]}|});
  comprueba "openai: json_object sin esquema es paso"
    (paso {|{"response_format":{"type":"json_object"},"messages":[{"role":"system","content":"S"},{"role":"user","content":"x"}]}|});
  let respuesta fin c =
    j (Printf.sprintf {|{"choices":[{"finish_reason":"%s","message":{"role":"assistant","content":%S}}]}|} fin c)
  in
  comprueba "openai: el objeto en forma canónica"
    (O.salida Esquema (respuesta "stop" {|{"b":1,"a":2}|}) = Some {|{"a":2,"b":1}|});
  comprueba "openai: length no es una salida" (O.salida Texto (respuesta "length" "HO") = None);
  comprueba "openai: un contenido que no es objeto no es salida estructurada"
    (O.salida Esquema (respuesta "stop" "hola") = None);
  comprueba "openai: el cristal sale legible"
    (O.salida Esquema (Result.get_ok (O.respuesta ~modelo:"m" Esquema {|{"a":1}|})) = Some {|{"a":1}|});
  comprueba "openai: cristal sin JSON es error" (Result.is_error (O.respuesta ~modelo:"m" Esquema "no"))

(* Métricas: el texto de Prometheus. *)
let () =
  let module M = Forja_http.Metricas in
  let m = M.crear () in
  M.contador m "x_total" ~ayuda:"Equis.";
  M.histograma m "h_segundos" ~ayuda:"Hache." ~cubos:[ 0.1; 1. ];
  M.sumar m "x_total" ~etiquetas:[ ("b", "2"); ("a", "1") ] 1.;
  M.sumar m "x_total" ~etiquetas:[ ("a", "1"); ("b", "2") ] 2.;
  M.sumar m "x_total" ~etiquetas:[ ("a", "comilla \"y\\ barra") ] 1.;
  M.sumar m "no_declarado_total" 1.;
  List.iter (M.observar m "h_segundos") [ 0.05; 0.5; 5. ];
  let t = M.servir m [ { M.nombre = "g"; ayuda = "Ge."; valores = [ ([ ("z", "1"); ("y", "2") ], 0.5) ] } ] in
  comprueba "contador con su tipo" (contiene t "# TYPE x_total counter");
  comprueba "mismas etiquetas en otro orden, misma serie" (contiene t {|x_total{a="1",b="2"} 3|});
  comprueba "escapa comillas y barras" (contiene t {|x_total{a="comilla \"y\\ barra"} 1|});
  comprueba "lo no declarado no sale" (not (contiene t "no_declarado"));
  comprueba "cubos acumulados"
    (contiene t {|h_segundos_bucket{le="0.1"} 1|} && contiene t {|h_segundos_bucket{le="1"} 2|}
    && contiene t {|h_segundos_bucket{le="+Inf"} 3|});
  comprueba "suma y cuenta" (contiene t "h_segundos_sum 5.55" && contiene t "h_segundos_count 3");
  comprueba "medidas, con etiquetas ordenadas" (contiene t "# TYPE g gauge" && contiene t {|g{y="2",z="1"} 0.5|})

(* Ejemplos (few-shot): la muestra vale, su contraste no mide la madurez; y
   el contraste se pide sin ellos. *)
let () =
  let m =
    { Forja.Cantera.tarea = tarea "mayus"; plantilla = "P"; entrada = "a"; salida = Some "A";
      contraste = Some "A"; defecto = None; ejemplos = true }
  in
  let i = Forja.Madurez.sumar Forja.Madurez.vacio m in
  comprueba "con ejemplos, muestra sin contraste" (i.muestras = 1 && i.contrastes = 0 && i.coincidencias = 0);
  let i = Forja.Madurez.sumar Forja.Madurez.vacio { m with ejemplos = false } in
  comprueba "sin ejemplos, contraste" (i.contrastes = 1 && i.coincidencias = 1);
  let j = Yojson.Safe.from_string in
  let a =
    j {|{"system":"S","messages":[{"role":"user","content":"x"},{"role":"assistant","content":"X"},{"role":"user","content":"z"}]}|}
  in
  comprueba "anthropic: con ejemplos" (Forja_http.Anthropic.con_ejemplos a);
  comprueba "anthropic: sin ejemplos, el último"
    (Forja_http.Anthropic.sin_ejemplos a
    = j {|{"system":"S","messages":[{"role":"user","content":"z"}]}|});
  comprueba "anthropic: sin ejemplos no tiene"
    (not (Forja_http.Anthropic.con_ejemplos (Forja_http.Anthropic.sin_ejemplos a)));
  let o =
    j {|{"messages":[{"role":"system","content":"S"},{"role":"user","content":"x"},{"role":"assistant","content":"X"},{"role":"user","content":"z"}]}|}
  in
  comprueba "openai: con ejemplos" (Forja_http.Openai.con_ejemplos o);
  comprueba "openai: sin ejemplos, el system y el último"
    (Forja_http.Openai.sin_ejemplos o
    = j {|{"messages":[{"role":"system","content":"S"},{"role":"user","content":"z"}]}|});
  comprueba "openai: system y usuario no son ejemplos"
    (not (Forja_http.Openai.con_ejemplos (Forja_http.Openai.sin_ejemplos o)))

let () = if !fallos > 0 then exit 1
