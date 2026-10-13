(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* probar <memoria-anuncio|memoria-modelo> <fichero>: aplica el cristal al
   texto del fichero y escribe la salida o el defecto. Para depurar; no es
   parte de la red. *)

let () =
  let ic = open_in_bin Sys.argv.(2) in
  let texto = really_input_string ic (in_channel_length ic) in
  let r = match Sys.argv.(1) with "memoria-modelo" -> Memoria_modelo.aplicar texto | _ -> Memoria_anuncio.aplicar texto in
  match r with Ok s -> print_endline s | Error m -> print_endline ("DEFECTO " ^ m)
