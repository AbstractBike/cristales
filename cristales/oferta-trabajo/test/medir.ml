(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* medir <muestras.jsonl> [campo]: el cristal contra lo que respondió el LLM.
   Una muestra por línea, {"e": entrada, "s": salida del LLM}; un campo que
   no está en "s" no se mide (en las muestras parciales de la cantera el LLM
   solo dio los que faltaban). Con [campo], lista sus discrepancias. *)

let () =
  let ic = open_in Sys.argv.(1) in
  let cuenta = Hashtbl.create 16 and fallos = Hashtbl.create 16 and medibles = Hashtbl.create 16 in
  let n = ref 0 in
  (try
     while true do
       let j = Yojson.Safe.from_string (input_line ic) in
       incr n;
       let open Yojson.Safe.Util in
       let e = j |> member "e" |> to_string and s = j |> member "s" in
       let tiene k = match s with `Assoc l -> List.mem_assoc k l | _ -> false in
       (match s with
       | `Assoc l -> List.iter (fun (k, _) -> Hashtbl.replace medibles k (1 + Option.value ~default:0 (Hashtbl.find_opt medibles k))) l
       | _ -> ());
       match Oferta_trabajo.leer e with
       | None -> Printf.printf "sin posting: %s\n" (String.sub e 0 (min 80 (String.length e)))
       | Some o ->
           List.iter
             (fun (k, v) ->
               if tiene k then (
                 let dadas, buenas = Option.value ~default:(0, 0) (Hashtbl.find_opt cuenta k) in
                 let bien = Yojson.Safe.equal v (s |> member k) in
                 Hashtbl.replace cuenta k (dadas + 1, buenas + if bien then 1 else 0);
                 if not bien then
                   Hashtbl.add fallos k
                     (Printf.sprintf "%s | %s | cristal %s, LLM %s" o.titulo o.url (Yojson.Safe.to_string v)
                        (Yojson.Safe.to_string (s |> member k)))))
             (Oferta_trabajo.campos o)
     done
   with End_of_file -> ());
  Printf.printf "%d muestras\n" !n;
  Hashtbl.fold (fun k v acc -> (k, v) :: acc) medibles []
  |> List.sort compare
  |> List.iter (fun (k, m) ->
         let d, b = Option.value ~default:(0, 0) (Hashtbl.find_opt cuenta k) in
         Printf.printf "%-16s medibles %4d  da %4d (%3d%%)  coincide %4d (%5.1f%%)\n" k m d (100 * d / max m 1) b
           (100. *. float b /. float (max d 1)));
  if Array.length Sys.argv > 2 then
    List.iter (fun f -> print_endline ("  " ^ f)) (List.rev (Hashtbl.find_all fallos Sys.argv.(2)))
