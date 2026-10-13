(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type contenido = { slug : string; titulo : string; resumen : string; cuerpo : string; atomos : string list }
type t = Actualizar of contenido | Fusionar of string list * contenido | Crear of contenido | Nada
type salida = { operaciones : t list; persona : string option }

let senal = "[ACTUALIZAR_PERSONA]"

let buscar sub s =
  let n = String.length sub and m = String.length s in
  let rec ir i = if i + n > m then None else if String.sub s i n = sub then Some i else ir (i + 1) in
  ir 0

(* El motivo: lo que sigue a la señal hasta el fin de línea o de cadena. *)
let motivo texto =
  match buscar senal texto with
  | None -> None
  | Some i ->
      let desde = i + String.length senal in
      let resto = String.sub texto desde (String.length texto - desde) in
      let corte =
        String.fold_left
          (fun (fin, j) c -> if fin then (fin, j) else if c = '\n' || c = '"' then (true, j) else (false, j + 1))
          (false, 0) resto
        |> snd
      in
      Some (String.trim (String.sub resto 0 corte))

let campo k j = Yojson.Safe.Util.member k j

let cadena k j = match campo k j with `String s -> Ok s | `Null -> Ok "" | _ -> Error (k ^ " no es una cadena")

let cadenas k j =
  match campo k j with
  | `Null -> Ok []
  | `List l ->
      List.fold_right
        (fun x acc ->
          Result.bind acc (fun acc -> match x with `String s -> Ok (s :: acc) | _ -> Error (k ^ ": no es una cadena")))
        l (Ok [])
  | _ -> Error (k ^ " no es una lista")

let ( let* ) = Result.bind

let contenido j =
  let* slug = cadena "slug" j in
  let* titulo = cadena "titulo" j in
  let* resumen = cadena "resumen" j in
  let* cuerpo = cadena "cuerpo" j in
  let* atomos = cadenas "atomos" j in
  Ok { slug = String.trim slug; titulo; resumen; cuerpo; atomos }

let operacion j =
  match campo "op" j with
  | `String "nada" -> Ok Nada
  | `String "actualizar" -> Result.map (fun c -> Actualizar c) (contenido j)
  | `String "crear" -> Result.map (fun c -> Crear c) (contenido j)
  | `String "fusionar" ->
      let* de = cadenas "de" j in
      Result.map (fun c -> Fusionar (List.map String.trim de, c)) (contenido j)
  | `String o -> Error ("operación desconocida: " ^ o)
  | _ -> Error "operación sin «op»"

let de_texto texto =
  match (String.index_opt texto '{', String.rindex_opt texto '}') with
  | Some i, Some f when f > i -> (
      match Yojson.Safe.from_string (String.sub texto i (f - i + 1)) with
      | exception Yojson.Json_error e -> Error ("JSON inválido: " ^ e)
      | j -> (
          match campo "operaciones" j with
          | `List ops ->
              let* operaciones =
                List.fold_right
                  (fun o acc ->
                    let* acc = acc in
                    let* o = operacion o in
                    Ok (o :: acc))
                  ops (Ok [])
              in
              Ok { operaciones; persona = motivo texto }
          | _ -> Error "falta la lista «operaciones»"))
  | _ -> Error "no hay ningún objeto JSON"

let contenido_json c =
  [ ("slug", `String c.slug);
    ("titulo", `String c.titulo);
    ("resumen", `String c.resumen);
    ("cuerpo", `String c.cuerpo);
    ("atomos", `List (List.map (fun a -> `String a) c.atomos)) ]

let a_json = function
  | Nada -> `Assoc [ ("op", `String "nada") ]
  | Actualizar c -> `Assoc (("op", `String "actualizar") :: contenido_json c)
  | Crear c -> `Assoc (("op", `String "crear") :: contenido_json c)
  | Fusionar (de, c) ->
      `Assoc (("op", `String "fusionar") :: ("de", `List (List.map (fun s -> `String s) de)) :: contenido_json c)

let describir = function
  | Nada -> "nada"
  | Actualizar c -> "actualizar " ^ c.slug
  | Crear c -> "crear " ^ c.slug
  | Fusionar (de, c) -> Printf.sprintf "fusionar %s -> %s" (String.concat "+" de) c.slug
