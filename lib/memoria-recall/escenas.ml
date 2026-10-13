(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type t = { slug : string; titulo : string; resumen : string; calor : float; actualizada : string }

let leer_fichero ruta =
  try Some (In_channel.with_open_bin ruta In_channel.input_all) with Sys_error _ -> None

let sin_comillas v =
  let n = String.length v in
  if n >= 2 && ((v.[0] = '"' && v.[n - 1] = '"') || (v.[0] = '\'' && v.[n - 1] = '\'')) then
    String.sub v 1 (n - 2)
  else v

(* El frontmatter (líneas entre los dos primeros [---]) y el cuerpo. Sin
   [---] de cierre, todo es cuerpo. *)
let partir texto =
  match String.split_on_char '\n' texto with
  | primera :: resto when String.trim primera = "---" ->
      let rec ir acc = function
        | [] -> None
        | l :: ls when String.trim l = "---" -> Some (List.rev acc, String.concat "\n" ls)
        | l :: ls -> ir (String.trim l :: acc) ls
      in
      Option.value ~default:([], texto) (ir [] resto)
  | _ -> ([], texto)

let frontmatter texto =
  fst (partir texto)
  |> List.filter_map (fun l ->
         match String.index_opt l ':' with
         | Some i when i > 0 ->
             let k = String.trim (String.sub l 0 i) in
             let v = String.trim (String.sub l (i + 1) (String.length l - i - 1)) in
             Some (k, sin_comillas v)
         | _ -> None)

let de_texto ~slug texto =
  let fm = frontmatter texto in
  let campo k = Option.value ~default:"" (List.assoc_opt k fm) in
  { slug;
    titulo = (match campo "titulo" with "" -> slug | t -> t);
    resumen = campo "resumen";
    calor = Option.value ~default:0. (float_of_string_opt (campo "calor"));
    actualizada = campo "actualizada" }

let slug_valido s =
  s <> ""
  && String.for_all (function 'a' .. 'z' | '0' .. '9' | '-' | '_' -> true | _ -> false) s

let indice repo =
  let dir = Filename.concat repo "escenas" in
  match Sys.readdir dir with
  | exception Sys_error _ -> []
  | ficheros ->
      Array.to_list ficheros
      |> List.filter_map (fun f ->
             if Filename.check_suffix f ".md" then
               let slug = Filename.chop_suffix f ".md" in
               if slug_valido slug then
                 Option.map (de_texto ~slug) (leer_fichero (Filename.concat dir f))
               else None
             else None)
      |> List.sort (fun a b ->
             match Float.compare b.calor a.calor with 0 -> String.compare a.slug b.slug | c -> c)

let persona repo =
  match leer_fichero (Filename.concat repo "persona.md") with
  | None -> None
  | Some t -> ( match String.trim (snd (partir t)) with "" -> None | p -> Some p)

let escena repo slug =
  if not (slug_valido slug) then Error (slug ^ ": no es un slug de escena ([a-z0-9-_])")
  else
    match leer_fichero (Filename.concat (Filename.concat repo "escenas") (slug ^ ".md")) with
    | Some t -> Ok t
    | None -> Error (slug ^ ": no hay tal escena (mira el índice del arranque)")
