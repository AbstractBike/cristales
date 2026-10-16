(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let salida evento campos =
  Yojson.Safe.to_string
    (`Assoc [ ("hookSpecificOutput", `Assoc (("hookEventName", `String evento) :: campos)) ])

let contexto = function
  | [] -> None
  | agentes ->
      let lineas = List.map (fun (n, d) -> Printf.sprintf "- `%s`: %s" n d) agentes in
      let texto =
        String.concat "\n"
          ([ "# La agencia (agencia.pin)";
             "";
             "Antes de hacer tú una transformación con instrucciones fijas (traducir, clasificar, extraer, resumir, \
              reescribir, redactar con plantilla), encárgasela a un agente: un modelo pequeño o un cristal cuesta \
              mucho menos que tú. Estos ya existen (herramienta `mcp__agencia__<nombre>` o `agencia_encargar`):";
             "" ]
          @ lineas
          @ [ "";
              "Si ninguno sirve y la harías igual otra vez, créalo con `agencia_crear`. Los cristales \
               (`mcp__cristales__*`) son gratis: si uno cubre la tarea, va antes. Juzga cada encargo con \
               `agencia_juzgar`: sin veredictos la agencia no aprende a qué modelo pedir." ])
      in
      Some (salida "SessionStart" [ ("additionalContext", `String texto) ])

(* «… Júzgalo con agencia_juzgar (agente traductor-markdown, id 0123abcd…)»:
   la meta que agencia-mcp pone en cada resultado. *)
let patron = Str.regexp "agencia_juzgar (agente \\([a-z0-9-]+\\), id \\([0-9a-f]+\\))"

let rec cadenas acc = function
  | `String s -> s :: acc
  | `Assoc kv -> List.fold_left (fun acc (_, v) -> cadenas acc v) acc kv
  | `List l -> List.fold_left cadenas acc l
  | _ -> acc

let encargados s =
  let rec desde i acc =
    match Str.search_forward patron s i with
    | exception Not_found -> List.rev acc
    | _ -> desde (Str.match_end ()) ((Str.matched_group 1 s, Str.matched_group 2 s) :: acc)
  in
  desde 0 []

(* Las llamadas a agencia_juzgar: el id de su entrada. *)
let rec juzgados acc = function
  | `Assoc kv -> (
      let acc = List.fold_left (fun acc (_, v) -> juzgados acc v) acc kv in
      match (List.assoc_opt "name" kv, List.assoc_opt "input" kv) with
      | Some (`String n), Some (`Assoc input) when String.ends_with ~suffix:"agencia_juzgar" n -> (
          match List.assoc_opt "id" input with Some (`String id) -> id :: acc | _ -> acc)
      | _ -> acc)
  | `List l -> List.fold_left juzgados acc l
  | _ -> acc

let pendientes lineas =
  let juzgados = List.fold_left juzgados [] lineas in
  let vistos = Hashtbl.create 16 in
  List.concat_map
    (fun l ->
      (* Solo los resultados de herramienta: una llamada a agencia_juzgar
         que cita la meta no es un encargo. *)
      let es_resultado = function `Assoc kv -> List.assoc_opt "type" kv = Some (`String "tool_result") | _ -> false in
      let rec resultados acc = function
        | `Assoc kv as j when es_resultado j -> cadenas acc (`Assoc kv)
        | `Assoc kv -> List.fold_left (fun acc (_, v) -> resultados acc v) acc kv
        | `List l -> List.fold_left resultados acc l
        | _ -> acc
      in
      List.concat_map encargados (List.rev (resultados [] l)))
    lineas
  |> List.filter (fun (_, id) ->
         if List.mem id juzgados || Hashtbl.mem vistos id then false
         else (
           Hashtbl.add vistos id ();
           true))

let bloqueo = function
  | [] -> None
  | ps ->
      let lista = String.concat ", " (List.map (fun (a, id) -> Printf.sprintf "%s/%s" a id) ps) in
      Some
        (Yojson.Safe.to_string
           (`Assoc
             [ ("decision", `String "block");
               ( "reason",
                 `String
                   (Printf.sprintf
                      "Quedan %d encargos de la agencia sin juzgar (%s). Si sabes si salieron bien, júzgalos con \
                       agencia_juzgar (bien/mal, con nota y, si la retocaste, salida_corregida); si no lo sabes, \
                       dilo en una línea y termina."
                      (List.length ps) lista) ) ]))
