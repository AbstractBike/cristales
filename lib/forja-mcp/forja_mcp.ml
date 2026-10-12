(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let version = Mcp_rpc.version

type cristal = { nombre : string; descripcion : string }
type aplicado = Salida of string | Defecto of string | No_existe | Fallo of string

type fuente = {
  cristales : unit -> (cristal list, string) result;
  aplicar : string -> string -> aplicado;
  consultar : (string -> (string, string) result) option;
}

let local vitrina =
  { cristales =
      (fun () ->
        Ok
          (List.map
             (fun (p : Forja.Vitrina.pieza) ->
               { nombre = Forja.Tarea.to_string p.tarea; descripcion = p.descripcion })
             (Forja.Vitrina.listar vitrina)));
    aplicar =
      (fun n e ->
        match Result.to_option (Forja.Tarea.explicita n) |> Option.map (Forja.Vitrina.buscar vitrina) with
        | None | Some None -> No_existe
        | Some (Some (_, c)) -> ( match c.aplicar e with Ok s -> Salida s | Error m -> Defecto m));
    consultar = None }

(* {1 Herramientas} *)

open Mcp_rpc

(* Las fijas: nombre, descripción, esquema y la ruta de la API a la que
   llaman, a partir de los argumentos ya validados. *)
type fija = { nombre : string; descripcion : string; esquema : Yojson.Safe.t; ruta : string -> int -> string }

let tarea = [ ("tarea", cadena) ]

let fijas =
  [ { nombre = "forja_tareas";
      descripcion =
        "Tareas que han pasado por la forja: fase (liquida, mixta o cristalina), muestras en la \
         cantera, contrastes, coincidencias y si ya está madura para nuclear.";
      esquema = esquema [];
      ruta = (fun _ _ -> "/forja/tareas") };
    { nombre = "forja_tarea";
      descripcion =
        "Detalle de una tarea de la forja: su informe, su plantilla (las instrucciones fijas) y \
         sus últimas muestras de la cantera.";
      esquema = esquema ~requeridos:[ "tarea" ] (tarea @ [ ("muestras", entero) ]);
      ruta = (fun t n -> Printf.sprintf "/forja/tareas/%s?muestras=%d" t n) };
    { nombre = "forja_semilla";
      descripcion =
        "SEMILLA.md de una tarea: la plantilla y las muestras de la cantera, en el formato con el \
         que se nuclea un cristal.";
      esquema = esquema ~requeridos:[ "tarea" ] tarea;
      ruta = (fun t _ -> Printf.sprintf "/forja/tareas/%s/semilla" t) };
    { nombre = "forja_nucleacion";
      descripcion =
        "Prompt de nucleación de una tarea: lo que se le pide al LLM para que escriba el cristal \
         (el método, no el resultado).";
      esquema = esquema ~requeridos:[ "tarea" ] tarea;
      ruta = (fun t _ -> Printf.sprintf "/forja/tareas/%s/nucleacion" t) } ]

let listar fuente =
  let fijas =
    if fuente.consultar = None then []
    else List.map (fun f -> herramienta f.nombre f.descripcion f.esquema) fijas
  in
  let cristales =
    match fuente.cristales () with
    | Ok cs ->
        List.map
          (fun (c : cristal) -> herramienta c.nombre c.descripcion (esquema ~requeridos:[ "entrada" ] [ ("entrada", cadena) ]))
          cs
    | Error e ->
        prerr_endline ("forja-mcp: sin vitrina: " ^ e);
        []
  in
  fijas @ cristales

(* {1 Llamadas} *)

let ( let* ) = Result.bind

let nombre_de_tarea n =
  match Forja.Tarea.explicita n with Ok _ -> Ok n | Error _ -> invalido (n ^ ": no es un nombre de tarea")

let llamar_fija consultar (f : fija) args =
  let* t =
    if f.nombre = "forja_tareas" then Ok ""
    else
      match argumento args "tarea" with
      | Ok (Some (`String t)) -> nombre_de_tarea t
      | Ok _ -> invalido (f.nombre ^ ": falta tarea (texto)")
      | Error e -> Error e
  in
  let* n =
    match argumento args "muestras" with
    | Ok None -> Ok 5
    | Ok (Some (`Int n)) when n >= 0 && n <= 1000 -> Ok n
    | Ok (Some _) -> invalido "muestras: entero de 0 a 1000"
    | Error e -> Error e
  in
  Ok (match consultar (f.ruta t n) with Ok s -> texto s | Error e -> texto ~error:true e)

let llamar_cristal fuente n args =
  let* n = nombre_de_tarea n in
  match argumento args "entrada" with
  | Ok (Some (`String e)) -> (
      match fuente.aplicar n e with
      | Salida s -> Ok (texto s)
      (* Un defecto no es un fallo del protocolo: es un resultado con
         isError, para que el modelo lo lea y siga. *)
      | Defecto m -> Ok (texto ~error:true ("defecto: " ^ m))
      | No_existe -> invalido (n ^ ": no hay tal cristal en la vitrina")
      | Fallo e -> Ok (texto ~error:true e))
  | Ok _ -> invalido (n ^ ": falta arguments.entrada (texto)")
  | Error e -> Error e

let llamar fuente n args =
  match (fuente.consultar, List.find_opt (fun f -> f.nombre = n) fijas) with
  | Some consultar, Some f -> llamar_fija consultar f args
  | _ -> llamar_cristal fuente n args

(* {1 Instrucciones}

   Lo que el cliente pone en el prompt de sistema del agente (Claude Code
   las lleva a cada sesión): para que use los cristales en vez de
   resolverlo él y para que nuclee lo que la forja tiene maduro. *)

let uso =
  "Cada herramienta de este servidor que no empieza por forja_ es un cristal: una función \
   determinista, revisada y versionada, que no gasta tokens. Si la tarea que tienes delante \
   la cubre un cristal (lee su descripción), llámalo en vez de resolverla tú. Un defecto \
   (isError) no es un fallo: resuélvelo tú y sigue; queda en la cantera como semilla de la \
   siguiente versión del cristal."

let nuclear =
  "Los cristales se crean desde la forja. forja_tareas dice qué tareas han pasado por ella y \
   cuáles están maduras (el LLM se repite: tiene un método que dar). Para nuclear una \
   madura: forja_nucleacion da el prompt y forja_semilla las muestras; escribe el cristal en \
   el repo cristales (/logical-node/repositories/logical-license/cristales, en un \
   workbench) según doc/anatomia.md, con su SEMILLA.md, procedencia.sexp y su red, \
   regístralo en lib/vitrina/vitrina.ml y commitéalo. Si en tu trabajo resuelves razonando \
   una transformación de texto con instrucciones fijas que darías igual dos veces, es \
   candidata a cristal: díselo al usuario."

let maduras cuerpo =
  let open Yojson.Safe.Util in
  try
    Yojson.Safe.from_string cuerpo |> to_list
    |> List.filter_map (fun t ->
           match (t |> member "madura", t |> member "tarea", t |> member "muestras") with
           | `Bool true, `String n, `Int m -> Some (Printf.sprintf "%s (%d muestras)" n m)
           | `Bool true, `String n, _ -> Some n
           | _ -> None)
    |> Option.some
  with _ -> None

let instrucciones fuente =
  match fuente.consultar with
  | None -> uso
  | Some consultar ->
      let ahora =
        match Option.bind (Result.to_option (consultar "/forja/tareas")) maduras with
        | None -> []
        | Some [] -> [ "Ahora mismo ninguna tarea de la forja está madura." ]
        | Some ts ->
            [ "Ahora mismo están maduras para nuclear: " ^ String.concat ", " ts
              ^ ". Díselo al usuario al empezar y ofrécete a nuclearlas." ]
      in
      String.concat "\n\n" ([ uso; nuclear ] @ ahora)

(* {1 JSON-RPC} *)

let servidor fuente =
  { Mcp_rpc.nombre = "forja-mcp";
    version = "0.2.0";
    instrucciones = (fun () -> instrucciones fuente);
    herramientas = (fun () -> listar fuente);
    llamar = llamar fuente }

let responder fuente = Mcp_rpc.responder (servidor fuente)
let linea fuente = Mcp_rpc.linea (servidor fuente)
