(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* {1 Candidatos} *)

let vacias =
  [ "para"; "pero"; "como"; "cuando"; "donde"; "desde"; "hasta"; "sobre"; "entre"; "este"; "esta"; "esto"; "estos";
    "estas"; "ese"; "esa"; "eso"; "esos"; "esas"; "aquel"; "todo"; "toda"; "todos"; "todas"; "cada"; "otro"; "otra";
    "otros"; "otras"; "mismo"; "misma"; "porque"; "aunque"; "tiene"; "tienen"; "hace"; "hacer"; "debe"; "deben"; "puede";
    "pueden"; "usuario"; "usuarios"; "siempre"; "nunca"; "también"; "solo"; "sólo"; "más"; "menos"; "muy"; "bien";
    "sin"; "con"; "por"; "que"; "una"; "uno"; "unos"; "unas"; "los"; "las"; "del"; "and"; "or"; "not"; "the"; "with";
    "from"; "this"; "that"; "ser"; "está"; "están"; "fue"; "son"; "hay"; "vez"; "veces"; "antes"; "después"; "ahora";
    "agente"; "agentes"; "prefiere"; "quiere"; "usar"; "usa"; "cosa"; "cosas"; "algo"; "nada"; "dentro"; "fuera" ]

(* Palabras: secuencias de letras ASCII, cifras o bytes UTF-8 (las letras
   con tilde); lo demás separa. *)
let palabras s =
  let b = Buffer.create 16 and l = ref [] in
  let cortar () = if Buffer.length b > 0 then (l := Buffer.contents b :: !l; Buffer.clear b) in
  String.iter (fun c -> match c with 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '\128' .. '\255' -> Buffer.add_char b c | _ -> cortar ()) s;
  cortar ();
  List.rev !l

let tiene p s = String.exists p s
let cifra = function '0' .. '9' -> true | _ -> false
let mayuscula = function 'A' .. 'Z' -> true | _ -> false

let terminos ?(max = 6) contenido =
  let candidatas =
    List.filter
      (fun p ->
        let n = String.length p in
        (n >= 4 || (n >= 2 && tiene cifra p))
        && (not (List.mem (String.lowercase_ascii p) vacias))
        && not (String.for_all cifra p && n < 4))
      (palabras contenido)
  in
  (* Sin repetir (sin distinguir mayúsculas), la primera forma vista. *)
  let unicas =
    List.fold_left
      (fun acc p -> if List.exists (fun q -> String.lowercase_ascii q = String.lowercase_ascii p) acc then acc else acc @ [ p ])
      [] candidatas
  in
  let peso p = (if tiene mayuscula p || tiene cifra p then 100 else 0) + String.length p in
  let ordenadas = List.stable_sort (fun a b -> compare (peso b) (peso a)) unicas in
  List.filteri (fun i _ -> i < max) ordenadas

let consulta t =
  let capital s = if s = "" then s else String.capitalize_ascii (String.lowercase_ascii s) in
  String.concat " OR " (List.sort_uniq String.compare [ t; String.lowercase_ascii t; capital t ])

(* Sin repetir, en el orden de la primera aparición. *)
let distintos l = List.rev (List.fold_left (fun acc x -> if List.mem x acc then acc else x :: acc) [] l)

let rrf ?(k = 60) listas =
  let puntos = ref [] in
  List.iter
    (fun lista ->
      List.iteri
        (fun i id ->
          let s = 1. /. float_of_int (k + i + 1) in
          puntos :=
            if List.mem_assoc id !puntos then List.map (fun (x, p) -> if x = id then (x, p +. s) else (x, p)) !puntos
            else !puntos @ [ (id, s) ])
        (distintos lista))
    listas;
  (* Estable: a igual puntuación, el que apareció antes. *)
  List.stable_sort (fun (_, a) (_, b) -> compare b a) !puntos

