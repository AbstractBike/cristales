(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* medir <anuncios.jsonl>: el cristal contra la semilla (un anuncio por línea,
   {portal, pais, titulo, descripcion, precio, categoria…}, como los reunió
   memorias.email). Por la salida estándar, una línea por anuncio (portal,
   título y lectura o defecto); por la de errores, cuántos se leen sin
   defecto en cada portal y los defectos por motivo. *)

let entrada j =
  let open Yojson.Safe.Util in
  let s k = match member k j with `String s -> s | _ -> "" in
  let precio = match member "precio" j with `Int i -> string_of_int i | `Float f -> Printf.sprintf "%g" f | _ -> "" in
  String.concat "\n"
    (List.filter (( <> ) "")
       [ "Título: " ^ s "titulo";
         (if s "categoria" = "" then "" else "Categoría: " ^ s "categoria");
         (if precio = "" then "" else "Precio: " ^ precio);
         "Portal: " ^ s "portal";
         "País: " ^ s "pais";
         (if s "descripcion" = "" then "" else "Descripción: " ^ s "descripcion") ])

let () =
  let ic = open_in Sys.argv.(1) in
  let modelo_bien = ref 0 and modelo_total = ref 0 in
  let leidos = Hashtbl.create 4 and total = Hashtbl.create 4 and motivos = Hashtbl.create 16 and tipos = Hashtbl.create 16 in
  let suma t k = Hashtbl.replace t k (1 + Option.value ~default:0 (Hashtbl.find_opt t k)) in
  (try
     while true do
       let j = Yojson.Safe.from_string (input_line ic) in
       let portal = Yojson.Safe.Util.(member "portal" j |> to_string) in
       let titulo = Yojson.Safe.Util.(member "titulo" j |> to_string) in
       suma total portal;
       match Memoria_anuncio.aplicar (entrada j) with
       | Ok s ->
         suma leidos portal;
         let tipo = Yojson.Safe.Util.(member "tipo" (Yojson.Safe.from_string s) |> to_string) in
         if List.mem tipo [ "modulo"; "kit"; "lote" ] then begin
           incr modelo_total;
           match Memoria_modelo.aplicar titulo with Ok _ -> incr modelo_bien | Error m -> Printf.eprintf "  memoria-modelo: %s ← %s\n" m titulo
         end;
         suma tipos tipo;
         Printf.printf "%s\t%s\t%s\n" portal titulo s
       | Error m ->
         let motivo = match String.index_opt m ':' with Some i -> String.sub m 0 i | None -> m in
         suma motivos motivo;
         Printf.printf "%s\t%s\tDEFECTO %s\n" portal titulo m
     done
   with End_of_file -> ());
  Hashtbl.iter (fun p n -> Printf.eprintf "%s: %d de %d sin defecto\n" p (Option.value ~default:0 (Hashtbl.find_opt leidos p)) n) total;
  Printf.eprintf "memoria-modelo, en los títulos de memoria suelta: %d de %d sin defecto\n" !modelo_bien !modelo_total;
  Hashtbl.iter (fun m n -> Printf.eprintf "  defecto %s: %d\n" m n) motivos;
  Hashtbl.iter (fun t n -> Printf.eprintf "  tipo %s: %d\n" t n) tipos
