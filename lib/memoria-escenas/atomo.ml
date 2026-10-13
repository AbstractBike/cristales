(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type t = {
  ts : int;
  id : string;
  version : int;
  vigente : bool;
  tipo : string;
  prioridad : int;
  escena : string;
  contenido : string;
  proyecto : string;
  origen : string;
  fechas : string;
}

let columnas =
  [ "ts"; "id"; "version"; "vigente"; "tipo"; "prioridad"; "escena"; "contenido"; "proyecto"; "origen"; "fechas" ]

let entero = function `Int i -> Some i | `Intlit s -> int_of_string_opt s | `Float f -> Some (int_of_float f) | _ -> None
let texto = function `String s -> s | `Null -> "" | j -> Yojson.Safe.to_string j
let booleano = function `Bool b -> b | `Int i -> i <> 0 | `String s -> s = "true" | _ -> false

let de_fila = function
  | `List [ ts; id; version; vigente; tipo; prioridad; escena; contenido; proyecto; origen; fechas ] -> (
      match (entero ts, id) with
      | Some ts, `String id ->
          Some
            { ts;
              id;
              version = Option.value ~default:1 (entero version);
              vigente = booleano vigente;
              tipo = texto tipo;
              prioridad = Option.value ~default:50 (entero prioridad);
              escena = texto escena;
              contenido = texto contenido;
              proyecto = texto proyecto;
              origen = texto origen;
              fechas = texto fechas }
      | _ -> None)
  | _ -> None

let vigentes atomos =
  let ultima = Hashtbl.create 64 in
  List.iter
    (fun a ->
      match Hashtbl.find_opt ultima a.id with
      | Some b when (b.version, b.ts) >= (a.version, a.ts) -> ()
      | _ -> Hashtbl.replace ultima a.id a)
    atomos;
  Hashtbl.fold (fun _ a acc -> if a.vigente then a :: acc else acc) ultima []
  |> List.sort (fun a b -> compare (a.ts, a.id) (b.ts, b.id))

let fechas a =
  try
    match Yojson.Safe.from_string a.fechas with
    | `List l -> List.filter_map (function `String s -> Some s | _ -> None) l
    | _ -> []
  with Yojson.Json_error _ -> []

let linea a =
  (* La primera y la última fecha: lo que importa es desde cuándo y hasta
     cuándo valió. *)
  let f =
    match fechas a with
    | [] -> ""
    | [ d ] -> " " ^ d
    | d :: r -> Printf.sprintf " %s..%s" d (List.nth r (List.length r - 1))
  in
  let p = if a.proyecto = "" then "" else Printf.sprintf " (%s)" a.proyecto in
  Printf.sprintf "- `%s` [%s]%s%s: %s" a.id a.tipo f p (String.trim a.contenido)
