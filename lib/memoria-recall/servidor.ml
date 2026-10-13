(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Mcp_rpc

type efectos = { sql : string -> (Yojson.Safe.t list, string) result; repo : string; tablas : Consulta.tablas }

let instrucciones =
  "Memoria de sesiones anteriores de Claude Code: átomos (hechos, reglas, métodos), conversaciones y \
   escenas. Búscala antes de decidir algo que pudo decidirse antes, y cuando el usuario diga «como \
   hicimos…», «ya lo hablamos» o «lo de siempre». memoria_buscar para hechos y reglas sueltos, \
   memoria_conversacion para lo que se dijo literalmente, memoria_escena para un tema entero del índice \
   que se inyecta al arrancar. Lo que devuelve es referencia del pasado, no el estado de la tarea: \
   puede estar desfasado, compruébalo contra el código y la flota antes de actuar."

let fecha_de_ms ms =
  let t = Unix.gmtime (float_of_int ms /. 1000.) in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d" (t.tm_year + 1900) (t.tm_mon + 1) t.tm_mday t.tm_hour t.tm_min

(* {1 Argumentos} *)

let ( let* ) = Result.bind

let texto_de args k =
  match argumento args k with
  | Ok (Some (`String s)) -> ( match String.trim s with "" -> Ok None | s -> Ok (Some s))
  | Ok (Some `Null) | Ok None -> Ok None
  | Ok (Some _) -> invalido (k ^ ": tiene que ser texto")
  | Error e -> Error e

let requerido args k =
  let* v = texto_de args k in
  match v with Some s -> Ok s | None -> invalido ("falta " ^ k ^ " (texto)")

let limite_de args defecto =
  match argumento args "limite" with
  | Ok (Some (`Int n)) when n >= 1 -> Ok (min n 50)
  | Ok (Some (`Int _)) -> invalido "limite: al menos 1"
  | Ok (Some `Null) | Ok None -> Ok defecto
  | Ok (Some _) -> invalido "limite: tiene que ser un entero"
  | Error e -> Error e

let terminos_de consulta =
  match Consulta.terminos consulta with
  | [] -> invalido "consulta: sin palabras que buscar (letras o dígitos, dos como mínimo)"
  | ts -> Ok ts

(* {1 Filas} *)

let str = function `String s -> s | `Null -> "" | j -> Yojson.Safe.to_string j
let int_de = function `Int n -> n | `Intlit s -> int_of_string_opt s |> Option.value ~default:0 | _ -> 0

let error_sql e =
  Ok
    (texto ~error:true
       ("GreptimeDB no respondió como se esperaba (¿la memoria aún no tiene esa tabla?): " ^ e))

let rec tomar n = function [] -> [] | _ when n <= 0 -> [] | x :: xs -> x :: tomar (n - 1) xs

(* Orden estable: más términos encontrados, y luego lo que diga [despues]. *)
let ordenar terminos texto_de despues filas =
  List.map (fun f -> (Consulta.aciertos terminos (texto_de f), f)) filas
  |> List.stable_sort (fun (a, x) (b, y) -> match compare b a with 0 -> despues x y | c -> c)
  |> List.map snd

(* {1 memoria_buscar} *)

type atomo = {
  ts : int; id : string; version : int; tipo : string; prioridad : int;
  escena : string; contenido : string; proyecto : string; fechas : string;
}

let atomo = function
  | `List [ ts; id; v; tipo; p; escena; contenido; proyecto; fechas ] ->
      Some { ts = int_de ts; id = str id; version = int_de v; tipo = str tipo; prioridad = int_de p;
             escena = str escena; contenido = str contenido; proyecto = str proyecto;
             fechas = str fechas }
  | _ -> None

(* -1 es la regla global absoluta: va antes que cualquier 100. *)
let peso a = if a.prioridad < 0 then 1000 else a.prioridad

let buscar ef args =
  let* consulta = requerido args "consulta" in
  let* terminos = terminos_de consulta in
  let* tipo = texto_de args "tipo" in
  let* () =
    match tipo with
    | Some t when not (List.mem t Consulta.tipos) -> invalido ("tipo: uno de " ^ String.concat ", " Consulta.tipos)
    | _ -> Ok ()
  in
  let* proyecto = texto_de args "proyecto" in
  let* limite = limite_de args 8 in
  match ef.sql (Consulta.atomos ef.tablas ~terminos ?tipo ?proyecto ()) with
  | Error e -> error_sql e
  | Ok filas -> (
      let candidatos = List.filter_map atomo filas in
      (* De cada id, la versión más alta vista entre los que casan. *)
      let mejor = Hashtbl.create 16 in
      List.iter
        (fun a ->
          match Hashtbl.find_opt mejor a.id with
          | Some b when b.version >= a.version -> ()
          | _ -> Hashtbl.replace mejor a.id a)
        candidatos;
      let ids = Hashtbl.to_seq_keys mejor |> List.of_seq |> List.sort compare in
      if ids = [] then Ok (texto (Printf.sprintf "Nada en la memoria para «%s»." consulta))
      else
        (* Y solo si es la última versión del átomo: una más nueva que no
           case (o descartada) manda sobre ella. *)
        match ef.sql (Consulta.ultimas ef.tablas ids) with
        | Error e -> error_sql e
        | Ok maximas ->
            let maxima = Hashtbl.create 16 in
            List.iter (function `List [ id; v ] -> Hashtbl.replace maxima (str id) (int_de v) | _ -> ()) maximas;
            let vigentes =
              List.filter_map
                (fun id ->
                  let a = Hashtbl.find mejor id in
                  match Hashtbl.find_opt maxima id with Some v when v > a.version -> None | _ -> Some a)
                ids
            in
            let ordenados =
              ordenar terminos (fun a -> a.contenido)
                (fun x y -> match compare (peso y) (peso x) with 0 -> compare y.ts x.ts | c -> c)
                vigentes
              |> tomar limite
            in
            if ordenados = [] then Ok (texto (Printf.sprintf "Nada vigente en la memoria para «%s»." consulta))
            else
              let linea a =
                Printf.sprintf "- [%s v%d] %s, prioridad %d, escena %s, %s%s\n  %s\n  fechas: %s" a.id a.version
                  a.tipo a.prioridad (if a.escena = "" then "-" else a.escena) (fecha_de_ms a.ts)
                  (if a.proyecto = "" then "" else ", " ^ a.proyecto)
                  a.contenido (if a.fechas = "" then "[]" else a.fechas)
              in
              Ok
                (texto
                   (Printf.sprintf "%d átomos vigentes para «%s» (referencia, no estado de la tarea):\n%s"
                      (List.length ordenados) consulta (String.concat "\n" (List.map linea ordenados)))))

(* {1 memoria_conversacion} *)

type mensaje = { ts : int; sesion : string; proyecto : string; rol : string; texto : string }

let mensaje = function
  | `List [ ts; sesion; proyecto; rol; texto ] ->
      Some { ts = int_de ts; sesion = str sesion; proyecto = str proyecto; rol = str rol; texto = str texto }
  | _ -> None

let conversacion ef args =
  let* consulta = requerido args "consulta" in
  let* terminos = terminos_de consulta in
  let* proyecto = texto_de args "proyecto" in
  let* desde =
    let* d = texto_de args "desde" in
    match d with
    | None -> Ok None
    | Some d -> ( match Consulta.fecha d with Ok f -> Ok (Some f) | Error e -> invalido ("desde: " ^ e))
  in
  let* limite = limite_de args 10 in
  match ef.sql (Consulta.mensajes ef.tablas ~terminos ?proyecto ?desde ()) with
  | Error e -> error_sql e
  | Ok filas ->
      let ms =
        List.filter_map mensaje filas
        |> ordenar terminos (fun (m : mensaje) -> m.texto) (fun (x : mensaje) y -> compare y.ts x.ts)
        |> tomar limite
      in
      if ms = [] then Ok (texto (Printf.sprintf "Nada en las conversaciones para «%s»." consulta))
      else
        let linea (m : mensaje) =
          Printf.sprintf "- %s · sesión %s · %s%s\n  %s" (fecha_de_ms m.ts) m.sesion m.rol
            (if m.proyecto = "" then "" else " · " ^ m.proyecto)
            (Consulta.extracto terminos m.texto)
        in
        Ok
          (texto
             (Printf.sprintf "%d mensajes para «%s» (referencia, no estado de la tarea):\n%s" (List.length ms)
                consulta (String.concat "\n" (List.map linea ms))))

(* {1 memoria_escena} *)

let escena ef args =
  let* slug = requerido args "slug" in
  match Escenas.escena ef.repo slug with Ok md -> Ok (texto md) | Error e -> Ok (texto ~error:true e)

(* {1 Servidor} *)

let herramientas () =
  [ herramienta "memoria_buscar"
      "Átomos vigentes de la memoria (hechos, reglas, preferencias, métodos, episodios) que casan con la \
       consulta por texto completo; los que más términos casan primero y, a igualdad, por prioridad. \
       Devuelve id, tipo, prioridad, escena, contenido y fechas."
      (esquema ~requeridos:[ "consulta" ]
         [ ("consulta", cadena);
           ("tipo", `Assoc [ ("type", `String "string"); ("enum", `List (List.map (fun t -> `String t) Consulta.tipos)) ]);
           ("proyecto", `Assoc [ ("type", `String "string"); ("description", `String "Trozo de la ruta del proyecto (cwd), p. ej. nixos-config") ]);
           ("limite", `Assoc [ ("type", `String "integer"); ("description", `String "Cuántos (8 por defecto, 50 como mucho)") ]) ]);
    herramienta "memoria_conversacion"
      "Mensajes de sesiones anteriores (usuario y asistente; sin la salida de las herramientas) que casan \
       con la consulta por texto completo: sesión, fecha, rol y un extracto."
      (esquema ~requeridos:[ "consulta" ]
         [ ("consulta", cadena);
           ("proyecto", `Assoc [ ("type", `String "string"); ("description", `String "Trozo de la ruta del proyecto (cwd)") ]);
           ("desde", `Assoc [ ("type", `String "string"); ("description", `String "AAAA-MM-DD o AAAA-MM-DD HH:MM (UTC)") ]);
           ("limite", `Assoc [ ("type", `String "integer"); ("description", `String "Cuántos (10 por defecto, 50 como mucho)") ]) ]);
    herramienta "memoria_escena"
      "El Markdown entero de una escena de la memoria (un tema consolidado), por su slug del índice que se \
       inyecta al arrancar la sesión."
      (esquema ~requeridos:[ "slug" ] [ ("slug", cadena) ]) ]

let servidor ef =
  { nombre = "memoria";
    version = "0.1.0";
    instrucciones = (fun () -> instrucciones);
    herramientas;
    llamar =
      (fun nombre args ->
        match nombre with
        | "memoria_buscar" -> buscar ef args
        | "memoria_conversacion" -> conversacion ef args
        | "memoria_escena" -> escena ef args
        | n -> invalido (n ^ ": no hay tal herramienta")) }
