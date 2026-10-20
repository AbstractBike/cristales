(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type etiquetas = (string * string) list
type tipo = Contador | Histograma of float list

type t = {
  tipos : (string, tipo * string) Hashtbl.t;  (* nombre → tipo y ayuda *)
  orden : string list ref;  (* en orden de declaración *)
  contadores : (string * etiquetas, float ref) Hashtbl.t;
  histogramas : (string * etiquetas, float array * float ref * float ref) Hashtbl.t;
      (* cubos (acumulados al servir), suma y cuenta *)
}

let crear () =
  { tipos = Hashtbl.create 16; orden = ref []; contadores = Hashtbl.create 64; histogramas = Hashtbl.create 64 }

let declarar t nombre tipo ayuda =
  if not (Hashtbl.mem t.tipos nombre) then (
    Hashtbl.replace t.tipos nombre (tipo, ayuda);
    t.orden := !(t.orden) @ [ nombre ])

let contador t nombre ~ayuda = declarar t nombre Contador ayuda
let histograma t nombre ~ayuda ~cubos = declarar t nombre (Histograma cubos) ayuda

(* Mismas etiquetas en otro orden son la misma serie. *)
let normal = List.sort compare

let sumar t nombre ?(etiquetas = []) v =
  match Hashtbl.find_opt t.tipos nombre with
  | Some (Contador, _) -> (
      let k = (nombre, normal etiquetas) in
      match Hashtbl.find_opt t.contadores k with
      | Some r -> r := !r +. v
      | None -> Hashtbl.replace t.contadores k (ref v))
  | _ -> ()

let observar t nombre ?(etiquetas = []) v =
  match Hashtbl.find_opt t.tipos nombre with
  | Some (Histograma cubos, _) ->
      let k = (nombre, normal etiquetas) in
      let cs, suma, cuenta =
        match Hashtbl.find_opt t.histogramas k with
        | Some h -> h
        | None ->
            let h = (Array.make (List.length cubos) 0., ref 0., ref 0.) in
            Hashtbl.replace t.histogramas k h;
            h
      in
      (* Cada observación cae en el primer cubo que la contiene; al servir se
         acumulan. *)
      (match List.find_index (fun l -> v <= l) cubos with Some i -> cs.(i) <- cs.(i) +. 1. | None -> ());
      suma := !suma +. v;
      cuenta := !cuenta +. 1.
  | _ -> ()

(* Lo sumado en un contador por las series que llevan todas esas etiquetas. *)
let suma t nombre ~donde =
  let donde = normal donde in
  Hashtbl.fold
    (fun (n, es) r acc -> if n = nombre && List.for_all (fun p -> List.mem p es) donde then acc +. !r else acc)
    t.contadores 0.

type medida = { nombre : string; ayuda : string; valores : (etiquetas * float) list }

(* {1 Texto} *)

let escapar s =
  let b = Buffer.create (String.length s) in
  String.iter
    (function
      | '\\' -> Buffer.add_string b "\\\\"
      | '"' -> Buffer.add_string b "\\\""
      | '\n' -> Buffer.add_string b "\\n"
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

let etiquetas_texto = function
  | [] -> ""
  | es -> "{" ^ String.concat "," (List.map (fun (k, v) -> Printf.sprintf "%s=\"%s\"" k (escapar v)) es) ^ "}"

let numero v =
  if Float.is_integer v && Float.abs v < 1e15 then Printf.sprintf "%.0f" v
  else if v = Float.infinity then "+Inf"
  else Printf.sprintf "%g" v

let linea b nombre es v = Printf.bprintf b "%s%s %s\n" nombre (etiquetas_texto es) (numero v)

let cabecera b nombre ayuda tipo = Printf.bprintf b "# HELP %s %s\n# TYPE %s %s\n" nombre ayuda nombre tipo

let series tabla nombre =
  Hashtbl.fold (fun (n, es) v acc -> if n = nombre then (es, v) :: acc else acc) tabla []
  |> List.sort compare

let servir t medidas =
  let b = Buffer.create 4096 in
  List.iter
    (fun nombre ->
      match Hashtbl.find t.tipos nombre with
      | Contador, ayuda ->
          cabecera b nombre ayuda "counter";
          List.iter (fun (es, r) -> linea b nombre es !r) (series t.contadores nombre)
      | Histograma cubos, ayuda ->
          cabecera b nombre ayuda "histogram";
          List.iter
            (fun (es, (cs, suma, cuenta)) ->
              let acumulado = ref 0. in
              List.iteri
                (fun i l ->
                  acumulado := !acumulado +. cs.(i);
                  linea b (nombre ^ "_bucket") (es @ [ ("le", numero l) ]) !acumulado)
                cubos;
              linea b (nombre ^ "_bucket") (es @ [ ("le", "+Inf") ]) !cuenta;
              linea b (nombre ^ "_sum") es !suma;
              linea b (nombre ^ "_count") es !cuenta)
            (series t.histogramas nombre))
    !(t.orden);
  List.iter
    (fun m ->
      cabecera b m.nombre m.ayuda "gauge";
      List.iter (fun (es, v) -> linea b m.nombre (normal es) v) m.valores)
    medidas;
  Buffer.contents b
