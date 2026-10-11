(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red de la API de introspección (/forja/…), la que leen los forja-mcp. *)

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
let mayus = Cristal.cristal "mayus" (fun s -> if s = "" then Error "vacía" else Ok (String.uppercase_ascii s))

let forja =
  let vitrina = Forja.Vitrina.(vacia |> con (tarea "mayus") `Cristalina mayus ~descripcion:"Mayúsculas.") in
  let politica = { Forja.Madurez.minimo = 2; contrastar_cada = 1; contrastes = 1; estabilidad = 1.0 } in
  let f = Forja.crear ~politica ~vitrina ~cantera:(Forja.Cantera.en_memoria ()) () in
  let p e = { Forja.tarea = tarea "resumir"; plantilla = "Resume."; entrada = e } in
  List.iter (fun e -> ignore (Forja.aprender f (p e) ~contraste:"R" "R")) [ "uno"; "dos"; "tres" ];
  f

let pedir ?(meth = `GET) ?(query = []) ?(cuerpo = "") ruta =
  Forja_http.Introspeccion.atender forja ~meth ~ruta ~query cuerpo

let json r = Yojson.Safe.from_string r.Forja_http.Introspeccion.cuerpo
let campo k j = Yojson.Safe.Util.member k j

let () =
  comprueba "fuera de /forja/ no es suyo" (pedir "/v1/messages" = None);
  (match pedir "/forja/vitrina" with
  | Some r ->
      comprueba "vitrina"
        (json r = Yojson.Safe.from_string {|[{"tarea":"mayus","estado":"cristalina","descripcion":"Mayúsculas."}]|})
  | None -> comprueba "vitrina responde" false);
  let aplicar cuerpo = Option.map json (pedir ~meth:`POST ~cuerpo "/forja/vitrina/mayus") in
  comprueba "aplicar: salida" (aplicar {|{"entrada":"hola"}|} = Some (`Assoc [ ("salida", `String "HOLA") ]));
  comprueba "aplicar: defecto" (aplicar {|{"entrada":""}|} = Some (`Assoc [ ("defecto", `String "vacía") ]));
  comprueba "aplicar: sin entrada es 400"
    (Option.map (fun r -> r.Forja_http.Introspeccion.estado) (pedir ~meth:`POST ~cuerpo:"{}" "/forja/vitrina/mayus") = Some 400);
  comprueba "aplicar: no es JSON es 400"
    (Option.map (fun r -> r.Forja_http.Introspeccion.estado) (pedir ~meth:`POST ~cuerpo:"x" "/forja/vitrina/mayus") = Some 400);
  comprueba "aplicar: cristal que no está es 404"
    (Option.map (fun r -> r.Forja_http.Introspeccion.estado) (pedir ~meth:`POST ~cuerpo:{|{"entrada":"x"}|} "/forja/vitrina/otro") = Some 404);
  comprueba "política"
    (Option.map json (pedir "/forja/politica")
    = Some (Yojson.Safe.from_string {|{"minimo":2,"contrastar_cada":1,"contrastes":1,"estabilidad":1.0}|}));
  (match Option.map json (pedir "/forja/tareas") with
  | Some (`List [ m; r ]) ->
      comprueba "tareas: la de la vitrina, cristalina" (campo "tarea" m = `String "mayus" && campo "fase" m = `String "cristalina");
      comprueba "tareas: la de la cantera, líquida y madura"
        (campo "tarea" r = `String "resumir" && campo "fase" r = `String "liquida"
        && campo "muestras" r = `Int 3 && campo "madura" r = `Bool true)
  | _ -> comprueba "tareas: dos" false);
  (match Option.map json (pedir ~query:[ ("muestras", [ "2" ]) ] "/forja/tareas/resumir") with
  | Some j ->
      comprueba "detalle: plantilla" (campo "plantilla" j = `String "Resume.");
      comprueba "detalle: las 2 últimas, en orden"
        (match campo "ultimas" j with
        | `List [ a; b ] -> campo "entrada" a = `String "dos" && campo "entrada" b = `String "tres" && campo "contraste" b = `String "R"
        | _ -> false)
  | None -> comprueba "detalle responde" false);
  let estado r = Option.map (fun r -> r.Forja_http.Introspeccion.estado) r in
  comprueba "detalle de una tarea desconocida es 404" (estado (pedir "/forja/tareas/nada") = Some 404);
  comprueba "nombre que no es de tarea es 404" (estado (pedir "/forja/tareas/Nada") = Some 404);
  (match pedir "/forja/tareas/resumir/semilla" with
  | Some r -> comprueba "semilla en markdown" (r.estado = 200 && String.starts_with ~prefix:"# Semilla: resumir" r.cuerpo)
  | None -> comprueba "semilla responde" false);
  (match pedir "/forja/tareas/resumir/nucleacion" with
  | Some r -> let huecos = ref false in
      String.iteri (fun i c -> if c = '{' && i + 1 < String.length r.cuerpo && r.cuerpo.[i + 1] = '{' then huecos := true) r.cuerpo;
      comprueba "nucleación sin huecos" (r.estado = 200 && not !huecos)
  | None -> comprueba "nucleación responde" false);
  (* El defecto de aplicar quedó en la cantera, sin salida y sin contar. *)
  (match Option.map json (pedir "/forja/tareas/mayus") with
  | Some j ->
      comprueba "el defecto directo no cuenta para la madurez" (campo "muestras" j = `Int 0);
      comprueba "el defecto directo queda en la cantera"
        (match campo "ultimas" j with
        | `List [ d ] -> campo "entrada" d = `String "" && campo "salida" d = `Null && campo "defecto" d = `String "vacía"
        | _ -> false)
  | None -> comprueba "detalle del cristal responde" false);
  (match pedir "/forja/tareas/mayus/semilla" with
  | Some r -> comprueba "la semilla dice que el defecto no tuvo respuesta" (r.estado = 200 && contiene r.cuerpo "Sin respuesta")
  | None -> comprueba "semilla del cristal responde" false);
  comprueba "ruta desconocida bajo /forja/ es 404" (estado (pedir "/forja/otra") = Some 404);
  if !fallos > 0 then exit 1
