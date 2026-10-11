(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type respuesta = { estado : int; tipo : string; cuerpo : string }

let json estado j = { estado; tipo = "application/json"; cuerpo = Yojson.Safe.to_string j }
let markdown s = { estado = 200; tipo = "text/markdown; charset=utf-8"; cuerpo = s }
let error estado m = json estado (`Assoc [ ("error", `String m) ])
let no_hay t = error 404 ("forja: no hay tal tarea: " ^ t)
let opcion = function Some s -> `String s | None -> `Null

let fase = function `Liquida -> "liquida" | `Mixta -> "mixta" | `Cristalina -> "cristalina"

let resumen (r : Forja.resumen) =
  [ ("tarea", `String (Forja.Tarea.to_string r.tarea));
    ("fase", `String (fase r.fase));
    ("muestras", `Int r.informe.muestras);
    ("contrastes", `Int r.informe.contrastes);
    ("coincidencias", `Int r.informe.coincidencias);
    ("madura", `Bool r.madura) ]

let vitrina f =
  `List
    (List.map
       (fun (p : Forja.Vitrina.pieza) ->
         `Assoc
           [ ("tarea", `String (Forja.Tarea.to_string p.tarea));
             ("estado", `String (fase (p.estado :> Forja.fase)));
             ("descripcion", `String p.descripcion) ])
       (Forja.Vitrina.listar (Forja.vitrina f)))

(* El cristal tal cual, sin respaldo líquido: quien llama ya es un LLM. *)
let aplicar f nombre cuerpo =
  match (Forja.Tarea.explicita nombre, Yojson.Safe.from_string cuerpo) with
  | Error _, _ -> no_hay nombre
  | Ok t, j -> (
      match (Forja.Vitrina.buscar (Forja.vitrina f) t, Yojson.Safe.Util.member "entrada" j) with
      | None, _ -> no_hay nombre
      | Some (_, c), `String e -> (
          match c.aplicar e with
          | Ok s -> json 200 (`Assoc [ ("salida", `String s) ])
          | Error m -> json 200 (`Assoc [ ("defecto", `String m) ]))
      | Some _, _ -> error 400 "forja: falta entrada (texto)")
  | exception (Yojson.Json_error _ | Yojson.Safe.Util.Type_error _) -> error 400 "forja: el cuerpo no es JSON"

(* Lo que la forja sabe de una tarea: [None] si no tiene muestras ni está en
   la vitrina. *)
let conocida f nombre =
  match Forja.Tarea.explicita nombre with
  | Error _ -> None
  | Ok t ->
      let muestras = (Forja.cantera f).muestras t in
      let r = Forja.resumen f t in
      if muestras = [] && r.fase = `Liquida then None else Some (t, r, muestras)

let ultimas n l =
  let sobran = List.length l - n in
  List.filteri (fun i _ -> i >= sobran) l

let detalle f nombre query =
  match conocida f nombre with
  | None -> no_hay nombre
  | Some (_, r, muestras) ->
      let n =
        match List.assoc_opt "muestras" query with
        | Some [ s ] -> Option.value ~default:5 (int_of_string_opt s) |> max 0 |> min 1000
        | _ -> 5
      in
      let plantilla = match muestras with m :: _ -> m.Forja.Cantera.plantilla | [] -> "" in
      json 200
        (`Assoc
          (resumen r
          @ [ ("plantilla", `String plantilla);
              ( "ultimas",
                `List
                  (List.map
                     (fun (m : Forja.Cantera.muestra) ->
                       `Assoc
                         [ ("entrada", `String m.entrada); ("salida", `String m.salida);
                           ("contraste", opcion m.contraste); ("defecto", opcion m.defecto) ])
                     (ultimas n muestras)) ) ]))

let con_muestras f nombre k =
  match conocida f nombre with
  | Some (t, r, (_ :: _ as muestras)) -> markdown (k t r muestras)
  | _ -> no_hay nombre

let atender f ~meth ~ruta ~query cuerpo =
  match (meth, String.split_on_char '/' ruta) with
  | `GET, [ ""; "forja"; "vitrina" ] -> Some (json 200 (vitrina f))
  | `POST, [ ""; "forja"; "vitrina"; t ] -> Some (aplicar f t cuerpo)
  | `GET, [ ""; "forja"; "tareas" ] ->
      Some (json 200 (`List (List.map (fun r -> `Assoc (resumen r)) (Forja.tareas f))))
  | `GET, [ ""; "forja"; "tareas"; t ] -> Some (detalle f t query)
  | `GET, [ ""; "forja"; "tareas"; t; "semilla" ] ->
      Some (con_muestras f t (fun t r m -> Forja.Semilla.markdown t r.informe m))
  | `GET, [ ""; "forja"; "tareas"; t; "nucleacion" ] ->
      Some (con_muestras f t (fun _ _ m -> Forja.Semilla.nucleacion ~prompt:Prompt.cristalizar m))
  | _, "" :: "forja" :: _ -> Some (error 404 ("forja: no existe " ^ ruta))
  | _ -> None
