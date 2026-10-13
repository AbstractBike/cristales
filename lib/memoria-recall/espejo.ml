(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type fichero = { ruta : string; contenido : string }

let tabla = "memoria_espejo"

let del_repo repo =
  let leer ruta = Option.map (fun contenido -> { ruta; contenido }) (Escenas.leer_fichero (Filename.concat repo ruta)) in
  let escenas =
    match Sys.readdir (Filename.concat repo "escenas") with
    | exception Sys_error _ -> []
    | fs ->
        Array.to_list fs
        |> List.filter (fun f -> Filename.check_suffix f ".md" && Escenas.slug_valido (Filename.chop_suffix f ".md"))
        |> List.filter_map (fun f -> leer ("escenas/" ^ f))
  in
  List.filter_map Fun.id [ leer "persona.md" ] @ escenas |> List.sort (fun a b -> compare a.ruta b.ruta)

let huella fs =
  Digest.to_hex
    (Digest.string
       (String.concat "\000" (List.concat_map (fun f -> [ f.ruta; f.contenido ]) (List.sort compare fs))))

let filas fs =
  let h = huella fs and total = List.length fs in
  List.map
    (fun f ->
      `Assoc
        [ ("ruta", `String f.ruta); ("contenido", `String f.contenido); ("huella", `String h); ("total", `Int total) ])
    fs

let ultima = Printf.sprintf "SELECT huella, total FROM %s ORDER BY greptime_timestamp DESC LIMIT 1" tabla

let de_huella h =
  if h <> "" && String.for_all (function '0' .. '9' | 'a' .. 'f' -> true | _ -> false) h then
    Ok (Printf.sprintf "SELECT ruta, contenido FROM %s WHERE huella = '%s'" tabla h)
  else Error (h ^ ": no es una huella")

let ruta_valida = function
  | "persona.md" -> true
  | r ->
      String.length r > 11
      && String.sub r 0 8 = "escenas/"
      && Filename.check_suffix r ".md"
      && Escenas.slug_valido (Filename.chop_suffix (String.sub r 8 (String.length r - 8)) ".md")

let escribir_fichero ruta texto = Out_channel.with_open_bin ruta (fun oc -> output_string oc texto)

let rec borrar ruta =
  match Sys.is_directory ruta with
  | true ->
      Array.iter (fun f -> borrar (Filename.concat ruta f)) (Sys.readdir ruta);
      Sys.rmdir ruta
  | false -> Sys.remove ruta
  | exception Sys_error _ -> ()

let escribir dir fs =
  let nuevo = dir ^ ".nuevo" and viejo = dir ^ ".viejo" in
  borrar nuevo;
  borrar viejo;
  Sys.mkdir nuevo 0o755;
  Sys.mkdir (Filename.concat nuevo "escenas") 0o755;
  List.iter (fun f -> if ruta_valida f.ruta then escribir_fichero (Filename.concat nuevo f.ruta) f.contenido) fs;
  escribir_fichero (Filename.concat nuevo ".huella") (huella fs);
  if Sys.file_exists dir then Sys.rename dir viejo;
  Sys.rename nuevo dir;
  borrar viejo

let huella_local dir = Option.map String.trim (Escenas.leer_fichero (Filename.concat dir ".huella"))
