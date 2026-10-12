(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* medir <muestras.jsonl>: el cristal contra lo que respondió el LLM. *)

let () =
  let ic = open_in Sys.argv.(1) in
  let cuenta = Hashtbl.create 16 and fallos = Hashtbl.create 16 in
  let n = ref 0 in
  (try
     while true do
       let j = Yojson.Safe.from_string (input_line ic) in
       incr n;
       let open Yojson.Safe.Util in
       let e = j |> member "e" |> to_string and s = j |> member "s" in
       match Oferta_trabajo.leer e with
       | None -> Printf.printf "sin posting: %s\n" (String.sub e 0 (min 80 (String.length e)))
       | Some o ->
           List.iter
             (fun (k, v) ->
               let dadas, buenas = Option.value ~default:(0, 0) (Hashtbl.find_opt cuenta k) in
               let bien = Yojson.Safe.equal v (s |> member k) in
               Hashtbl.replace cuenta k (dadas + 1, buenas + if bien then 1 else 0);
               if not bien then
                 Hashtbl.add fallos k
                   (Printf.sprintf "%s | cristal %s, LLM %s" o.titulo (Yojson.Safe.to_string v)
                      (Yojson.Safe.to_string (s |> member k))))
             (Oferta_trabajo.campos o)
     done
   with End_of_file -> ());
  Printf.printf "%d muestras\n" !n;
  Hashtbl.fold (fun k v acc -> (k, v) :: acc) cuenta []
  |> List.sort compare
  |> List.iter (fun (k, (d, b)) ->
         Printf.printf "%-16s da %4d (%3d%%)  coincide %4d (%5.1f%%)\n" k d (100 * d / !n) b
           (100. *. float b /. float (max d 1)));
  if Array.length Sys.argv > 2 then
    List.iter (fun f -> print_endline ("  " ^ f)) (Hashtbl.find_all fallos Sys.argv.(2))
