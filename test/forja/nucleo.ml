(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red del núcleo de la forja y de la traducción de la Messages API. *)

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

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
    (List.for_all (function Cristal.Por_liquido "mayus" -> true | _ -> false) !eventos);
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
    Cristal.cristal "mayus" (fun s ->
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
        entrada = "hola"; salida = "HOLA"; contraste = None; defecto = None } ]
  in
  let prompt = Forja_http.Prompt.cristalizar in
  let n = Forja.Semilla.nucleacion ~prompt muestras in
  let contiene s sub =
    let ls = String.length s and lsub = String.length sub in
    let rec ir i = i + lsub <= ls && (String.sub s i lsub = sub || ir (i + 1)) in
    ir 0
  in
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
      let contiene s sub =
        let n = String.length sub in
        let rec ir i = i + n <= String.length s && (String.sub s i n = sub || ir (i + 1)) in
        ir 0
      in
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
          ["mayus","P","hola","HOLA",true,"HOLA",""],
          ["mayus","P","a1","A1",false,"","dígitos"]]}}]}|}
  in
  match Forja_http.Cantera_greptime.filas r with
  | [ a; b ] ->
      comprueba "fila contrastada" (a.contraste = Some "HOLA" && a.defecto = None);
      comprueba "fila con defecto" (b.contraste = None && b.defecto = Some "dígitos")
  | _ -> comprueba "dos filas de greptime" false

let () = if !fallos > 0 then exit 1
