(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red de la agencia: la elección de modelo, el servidor MCP con un LLM
   falso, las APIs y las filas de GreptimeDB. *)

open Agencia

let fallos = ref 0

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
    nota = "" }

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
    (match !puntos with [ p ] -> List.assoc "modelo" p.etiquetas = "claude-haiku-5-5" | _ -> false);
  if !fallos > 0 then exit 1
