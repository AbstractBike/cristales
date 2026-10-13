(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let leer f = In_channel.with_open_bin f In_channel.input_all
let ( / ) = Filename.concat

let escribir_fichero repo ruta texto =
  let f = repo / ruta in
  let d = Filename.dirname f in
  if not (Sys.file_exists d) then Sys.mkdir d 0o755;
  let tmp = f ^ ".tmp" in
  Out_channel.with_open_bin tmp (fun oc -> Out_channel.output_string oc texto);
  Sys.rename tmp f

let escenas repo =
  let d = repo / "escenas" in
  if not (Sys.file_exists d) then Ok []
  else
    Sys.readdir d |> Array.to_list
    |> List.filter (fun f -> Filename.check_suffix f ".md")
    |> List.sort compare
    |> List.fold_left
         (fun acc f ->
           Result.bind acc (fun acc ->
               Result.map (fun e -> e :: acc) (Escena.de_texto ~slug:(Filename.chop_suffix f ".md") (leer (d / f)))))
         (Ok [])
    |> Result.map List.rev

let persona repo = if Sys.file_exists (repo / "persona.md") then leer (repo / "persona.md") else ""
let estado repo = if Sys.file_exists (repo / ".estado") then Estado.de_texto (leer (repo / ".estado")) else Estado.inicial

let bloqueada_en_disco repo slug =
  let f = repo / "escenas" / (slug ^ ".md") in
  Sys.file_exists f
  && match Escena.de_texto ~slug (leer f) with Ok e -> e.bloqueada | Error _ -> true

let escribir repo ~escenas ~escritas ~borradas ~persona estado =
  List.iter
    (fun s ->
      match List.find_opt (fun (e : Escena.t) -> e.slug = s) escenas with
      | Some e when not (bloqueada_en_disco repo s) -> escribir_fichero repo ("escenas" / (s ^ ".md")) (Escena.a_texto e)
      | _ -> ())
    escritas;
  List.iter
    (fun s ->
      let f = repo / "escenas" / (s ^ ".md") in
      if Sys.file_exists f && not (bloqueada_en_disco repo s) then Sys.remove f)
    borradas;
  Option.iter (fun p -> escribir_fichero repo "persona.md" (String.trim p ^ "\n")) persona;
  escribir_fichero repo ".estado" (Estado.a_texto estado)
