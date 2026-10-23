(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* medir <titulares.jsonl>: el cristal contra la semilla (un titular por
   línea, {feed, idioma, titulo, resumen…}). Por la salida estándar, una
   línea por titular (feed, título y lectura o defecto); por la de errores,
   cuántos se leen sin defecto y cuántos de cada tema. *)

let () =
  let ic = open_in Sys.argv.(1) in
  let n = ref 0 and leidos = ref 0 and temas = Hashtbl.create 8 and motivos = Hashtbl.create 8 in
  let suma t k = Hashtbl.replace t k (1 + Option.value ~default:0 (Hashtbl.find_opt t k)) in
  (try
     while true do
       let j = Yojson.Safe.from_string (input_line ic) in
       let s k = match Yojson.Safe.Util.member k j with `String s -> s | _ -> "" in
       incr n;
       let entrada = "Título: " ^ s "titulo" ^ (if s "resumen" = "" then "" else "\nResumen: " ^ s "resumen") ^ "\nFuente: " ^ s "feed" in
       match Tv_noticia.aplicar entrada with
       | Ok r ->
         incr leidos;
         suma temas Yojson.Safe.Util.(member "tema" (Yojson.Safe.from_string r) |> to_string);
         Printf.printf "%s\t%s\t%s\n" (s "feed") (s "titulo") r
       | Error m ->
         suma motivos m;
         Printf.printf "%s\t%s\tDEFECTO %s\n" (s "feed") (s "titulo") m
     done
   with End_of_file -> ());
  Printf.eprintf "%d de %d sin defecto\n" !leidos !n;
  Hashtbl.iter (fun t k -> Printf.eprintf "  tema %s: %d\n" t k) temas;
  Hashtbl.iter (fun m k -> Printf.eprintf "  defecto %s: %d\n" m k) motivos