let vigentes maximas filas =
  let filas =
    List.filter
      (fun (a : Atomo.t) -> a.vigente && List.assoc_opt a.id maximas = Some a.version)
      filas
  in
  List.rev (List.fold_left (fun acc (a : Atomo.t) -> if List.exists (fun (b : Atomo.t) -> b.id = a.id) acc then acc else a :: acc) [] filas)

let mejores ?(n = 5) listas =
  let todos = List.concat listas in
  let ranking = rrf (List.map (List.map (fun (a : Atomo.t) -> a.id)) listas) in
  List.filteri (fun i _ -> i < n) ranking
  |> List.filter_map (fun (id, _) -> List.find_opt (fun (a : Atomo.t) -> a.id = id) todos)

(* {1 El juez} *)

type caso = { etiqueta : string; nuevo : Atomo.nuevo; candidatos : Atomo.t list }

let casos l = List.mapi (fun i (nuevo, candidatos) -> { etiqueta = Printf.sprintf "n%d" (i + 1); nuevo; candidatos }) l

let hace_falta_juez = List.exists (fun c -> c.candidatos <> [])

let json_textos l = `List (List.map (fun s -> `String s) l)

let entrada casos =
  let pool =
    List.fold_left
      (fun acc c -> List.fold_left (fun acc (a : Atomo.t) -> if List.exists (fun (b : Atomo.t) -> b.id = a.id) acc then acc else acc @ [ a ]) acc c.candidatos)
      [] casos
  in
  let candidato (a : Atomo.t) =
    `Assoc
      [ ("id", `String a.id);
        ("tipo", `String (Atomo.tipo_a_texto a.tipo));
        ("prioridad", `Int a.prioridad);
        ("escena", `String a.escena);
        ("contenido", `String a.contenido);
        ("fechas", json_textos a.fechas) ]
  in
  let nuevo c =
    Printf.sprintf "### %s\n%s\nCandidatos: %s" c.etiqueta
      (Yojson.Safe.to_string
         (`Assoc
           [ ("id", `String c.etiqueta);
             ("tipo", `String (Atomo.tipo_a_texto c.nuevo.tipo));
             ("prioridad", `Int c.nuevo.prioridad);
             ("escena", `String c.nuevo.escena);
             ("contenido", `String c.nuevo.contenido);
             ("fechas", json_textos c.nuevo.fechas) ]))
      (match c.candidatos with
      | [] -> "ninguno (guardar)"
      | l -> Yojson.Safe.to_string (json_textos (List.map (fun (a : Atomo.t) -> a.id) l)))
  in
  Printf.sprintf "## Candidatos (%d átomos que ya están en la memoria)\n\n%s\n\n## Átomos nuevos (%d)\n\n%s\n\nUna decisión por átomo nuevo, en un array JSON.\n"
    (List.length pool)
    (match pool with [] -> "(ninguno)" | l -> String.concat "\n" (List.map (fun a -> Yojson.Safe.to_string (candidato a)) l))
    (List.length casos)
    (String.concat "\n\n" (List.map nuevo casos))

type accion = Guardar | Saltar | Actualizar | Fusionar

let accion_a_texto = function Guardar -> "guardar" | Saltar -> "saltar" | Actualizar -> "actualizar" | Fusionar -> "fusionar"

let accion_de_texto s =
  match String.lowercase_ascii (String.trim s) with
  | "guardar" | "store" -> Some Guardar
  | "saltar" | "skip" -> Some Saltar
  | "actualizar" | "update" -> Some Actualizar
  | "fusionar" | "merge" -> Some Fusionar
  | _ -> None

type decision = {
  caso : string;
  accion : accion;
  objetivos : string list;
  contenido : string option;
  tipo : Atomo.tipo option;
  prioridad : int option;
  fechas : string list;
}

let guardar c = { caso = c.etiqueta; accion = Guardar; objetivos = []; contenido = None; tipo = None; prioridad = None; fechas = [] }
let guardar_todo = List.map guardar

let es_fecha s =
  String.length s = 10 && s.[4] = '-' && s.[7] = '-'
  && String.for_all (fun c -> cifra c || c = '-') s

