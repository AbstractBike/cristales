(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* probar <texto>…: lo que lee tv-modelo de cada texto. *)
let () =
  for i = 1 to Array.length Sys.argv - 1 do
    match Tv_modelo.aplicar Sys.argv.(i) with
    | Ok s -> print_endline s
    | Error m -> print_endline ("DEFECTO " ^ m)
  done
