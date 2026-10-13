(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red de la agencia: la elección de modelo, el servidor MCP con un LLM
   falso, las APIs y las filas de GreptimeDB. *)

open Agencia

let fallos = ref 0

let contiene s sub =
  let n = String.length sub in
  let rec ir i = i + n <= String.length s && (String.sub s i n = sub || ir (i + 1)) in
  ir 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let modelo s = Result.get_ok (Modelo.de_texto s)
let barato = modelo "openai:qwen3"
let medio = modelo "claude-haiku-5-5"
let caro = modelo "claude-opus-5-5"

let agente =
  Result.get_ok
    (Agente.crear ~nombre:"resumir" ~instrucciones:"Resume en una línea." ~escalera:[ barato; medio; caro ] ())

let contador = ref 0

let encargo ?(a = agente) ?(salida = Ok "x") ?veredicto m =
  incr contador;
  { Encargo.id = Printf.sprintf "%016x" !contador;
    agente = a.nombre;
    version = Agente.version a;
    modelo = Modelo.to_string m;
    motivo = "";
    fuente = "directo";
    entrada = "e";
    salida;
    ms = 10;
    tokens_entrada = 1;
    tokens_salida = 1;
    veredicto;
    nota = "";
    corregida = None }

let elige es = (elegir agente es).modelo

