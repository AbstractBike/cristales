(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Agencia

(* {1 JSON} *)

let recortar n s = if String.length s <= n then s else String.sub s 0 n ^ "…"
let nivel = function Fiable -> "fiable" | Descartado -> "descartado" | Por_ver -> "por ver"

let json_cuenta (c : cuenta) =
  `Assoc
    [ ("modelo", `String (Modelo.to_string c.modelo));
      ("nivel", `String (nivel c.nivel));
      ("encargos", `Int c.encargos);
      ("juzgados", `Int c.juzgados);
      ("bien", `Int c.bien);
      ("errores", `Int c.errores);
      ("ms_medio", `Int c.ms_medio);
      ("tokens", `Int c.tokens) ]

let json_agente_con politica ?(instrucciones = false) (a : Agente.t) es =
  let siguiente = elegir ~politica a es in
  `Assoc
    ([ ("nombre", `String (Forja.Tarea.to_string a.nombre));
       ("descripcion", `String a.descripcion);
       ("version", `String (Agente.version a));
       ("escalera", `List (List.map (fun m -> `String (Modelo.to_string m)) a.escalera));
       ("defecto", `String (Modelo.to_string a.defecto));
       ("max_tokens", `Int a.max_tokens) ]
    @ (if instrucciones then [ ("instrucciones", `String a.instrucciones) ] else [])
    @ [ ( "siguiente",
          `Assoc
            [ ("modelo", `String (Modelo.to_string siguiente.modelo));
              ("motivo", `String siguiente.motivo) ] );
        ("modelos", `List (List.map json_cuenta (cuentas ~politica a es))) ])

let json_agente (archivo : Archivo.t) politica ?instrucciones (a : Agente.t) =
  json_agente_con politica ?instrucciones a (archivo.historial a.nombre)

let json_encargo ?(recorte = 200) (e : Encargo.t) =
  `Assoc
    ([ ("id", `String e.id);
       ("modelo", `String e.modelo);
       ("motivo", `String e.motivo);
       ("fuente", `String e.fuente);
       ("version", `String e.version);
       ("ms", `Int e.ms);
       ("tokens", `Int (e.tokens_entrada + e.tokens_salida));
       ("veredicto", match e.veredicto with Some v -> `String (veredicto_a_texto v) | None -> `Null);
       ("entrada", `String (recortar recorte e.entrada)) ]
    @ (if e.nota = "" then [] else [ ("nota", `String e.nota) ])
    @
    match e.salida with
    | Ok s -> [ ("salida", `String (recortar (recorte * 5 / 2) s)) ]
    | Error m -> [ ("error", `String m) ])

let json_historico (archivo : Archivo.t) politica ?recorte ~ultimos (a : Agente.t) =
  let es = archivo.historial a.nombre in
  let recientes = List.filteri (fun i _ -> i >= List.length es - ultimos) es |> List.rev in
  `Assoc
    [ ("agente", json_agente_con politica ~instrucciones:true a es);
      ("encargos", `Int (List.length es));
      ("ultimos", `List (List.map (json_encargo ?recorte) recientes)) ]

(* {1 API} *)

type respuesta = { estado : int; tipo : string; cuerpo : string }

let json estado j = { estado; tipo = "application/json"; cuerpo = Yojson.Safe.to_string j }
let error estado m = json estado (`Assoc [ ("error", `String m) ])

let politica_json (p : Politica.t) =
  `Assoc
    [ ("juicios", `Int p.juicios); ("acierto", `Float p.acierto); ("explorar_cada", `Int p.explorar_cada) ]

let entero query k ~defecto ~max =
  match List.assoc_opt k query with
  | Some [ s ] -> Option.value ~default:defecto (int_of_string_opt s) |> Int.max 0 |> Int.min max
  | _ -> defecto

(* La página enseña los encargos enteros, o casi: más margen que el MCP,
   que los mete en el contexto de otro modelo. *)
let recorte_vista = 4000

let atender (archivo : Archivo.t) politica ~meth ~ruta ~query =
  match (meth, String.split_on_char '/' ruta) with
  | `GET, [ ""; "agencia"; "politica" ] -> Some (json 200 (politica_json politica))
  | `GET, [ ""; "agencia"; "agentes" ] ->
      Some (json 200 (`List (List.map (json_agente archivo politica) (archivo.agentes ()))))
  | `GET, [ ""; "agencia"; "agentes"; n ] -> (
      match List.find_opt (fun (a : Agente.t) -> Forja.Tarea.to_string a.nombre = n) (archivo.agentes ()) with
      | None -> Some (error 404 ("agencia: no hay tal agente: " ^ n))
      | Some a ->
          let ultimos = entero query "encargos" ~defecto:20 ~max:1000 in
          Some (json 200 (json_historico archivo politica ~recorte:recorte_vista ~ultimos a)))
  | `GET, "" :: "agencia" :: _ -> Some (error 404 ("agencia: no existe " ^ ruta))
  | _, "" :: "agencia" :: _ -> Some (error 405 "agencia: solo lectura")
  | _ -> None