let leer casos respuesta =
  match Json_llm.extraer respuesta with
  | Error e -> Error e
  | Ok (`List items) ->
      let decidir c =
        match List.find_opt (fun j -> Json_llm.texto j "id" = Some c.etiqueta) items with
        | None -> guardar c
        | Some j -> (
            let ids = List.map (fun (a : Atomo.t) -> a.id) c.candidatos in
            let objetivos = distintos (List.filter (fun o -> List.mem o ids) (Json_llm.textos j "objetivos")) in
            let d =
              { caso = c.etiqueta;
                accion = Guardar;
                objetivos;
                contenido = Json_llm.texto j "contenido";
                tipo = Option.bind (Json_llm.texto j "tipo") Atomo.tipo_de_texto;
                prioridad = Option.map Atomo.prioridad_valida (Json_llm.entero j "prioridad");
                fechas = List.filter es_fecha (Json_llm.textos j "fechas") }
            in
            match Option.bind (Json_llm.texto j "accion") accion_de_texto with
            | None | Some Guardar -> { d with accion = Guardar; objetivos = [] }
            | Some Saltar -> { d with accion = Saltar }
            | Some ((Actualizar | Fusionar) as a) -> if objetivos = [] then guardar c else { d with accion = a })
      in
      Ok (List.map decidir casos)
  | Ok _ -> Error "la respuesta no es un array"

(* {1 El plan} *)

(* La prioridad de una fusión: -1 manda; si no, la mayor. *)
let fundir ps = if List.mem (-1) ps then -1 else List.fold_left max 0 ps

let plan casos decisiones =
  (* El estado de cada id tocado en el lote: su última versión, o None si
     quedó absorbido. *)
  let estado : (string, Atomo.t option) Hashtbl.t = Hashtbl.create 16 in
  let actual (a : Atomo.t) = match Hashtbl.find_opt estado a.id with Some e -> e | None -> Some a in
  let filas = ref [] in
  let escribir (a : Atomo.t) =
    Hashtbl.replace estado a.id (if a.vigente then Some a else None);
    filas := a :: !filas
  in
  List.iter
    (fun c ->
      let d = Option.value ~default:(guardar c) (List.find_opt (fun d -> d.caso = c.etiqueta) decisiones) in
      let guardar_nuevo () =
        let a = Atomo.de_nuevo c.nuevo in
        if not (Hashtbl.mem estado a.id) then escribir a
      in
      match d.accion with
      | Guardar -> guardar_nuevo ()
      | Saltar -> ()
      | Actualizar | Fusionar -> (
          let objetivos =
            List.filter_map
              (fun id -> Option.bind (List.find_opt (fun (a : Atomo.t) -> a.id = id) c.candidatos) actual)
              d.objetivos
          in
          match objetivos with
          | [] -> guardar_nuevo ()
          | primero :: absorbidos ->
              let todos = primero :: absorbidos in
              let prioridad =
                let del_juez = Option.value ~default:c.nuevo.prioridad d.prioridad in
                if d.accion = Fusionar then fundir (del_juez :: c.nuevo.prioridad :: List.map (fun (a : Atomo.t) -> a.prioridad) todos)
                else del_juez
              in
              let union_de f = List.fold_left (fun acc a -> Atomo.union acc (f a)) [] todos in
              escribir
                { primero with
                  version = primero.version + 1;
                  vigente = true;
                  tipo = Option.value ~default:c.nuevo.tipo d.tipo;
                  prioridad;
                  escena = (if primero.escena = "" then c.nuevo.escena else primero.escena);
                  contenido = Option.value ~default:c.nuevo.contenido d.contenido;
                  origen = Atomo.union (union_de (fun (a : Atomo.t) -> a.origen)) c.nuevo.origen;
                  fechas = Atomo.union (Atomo.union (union_de (fun (a : Atomo.t) -> a.fechas)) c.nuevo.fechas) d.fechas };
              List.iter (fun (a : Atomo.t) -> escribir { a with version = a.version + 1; vigente = false }) absorbidos))
    casos;
  List.rev !filas