let () =
  (* Modelos y agentes. *)
  comprueba "openai: es de Chat Completions" (barato.api = Openai && barato.nombre = "qwen3");
  comprueba "ida y vuelta del nombre" (Modelo.to_string barato = "openai:qwen3");
  comprueba "modelo vacío" (Result.is_error (Modelo.de_texto "openai:"));
  comprueba "por defecto, el más capaz" (agente.defecto = caro);
  comprueba "escalera vacía"
    (Result.is_error (Agente.crear ~nombre:"x" ~instrucciones:"i" ~escalera:[] ()));
  comprueba "defecto fuera de la escalera"
    (Result.is_error (Agente.crear ~nombre:"x" ~instrucciones:"i" ~escalera:[ barato ] ~defecto:caro ()));
  comprueba "nombre de tarea" (Result.is_error (Agente.crear ~nombre:"Con Espacios" ~instrucciones:"i" ~escalera:[ caro ] ()));
  (* Elección. *)
  comprueba "sin historial, el de por defecto" (elige [] = caro);
  let bien m = encargo ~veredicto:Bien m and mal m = encargo ~veredicto:Mal m in
  comprueba "el quinto explora el más barato" (elige [ bien caro; bien caro; bien caro; bien caro ] = barato);
  let barato_bien = [ bien barato; bien barato; bien barato ] in
  comprueba "el más barato fiable" (elige barato_bien = barato);
  let barato_mal = [ mal barato; encargo ~salida:(Error "caído") barato; mal barato ] in
  comprueba "un descartado no se explora"
    (elige (barato_mal @ [ bien caro ]) = medio);
  comprueba "medio fiable gana a caro"
    (elige (barato_mal @ [ bien medio; bien medio; bien medio ]) = medio);
  let cs = cuentas agente barato_mal in
  comprueba "los errores cuentan como mal"
    (match cs with c :: _ -> c.errores = 1 && c.juzgados = 3 && c.nivel = Descartado | [] -> false);
  comprueba "lo que no llegó al modelo no cuenta"
    (elige ([ { (encargo ~salida:(Error "caído") barato) with fuente = sin_respuesta } ] @ barato_bien) = barato
    && (List.hd (cuentas agente [ { (encargo ~salida:(Error "caído") barato) with fuente = sin_respuesta } ])).juzgados = 0);
  let caro_mal = [ mal caro; mal caro; mal caro ] in
  comprueba "defecto descartado y nada encima: el más capaz por debajo" (elige caro_mal = medio);
  comprueba "todos descartados: el más capaz"
    (elige (barato_mal @ [ mal medio; mal medio; mal medio ] @ caro_mal) = caro);
  let otro = { agente with instrucciones = "Otra cosa." } in
  comprueba "otras instrucciones, otro historial" ((elegir otro barato_bien).modelo = caro);
  (* El servidor MCP, con un LLM falso que dice qué modelo contestó. *)
  let archivo = Archivo.en_memoria () in
  let llamadas = ref [] in
  let ids = ref 0 in
  let ef =
    { Agencia_mcp.archivo;
      llamar =
        (fun a m e ->
          llamadas := Modelo.to_string m :: !llamadas;
          { salida = (if e = "falla" then Error "500" else Ok (a.instrucciones ^ " " ^ e ^ " por " ^ m.nombre));
            fuente = "directo"; ms = 5; tokens_entrada = 3; tokens_salida = 4 });
      id = (fun () -> incr ids; Printf.sprintf "%016x" !ids);
      escalera = [ medio; caro ];
      politica = Politica.por_defecto }
  in
  let s = Agencia_mcp.servidor ef in
  let pide metodo params =
    Option.get
      (Mcp_rpc.responder s
         (`Assoc [ ("jsonrpc", `String "2.0"); ("id", `Int 1); ("method", `String metodo); ("params", params) ]))
  in
  let llama nombre args = pide "tools/call" (`Assoc [ ("name", `String nombre); ("arguments", args) ]) in
  let campo ruta j = List.fold_left (fun j k -> Yojson.Safe.Util.member k j) j ruta in
  let textos r =
    match campo [ "result"; "content" ] r with
    | `List bs -> List.map (fun b -> Yojson.Safe.Util.(b |> member "text" |> to_string)) bs
    | _ -> []
  in
  let nombres () =
    match campo [ "result"; "tools" ] (pide "tools/list" `Null) with
    | `List ts -> List.map (fun t -> Yojson.Safe.Util.(t |> member "name" |> to_string)) ts
    | _ -> []
  in
  comprueba "cinco fijas sin agentes" (List.length (nombres ()) = 5);
  let r =
    llama "agencia_crear"
      (`Assoc [ ("nombre", `String "titular"); ("instrucciones", `String "Titula."); ("descripcion", `String "Titulares.") ])
  in
  comprueba "crear responde" (campo [ "result"; "isError" ] r = `Bool false);
  comprueba "el agente es una herramienta" (List.mem "titular" (nombres ()));
  comprueba "crear con escalera mala"
    (campo [ "error"; "code" ]
       (llama "agencia_crear"
          (`Assoc [ ("nombre", `String "x"); ("instrucciones", `String "i"); ("escalera", `List [ `Int 1 ]) ]))
    = `Int (-32602));
  let r = llama "agencia_encargar" (`Assoc [ ("agente", `String "titular"); ("entrada", `String "hola") ]) in
  comprueba "el encargo va al de por defecto" (List.hd (textos r) = "Titula. hola por claude-opus-5-5");
  comprueba "y dice cómo juzgarlo"
    (match textos r with [ _; meta ] -> String.length meta > 0 && String.sub meta 0 8 = "encargo " | _ -> false);
  let r = llama "titular" (`Assoc [ ("entrada", `String "adiós"); ("modelo", `String "claude-haiku-5-5") ]) in
  comprueba "por la herramienta del agente, con modelo pedido"
    (List.hd (textos r) = "Titula. adiós por claude-haiku-5-5");
  let r = llama "titular" (`Assoc [ ("entrada", `String "falla") ]) in
  comprueba "un error del modelo es isError" (campo [ "result"; "isError" ] r = `Bool true);
  comprueba "y queda en el archivo"
    (List.length (archivo.historial (Result.get_ok (Forja.Tarea.explicita "titular"))) = 3);
  let r =
    llama "agencia_juzgar"
      (`Assoc [ ("agente", `String "titular"); ("id", `String "0000000000000001"); ("veredicto", `String "bien") ])
  in
  comprueba "juzgar responde" (campo [ "result"; "isError" ] r = `Bool false);
  comprueba "el veredicto queda"
    (match archivo.historial (Result.get_ok (Forja.Tarea.explicita "titular")) with
    | e :: _ -> e.veredicto = Some Bien
    | [] -> false);
  ignore
    (llama "agencia_juzgar"
       (`Assoc
         [ ("agente", `String "titular"); ("id", `String "0000000000000002"); ("veredicto", `String "mal");
           ("nota", `String "largo"); ("salida_corregida", `String "Adiós") ]));
  comprueba "juzgar con salida corregida"
    (match archivo.historial (Result.get_ok (Forja.Tarea.explicita "titular")) with
    | _ :: e :: _ -> e.corregida = Some "Adiós" && e.veredicto = Some Mal
    | _ -> false);
  comprueba "juzgar un id ajeno"
    (campo [ "error"; "code" ]
       (llama "agencia_juzgar"
          (`Assoc [ ("agente", `String "titular"); ("id", `String "ffffffffffffffff"); ("veredicto", `String "bien") ]))
    = `Int (-32602));
  comprueba "veredicto raro"
    (campo [ "error"; "code" ]
       (llama "agencia_juzgar"
          (`Assoc [ ("agente", `String "titular"); ("id", `String "0000000000000001"); ("veredicto", `String "regular") ]))
    = `Int (-32602));
  let h = llama "agencia_historico" (`Assoc [ ("agente", `String "titular"); ("ultimos", `Int 2) ]) in
  (match Yojson.Safe.from_string (List.hd (textos h)) with
  | j ->
      comprueba "histórico: cuántos" (campo [ "encargos" ] j = `Int 3);
      comprueba "histórico: los últimos, el más nuevo primero"
        (match campo [ "ultimos" ] j with `List [ a; _ ] -> campo [ "error" ] a = `String "500" | _ -> false)
  | exception _ -> comprueba "histórico en JSON" false);
  comprueba "agente inexistente"
    (campo [ "error"; "code" ] (llama "nadie" (`Assoc [ ("entrada", `String "x") ])) = `Int (-32602));
  let i = campo [ "result"; "instructions" ] (pide "initialize" (`Assoc [])) in
  comprueba "las instrucciones nombran los agentes"
    (match i with `String s -> List.exists (fun l -> l = "Agentes: titular (Titulares.).") (String.split_on_char '\n' s) | _ -> false);
  (* La vista: la API de solo lectura de agencia.pin, sobre el mismo archivo. *)
  let vista meth ruta query = Agencia_vista.atender archivo Politica.por_defecto ~meth ~ruta ~query in
  let cuerpo_de = function Some (r : Agencia_vista.respuesta) -> (r.estado, Yojson.Safe.from_string r.cuerpo) | None -> (0, `Null) in
  (match cuerpo_de (vista `GET "/agencia/agentes" []) with
  | 200, `List [ a ] -> comprueba "vista: los agentes, con su siguiente" (campo [ "nombre" ] a = `String "titular" && campo [ "siguiente"; "modelo" ] a <> `Null)
  | _ -> comprueba "vista: un agente" false);
  (match cuerpo_de (vista `GET "/agencia/agentes/titular" [ ("encargos", [ "1" ]) ]) with
  | 200, j ->
      comprueba "vista: histórico con instrucciones" (campo [ "agente"; "instrucciones" ] j <> `Null);
      comprueba "vista: solo los pedidos" (match campo [ "ultimos" ] j with `List [ _ ] -> true | _ -> false)
  | _ -> comprueba "vista: histórico" false);
  comprueba "vista: agente inexistente" (fst (cuerpo_de (vista `GET "/agencia/agentes/nadie" [])) = 404);
  comprueba "vista: solo lectura" (fst (cuerpo_de (vista `POST "/agencia/agentes" [])) = 405);
  comprueba "vista: política" (fst (cuerpo_de (vista `GET "/agencia/politica" [])) = 200);
  comprueba "vista: lo demás no es suyo" (vista `GET "/forja/tareas" [] = None);
  (* Las APIs. *)
  let ruta, cuerpo = Agencia_http.Llm.peticion agente caro "hola" in
  comprueba "Messages" (ruta = "/v1/messages" && campo [ "system" ] cuerpo = `String "Resume en una línea.");
  let ruta, _ = Agencia_http.Llm.peticion agente barato "hola" in
  comprueba "Chat Completions" (ruta = "/v1/chat/completions");
  comprueba "leer Messages"
    (Agencia_http.Llm.leer Anthropic
       (Yojson.Safe.from_string
          {|{"content":[{"type":"thinking","thinking":"…"},{"type":"text","text":"hola"}],"usage":{"input_tokens":7,"output_tokens":2}}|})
    = Ok ("hola", 7, 2));
  comprueba "leer Chat Completions"
    (Agencia_http.Llm.leer Openai
       (Yojson.Safe.from_string
          {|{"choices":[{"message":{"role":"assistant","content":"hola"}}],"usage":{"prompt_tokens":5,"completion_tokens":1}}|})
    = Ok ("hola", 5, 1));
  comprueba "sin texto" (Result.is_error (Agencia_http.Llm.leer Openai (`Assoc [])));
  (* Las filas de GreptimeDB, ida y vuelta. *)
  let module G = Agencia_http.Archivo_greptime in
  comprueba "fila de agente" (G.agente (G.fila_agente agente) = Some agente);
  List.iter
    (fun e -> comprueba "fila de encargo" (G.encargo (G.fila_encargo e) = Some { e with veredicto = None }))
    [ encargo caro; encargo ~salida:(Error "caído") ~veredicto:Mal barato ];
  (* Las medidas: cada encargo y cada veredicto, un punto con etiquetas. *)
  let module M = Agencia_http.Medidas in
  let e = { (encargo medio) with fuente = "liquido"; ms = 1200; tokens_entrada = 300; tokens_salida = 50 } in
  comprueba "línea de un encargo"
    (M.linea (M.encargo e)
    = Printf.sprintf
        "agencia_encargo,agente=resumir,version=%s,modelo=claude-haiku-5-5,fuente=liquido,resultado=ok \
         n=1i,ms=1200i,tokens_entrada=300i,tokens_salida=50i"
        (Agente.version agente));
  comprueba "un error es resultado=error"
    (List.assoc "resultado" (M.encargo (encargo ~salida:(Error "x") caro)).etiquetas = "error");
  comprueba "escapa comas, iguales y espacios; sin etiquetas vacías"
    (M.linea { M.tabla = "t"; etiquetas = [ ("a", "x,y=z w"); ("b", "") ]; campos = [ ("n", 1) ]; ms = Some 5. }
    = {|t,a=x\,y\=z\ w n=1i 5|});
  let puntos = ref [] in
  let archivo = Archivo.en_memoria () in
  let medido = M.con_medidas (fun p -> puntos := p :: !puntos) archivo in
  medido.registrar e;
  medido.juzgar agente.nombre e.id Bien "";
  (match List.rev !puntos with
  | [ a; b ] ->
      comprueba "registrar mide el encargo" (a.tabla = "agencia_encargo");
      comprueba "juzgar mide el veredicto, con su modelo"
        (b.tabla = "agencia_veredicto"
        && List.assoc "modelo" b.etiquetas = "claude-haiku-5-5"
        && List.assoc "veredicto" b.etiquetas = "bien")
  | _ -> comprueba "dos puntos" false);
  comprueba "y el archivo lo guarda igual"
    (match archivo.historial agente.nombre with [ x ] -> x.veredicto = Some Bien | _ -> false);
  (* Un veredicto de otra sesión: el modelo, del historial. *)
  puntos := [];
  let otro = M.con_medidas (fun p -> puntos := p :: !puntos) archivo in
  otro.juzgar agente.nombre e.id Mal "";
  comprueba "modelo del historial"
    (match !puntos with [ p ] -> List.assoc "modelo" p.etiquetas = "claude-haiku-5-5" | _ -> false)

(* Ejemplos y advertencias: qué encargos previos acompañan al siguiente. *)
let () =
  let con ?(a = agente) ?veredicto ?(nota = "") ?(salida = Ok "s") entrada =
    { (encargo ~a ~salida ?veredicto caro) with entrada; nota }
  in
  let elige ?parametros ?(a = agente) es e = Ejemplos.elegir ?parametros a es e in
  comprueba "similitud: iguales 1, disjuntos 0"
    (Ejemplos.similitud "Hola, Mundo" "mundo hola" = 1. && Ejemplos.similitud "uno dos" "tres" = 0.);
  comprueba "similitud: UTF-8 es una palabra" (Ejemplos.similitud "canción" "canción larga" = 0.5);
  let es =
    [ con ~veredicto:Bien ~salida:(Ok "gatos") "los gatos duermen";
      con ~veredicto:Mal ~nota:"demasiado largo" "los perros ladran";
      con ~veredicto:Bien ~salida:(Ok "perros") "los perros ladran mucho";
      con "los perros sin juzgar";
      con ~veredicto:Bien ~salida:(Error "caído") "los perros con error";
      { (con ~veredicto:Bien "los perros de otra versión") with version = "000000000000" };
      con ~veredicto:Bien ~salida:(Ok "pájaros") "los pájaros cantan";
      con ~veredicto:Bien ~salida:(Ok "peces") "los peces nadan" ]
  in
  let c = elige es "los perros ladran fuerte" in
  comprueba "solo bien, con salida y de la versión actual; el más parecido al final"
    (match c.pares with
    | [ _; _; ("los perros ladran mucho", "perros") ] -> true
    | _ -> false);
  comprueba "a igualdad de parecido, los más recientes"
    (List.map fst c.pares = [ "los pájaros cantan"; "los peces nadan"; "los perros ladran mucho" ]);
  comprueba "advertencias de los mal" (c.advertencias = [ "demasiado largo" ]);
  comprueba "determinista" (elige es "los perros ladran fuerte" = c);
  comprueba "ejemplos = 0 lo apaga"
    (Ejemplos.es_vacio (elige ~a:{ agente with ejemplos = 0 } es "los perros ladran fuerte"));
  comprueba "a lo sumo los del agente"
    (List.length (elige ~a:{ agente with ejemplos = 1 } es "los perros ladran fuerte").pares = 1);
  let repetidos = [ con ~veredicto:Bien ~salida:(Ok "1") "igual"; con ~veredicto:Bien ~salida:(Ok "2") "igual" ] in
  comprueba "una entrada repetida, la última vez" ((elige repetidos "igual").pares = [ ("igual", "2") ]);
  let notas =
    List.map (fun n -> con ~veredicto:Mal ~nota:n "x") [ "a"; "b"; " a "; "c"; "d" ]
  in
  comprueba "advertencias: recientes, sin repetir, tres" ((elige notas "x").advertencias = [ "d"; "c"; "a" ]);
  (* El presupuesto: una entrada larga se corta; lo que no cabe se salta. *)
  let parametros = { Ejemplos.por_defecto with presupuesto = 100; max_entrada = 20 } in
  let largos =
    [ con ~veredicto:Bien ~salida:(Ok (String.make 90 'z')) "corto";
      con ~veredicto:Bien ~salida:(Ok "ok") (String.make 50 'a' ^ " ñ") ]
  in
  let c = elige ~parametros largos "aaa" in
  comprueba "entrada larga, cortada y avisada"
    (match c.pares with
    | [ (e, "ok") ] -> String.length e < 60 && String.starts_with ~prefix:(String.make 20 'a') e
    | _ -> false);
  comprueba "entrada y salida largas: se salta"
    (Ejemplos.es_vacio
       (elige ~parametros [ con ~veredicto:Bien ~salida:(Ok (String.make 30 't')) (String.make 40 'a') ] "aaa"));
  comprueba "sin partir un carácter"
    (match (elige ~parametros:{ parametros with max_entrada = 52 } largos "aaa").pares with
    | [ (e, _) ] -> String.length (List.hd (String.split_on_char '\n' e)) = 51
    | _ -> false);
  (* Las peticiones: lo estable delante. *)
  let contexto = { Ejemplos.pares = [ ("e1", "s1") ]; advertencias = [ "no así" ] } in
  let campo ruta j = List.fold_left (fun j k -> Yojson.Safe.Util.member k j) j ruta in
  let _, m = Agencia_http.Llm.peticion ~contexto agente caro "hola" in
  let roles = function
    | `List ts -> List.map (fun t -> Yojson.Safe.Util.(t |> member "role" |> to_string)) ts
    | _ -> []
  in
  comprueba "Messages: advertencias, ejemplos y entrada como turnos"
    (roles (campo [ "messages" ] m) = [ "user"; "assistant"; "user"; "assistant"; "user" ]);
  (match campo [ "messages" ] m with
  | `List [ adv; ack; e1; s1; ultimo ] ->
      comprueba "el primer turno da las advertencias"
        (match campo [ "content" ] adv with `String t -> contiene t "- no así" | _ -> false);
      comprueba "el asistente las acepta y cierra el prefijo cacheable"
        (match campo [ "content" ] ack with
        | `List [ b ] -> campo [ "cache_control"; "type" ] b = `String "ephemeral"
        | _ -> false);
      comprueba "luego los ejemplos y la entrada"
        (campo [ "content" ] e1 = `String "e1" && campo [ "content" ] s1 = `String "s1"
        && campo [ "content" ] ultimo = `String "hola")
  | _ -> comprueba "cinco turnos" false);
  (match campo [ "system" ] m with
  | `List [ b ] ->
      comprueba "Messages: el system son las instrucciones, con caché"
        (campo [ "text" ] b = `String agente.instrucciones && campo [ "cache_control"; "type" ] b = `String "ephemeral")
  | _ -> comprueba "Messages: system en un bloque" false);
  comprueba "sin advertencias, solo los ejemplos"
    (Ejemplos.turnos { contexto with advertencias = [] } = [ ("e1", "s1") ]);
  comprueba "contexto vacío: la petición de siempre"
    (Agencia_http.Llm.peticion ~contexto:Ejemplos.vacio agente caro "hola" = Agencia_http.Llm.peticion agente caro "hola");
  let _, o = Agencia_http.Llm.peticion ~contexto agente barato "hola" in
  comprueba "Chat Completions: system (las instrucciones), advertencias, ejemplos, entrada"
    (match campo [ "messages" ] o with
    | `List [ s; _; _; u; _; e ] ->
        campo [ "content" ] s = `String agente.instrucciones
        && campo [ "content" ] u = `String "e1"
        && campo [ "content" ] e = `String "hola"
    | _ -> false);
  (* Y la forja los ve como la misma tarea, con la plantilla limpia: ni los
     ejemplos ni las advertencias son la entrada ni la plantilla. *)
  (match Forja_http.Anthropic.peticion ~tarea:(Some "resumir") m with
  | Ok (p, _) ->
      comprueba "forja: la entrada es la última, la plantilla las instrucciones"
        (p.entrada = "hola" && p.plantilla = agente.instrucciones);
      comprueba "forja: lleva ejemplos" (Forja_http.Anthropic.con_ejemplos m)
  | Error e -> comprueba ("forja: con ejemplos es tarea: " ^ e) false);
  (match Forja_http.Openai.peticion ~tarea:(Some "resumir") o with
  | Ok (p, _) ->
      comprueba "forja openai: la entrada es la última, la plantilla las instrucciones"
        (p.entrada = "hola" && p.plantilla = agente.instrucciones)
  | Error e -> comprueba ("forja openai: con ejemplos es tarea: " ^ e) false);
  (* La salida corregida a mano es la que sirve de ejemplo, también de un
     mal; y su nota sigue siendo advertencia. *)
  let corr =
    [ { (con ~veredicto:Bien ~salida:(Ok "regular") "los gatos") with corregida = Some "buena" };
      { (con ~veredicto:Mal ~nota:"faltaba el tono" ~salida:(Ok "fatal") "los perros") with corregida = Some "arreglada" };
      { (con ~salida:(Ok "x") "sin juzgar") with corregida = Some "no cuenta" } ]
  in
  let c = elige corr "los perros" in
  comprueba "corregida en vez de la del modelo"
    (List.sort compare c.pares = [ ("los gatos", "buena"); ("los perros", "arreglada") ]);
  comprueba "y la nota del mal, advertencia" (c.advertencias = [ "faltaba el tono" ]);
  let module G = Agencia_http.Archivo_greptime in
  let v = Agencia.Bien in
  comprueba "fila de veredicto con corregida"
    (G.veredicto (G.fila_veredicto ~corregida:"c" agente.nombre "id" v "n") = Some ("id", v, "n", Some "c"));
  comprueba "fila de veredicto sin corregida"
    (G.veredicto (G.fila_veredicto agente.nombre "id" v "n") = Some ("id", v, "n", None));
  comprueba "fila de veredicto vieja"
    (G.veredicto (`List [ `String "id"; `String "resumir"; `String "mal"; `String "n" ]) = Some ("id", Mal, "n", None));
  let archivo = Archivo.en_memoria () in
  let e = encargo caro in
  archivo.registrar e;
  archivo.juzgar ~corregida:"mejor" agente.nombre e.id Bien "";
  comprueba "el archivo guarda la corregida"
    (match archivo.historial agente.nombre with [ x ] -> x.corregida = Some "mejor" | _ -> false);
  (* La fila del agente: ejemplos ida y vuelta, y las viejas sin ella. *)
  let module G = Agencia_http.Archivo_greptime in
  let a1 = { agente with ejemplos = 1 } in
  comprueba "fila con ejemplos" (G.agente (G.fila_agente a1) = Some a1);
  (match G.fila_agente agente with
  | `List l ->
      let vieja = `List (List.filteri (fun i _ -> i < 6) l) in
      comprueba "fila vieja: 3 ejemplos" (G.agente vieja = Some agente);
      comprueba "fila con nulo: 3 ejemplos" (G.agente (`List (List.filteri (fun i _ -> i < 6) l @ [ `Null ])) = Some agente)
  | _ -> comprueba "fila es lista" false);
  comprueba "ejemplos fuera de rango"
    (Result.is_error (Agente.crear ~nombre:"x" ~instrucciones:"i" ~escalera:[ caro ] ~ejemplos:11 ()));
  if !fallos > 0 then exit 1
