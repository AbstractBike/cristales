(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type t = (string, int) Hashtbl.t

let vacio () = Hashtbl.create 4096

let ruta_por_defecto () =
  let base =
    match Sys.getenv_opt "XDG_STATE_HOME" with
    | Some d when d <> "" -> d
    | _ -> Filename.concat (Option.value ~default:"/tmp" (Sys.getenv_opt "HOME")) ".local/state"
  in
  Filename.concat (Filename.concat base "memoria") "cursor"

let cargar ruta =
  let t = vacio () in
  (match In_channel.with_open_text ruta In_channel.input_all with
  | exception Sys_error _ -> ()
  | s ->
      String.split_on_char '\n' s
      |> List.iter (fun l ->
             match String.index_opt l '\t' with
             | Some i -> (
                 match int_of_string_opt (String.sub l 0 i) with
                 | Some n -> Hashtbl.replace t (String.sub l (i + 1) (String.length l - i - 1)) n
                 | None -> ())
             | None -> ()));
  t

let rec mkdir_p d =
  if not (Sys.file_exists d) then (
    mkdir_p (Filename.dirname d);
    try Sys.mkdir d 0o700 with Sys_error _ when Sys.file_exists d -> ())

let guardar ruta t =
  mkdir_p (Filename.dirname ruta);
  let tmp = ruta ^ ".tmp" in
  Out_channel.with_open_text tmp (fun oc ->
      Hashtbl.iter (fun f n -> Printf.fprintf oc "%d\t%s\n" n f) t);
  Sys.rename tmp ruta

let desde t f = Option.value ~default:0 (Hashtbl.find_opt t f)
let fijar t f n = Hashtbl.replace t f n
