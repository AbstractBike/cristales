(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Agencia

type punto = {
  tabla : string;
  etiquetas : (string * string) list;
  campos : (string * int) list;
  ms : float option;
}

let encargo (e : Encargo.t) =
  { tabla = "agencia_encargo";
    etiquetas =
      [ ("agente", Forja.Tarea.to_string e.agente);
        ("version", e.version);
        ("modelo", e.modelo);
        ("fuente", e.fuente);
        ("resultado", match e.salida with Ok _ -> "ok" | Error _ -> "error") ];
    campos = [ ("n", 1); ("ms", e.ms); ("tokens_entrada", e.tokens_entrada); ("tokens_salida", e.tokens_salida) ];
    ms = None }

let veredicto agente ~modelo v =
  { tabla = "agencia_veredicto";
    etiquetas = [ ("agente", Forja.Tarea.to_string agente); ("modelo", modelo); ("veredicto", veredicto_a_texto v) ];
    campos = [ ("n", 1) ];
    ms = None }

(* En las etiquetas se escapan comas, iguales y espacios; un valor vacío no
   vale en el protocolo, y se omite. *)
let escapar s =
  let b = Buffer.create (String.length s) in
  String.iter
    (function
      | (',' | '=' | ' ' | '\\') as c ->
          Buffer.add_char b '\\';
          Buffer.add_char b c
      | '\n' -> Buffer.add_char b ' '
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

let linea p =
  let etiquetas =
    List.filter_map (fun (k, v) -> if v = "" then None else Some (k ^ "=" ^ escapar v)) p.etiquetas
  in
  Printf.sprintf "%s%s %s%s"
    (escapar p.tabla)
    (String.concat "" (List.map (fun e -> "," ^ e) etiquetas))
    (String.concat "," (List.map (fun (k, v) -> Printf.sprintf "%s=%di" k v) p.campos))
    (match p.ms with Some ms -> Printf.sprintf " %.0f" ms | None -> "")

let con_medidas medir (a : Archivo.t) =
  (* Del encargo al modelo, para medir su veredicto sin leer el historial
     cuando se juzga en la misma sesión (lo normal). *)
  let modelos = Hashtbl.create 16 in
  let modelo_de agente id =
    match Hashtbl.find_opt modelos id with
    | Some m -> Some m
    | None ->
        List.find_map (fun (e : Encargo.t) -> if e.id = id then Some e.modelo else None) (a.historial agente)
  in
  { a with
    registrar =
      (fun e ->
        a.registrar e;
        Hashtbl.replace modelos e.id e.modelo;
        medir (encargo e));
    juzgar =
      (fun ?corregida agente id v nota ->
        a.juzgar ?corregida agente id v nota;
        Option.iter (fun modelo -> medir (veredicto agente ~modelo v)) (modelo_de agente id)) }

let a_greptime g p = Forja_http.Greptime.lineas g (linea p)
