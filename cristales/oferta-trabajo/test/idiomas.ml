(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Los idiomas exigidos que da el cristal para cada muestra (una por línea,
   {"id": n, "e": entrada}): «id códigos». Para medirlo contra un juicio
   hecho a mano; las muestras no se commitean. *)

let () =
  In_channel.with_open_text Sys.argv.(1) In_channel.input_lines
  |> List.iter (fun l ->
         let j = Yojson.Safe.from_string l in
         let id = Yojson.Safe.Util.(member "id" j |> to_int) in
         let e = Yojson.Safe.Util.(member "e" j |> to_string) in
         match Oferta_trabajo.leer e with
         | None -> Printf.printf "%d DEFECTO\n" id
         | Some o ->
             let codigos =
               match List.assoc_opt "languages" (Oferta_trabajo.campos o) with
               | Some (`List l) -> List.map (function `String c -> c | _ -> "?") l
               | _ -> [ "?" ]
             in
             Printf.printf "%d %s\n" id (String.concat "," codigos))
