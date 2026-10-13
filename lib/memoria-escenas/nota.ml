(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type t = { nombre : string; descripcion : string; tipo : string; cuerpo : string }

let valor v =
  let v = String.trim v in
  let n = String.length v in
  if n >= 2 && v.[0] = '"' && v.[n - 1] = '"' then
    match Yojson.Safe.from_string v with `String s -> s | _ -> v | exception Yojson.Json_error _ -> v
  else if n >= 2 && v.[0] = '\'' && v.[n - 1] = '\'' then
    let s = String.sub v 1 (n - 2) in
    let b = Buffer.create n in
    let i = ref 0 in
    while !i < String.length s do
      if s.[!i] = '\'' && !i + 1 < String.length s && s.[!i + 1] = '\'' then (
        Buffer.add_char b '\'';
        i := !i + 2)
      else (
        Buffer.add_char b s.[!i];
        incr i)
    done;
    Buffer.contents b
  else v

let de_texto texto =
  let vacia = { nombre = ""; descripcion = ""; tipo = ""; cuerpo = String.trim texto } in
  match String.split_on_char '\n' texto with
  | p :: resto when String.trim p = "---" ->
      let rec ir n acc = function
        | [] -> { vacia with cuerpo = String.trim texto }
        | l :: r when String.trim l = "---" -> { n with cuerpo = String.trim (String.concat "\n" r) }
        | l :: r -> (
            match String.index_opt l ':' with
            | None -> ir n acc r
            | Some i -> (
                let k = String.trim (String.sub l 0 i)
                and v = valor (String.sub l (i + 1) (String.length l - i - 1)) in
                match k with
                | "name" -> ir { n with nombre = v } acc r
                | "description" -> ir { n with descripcion = v } acc r
                | "type" -> ir { n with tipo = v } acc r
                | _ -> ir n acc r))
      in
      ir vacia () resto
  | _ -> vacia

let es_indice ruta = Filename.basename ruta = "MEMORY.md"

let tipo_atomo = function "feedback" -> "regla" | "user" -> "persona" | _ -> "hecho"

let fechas_en texto =
  let n = String.length texto in
  let digito i = i < n && texto.[i] >= '0' && texto.[i] <= '9' in
  let es i =
    i + 10 <= n
    && texto.[i] = '2' && texto.[i + 1] = '0'
    && digito (i + 2) && digito (i + 3)
    && texto.[i + 4] = '-' && digito (i + 5) && digito (i + 6)
    && texto.[i + 7] = '-' && digito (i + 8) && digito (i + 9)
    && (i = 0 || not (digito (i - 1)))
    && not (digito (i + 10))
  in
  let acc = ref [] in
  for i = 0 to n - 10 do
    if es i then acc := String.sub texto i 10 :: !acc
  done;
  List.sort_uniq compare !acc

let id_de ruta = "a-" ^ String.sub (Digest.to_hex (Digest.string ("nota:" ^ ruta))) 0 12

let primer_parrafo cuerpo =
  let p =
    String.split_on_char '\n' cuerpo
    |> List.map String.trim
    |> List.filter (fun l -> l <> "" && l.[0] <> '#')
    |> function
    | l :: _ -> l
    | [] -> ""
  in
  if String.length p > 400 then String.sub p 0 400 else p

let atomo ~ts ~ruta ~proyecto ~escena ~fecha n =
  let contenido = if String.trim n.descripcion <> "" then String.trim n.descripcion else primer_parrafo n.cuerpo in
  let tipo = tipo_atomo n.tipo in
  let fechas = List.sort_uniq compare ((if fecha = "" then [] else [ fecha ]) @ fechas_en (n.descripcion ^ "\n" ^ n.cuerpo)) in
  { Atomo.ts;
    id = id_de ruta;
    version = 1;
    vigente = true;
    tipo;
    prioridad = (if tipo = "hecho" then 50 else 70);
    escena;
    contenido;
    proyecto;
    origen = Yojson.Safe.to_string (`List [ `String ("nota:" ^ ruta) ]);
    fechas = Yojson.Safe.to_string (`List (List.map (fun f -> `String f) fechas)) }
