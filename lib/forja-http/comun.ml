(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let campo k = function `Assoc l -> List.assoc_opt k l | _ -> None

(* JSON con las claves ordenadas: dos respuestas iguales del LLM dan la
   misma cadena aunque cambie el orden de los campos. *)
let rec canonico = function
  | `Assoc l ->
      `Assoc (List.sort (fun (a, _) (b, _) -> compare a b) (List.map (fun (k, v) -> (k, canonico v)) l))
  | `List l -> `List (List.map canonico l)
  | j -> j

let cadena j = Yojson.Safe.to_string (canonico j)

(* El contenido es una cadena o una lista de bloques; solo vale si todos
   son de texto. Las dos APIs lo escriben igual. *)
let solo_texto = function
  | `String s -> Some s
  | `List bloques ->
      List.fold_right
        (fun b acc ->
          match (acc, campo "type" b, campo "text" b) with
          | Some ts, Some (`String "text"), Some (`String t) -> Some (t :: ts)
          | _ -> None)
        bloques (Some [])
      |> Option.map (String.concat "\n")
  | _ -> None

let objeto_json s =
  match Yojson.Safe.from_string s with
  | `Assoc _ as j -> Ok j
  | _ -> Error "la salida del cristal no es un objeto JSON"
  | exception Yojson.Json_error e -> Error ("la salida del cristal no es JSON: " ^ e)

(* {1 Esquemas: cristales parciales} *)

let cambiar k f = function
  | `Assoc l -> `Assoc (List.map (fun (k', v) -> if k' = k then (k', f v) else (k', v)) l)
  | j -> j

let propiedades esquema =
  match campo "properties" esquema with
  | Some (`Assoc l) -> List.map fst l
  | _ -> []

(* El esquema con solo [ks]: sus propiedades y, de las obligatorias, esas. *)
let restringir_esquema ks esquema =
  let solo = function
    | `Assoc l -> `Assoc (List.filter (fun (k, _) -> List.mem k ks) l)
    | j -> j
  in
  esquema
  |> cambiar "properties" solo
  |> cambiar "required" (function
       | `List l -> `List (List.filter (function `String k -> List.mem k ks | _ -> false) l)
       | j -> j)

(* {1 Ejemplos (few-shot)} *)

(* Turnos usuario/asistente alternos, de texto, que acaban en uno de
   usuario: los previos son ejemplos y el último, la entrada. *)
let ultimo_de_ejemplos turnos =
  let rol r m = campo "role" m = Some (`String r) && Option.is_some (Option.bind (campo "content" m) solo_texto) in
  let rec alternos = function
    | [ u ] when rol "user" u -> Some u
    | u :: a :: l when rol "user" u && rol "assistant" a -> alternos l
    | _ -> None
  in
  alternos turnos
