(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Agencia

(* Columnas y valores van juntos: la fila que se ingiere y la que se lee
   tienen el mismo orden. *)
let columnas_agente = [ "nombre"; "descripcion"; "instrucciones"; "escalera"; "defecto"; "max_tokens"; "ejemplos" ]

(* Las filas de antes de [ejemplos] no la tienen (ni la tabla, hasta que
   se guarde el primer agente con ella: la ingesta añade la columna). *)
let columnas_agente_viejas = List.filter (( <> ) "ejemplos") columnas_agente

let fila_agente (a : Agente.t) =
  `List
    [ `String (Forja.Tarea.to_string a.nombre);
      `String a.descripcion;
      `String a.instrucciones;
      `String (String.concat "," (List.map Modelo.to_string a.escalera));
      `String (Modelo.to_string a.defecto);
      `Int a.max_tokens;
      `Int a.ejemplos ]

let modelos s = List.filter_map (fun m -> Result.to_option (Modelo.de_texto m)) (String.split_on_char ',' s)

let agente fila =
  let fila, ejemplos =
    match fila with
    | `List [ n; d; i; e; f; m; `Int k ] -> (`List [ n; d; i; e; f; m ], Some k)
    | `List [ n; d; i; e; f; m; `Null ] | `List [ n; d; i; e; f; m ] -> (`List [ n; d; i; e; f; m ], None)
    | f -> (f, None)
  in
  match fila with
  | `List [ `String nombre; `String descripcion; `String instrucciones; `String escalera; `String defecto; `Int max_tokens ]
    -> (
      match Modelo.de_texto defecto with
      | Error _ -> None
      | Ok defecto ->
          Result.to_option
            (Agente.crear ~nombre ~descripcion ~instrucciones ~escalera:(modelos escalera) ~defecto ~max_tokens ?ejemplos ()))
  | _ -> None

let columnas_encargo =
  [ "id"; "agente"; "version"; "modelo"; "motivo"; "fuente"; "entrada"; "ok"; "salida"; "ms";
    "tokens_entrada"; "tokens_salida" ]

(* El error va en [salida] con [ok] a falso. *)
let fila_encargo (e : Encargo.t) =
  let ok, salida = match e.salida with Ok s -> (true, s) | Error m -> (false, m) in
  `List
    [ `String e.id;
      `String (Forja.Tarea.to_string e.agente);
      `String e.version;
      `String e.modelo;
      `String e.motivo;
      `String e.fuente;
      `String e.entrada;
      `Bool ok;
      `String salida;
      `Int e.ms;
      `Int e.tokens_entrada;
      `Int e.tokens_salida ]

let encargo = function
  | `List
      [ `String id; `String agente; `String version; `String modelo; `String motivo; `String fuente;
        `String entrada; `Bool ok; `String salida; `Int ms; `Int tokens_entrada; `Int tokens_salida ] -> (
      match Forja.Tarea.explicita agente with
      | Error _ -> None
      | Ok agente ->
          Some
            { Encargo.id; agente; version; modelo; motivo; fuente; entrada;
              salida = (if ok then Ok salida else Error salida);
              ms; tokens_entrada; tokens_salida; veredicto = None; nota = ""; corregida = None })
  | _ -> None

let columnas_veredicto = [ "id"; "agente"; "veredicto"; "nota"; "salida_corregida" ]

(* Como en los agentes: las filas y la tabla de antes no la tienen. *)
let columnas_veredicto_viejas = List.filter (( <> ) "salida_corregida") columnas_veredicto

let fila_veredicto ?corregida t id v nota =
  `List
    [ `String id; `String (Forja.Tarea.to_string t); `String (veredicto_a_texto v); `String nota;
      `String (Option.value ~default:"" corregida) ]

(* Id, veredicto, nota y salida corregida (vacía o nula: no la hay). *)
let veredicto = function
  | `List [ `String id; _; `String v; `String nota ] -> Option.map (fun v -> (id, v, nota, None)) (veredicto_de_texto v)
  | `List [ `String id; _; `String v; `String nota; c ] ->
      let c = match c with `String c when c <> "" -> Some c | _ -> None in
      Option.map (fun v -> (id, v, nota, c)) (veredicto_de_texto v)
  | _ -> None

let objeto columnas = function
  | `List vs -> `Assoc (List.combine columnas vs)
  | _ -> invalid_arg "Archivo_greptime.objeto"

let crear ~post ~url ?(db = "agencia") () =
  let g = Forja_http.Greptime.conectar ~post ~url ~db in
  let ingerir tabla columnas fila = Forja_http.Greptime.ingerir g ~tabla (objeto columnas fila) in
  let select columnas tabla donde =
    Forja_http.Greptime.leer g
      (Printf.sprintf "SELECT %s FROM %s%s ORDER BY greptime_timestamp" (String.concat ", " columnas) tabla donde)
  in
  (* Los nombres de agente son [a-z0-9-] y los ids hex: se citan sin
     escapar. *)
  let de_agente t = Printf.sprintf " WHERE agente = '%s'" (Forja.Tarea.to_string t) in
  let agentes () =
    let ultimos = Hashtbl.create 16 in
    let filas =
      match select columnas_agente "agencia_agentes" "" with
      | [] -> select columnas_agente_viejas "agencia_agentes" ""
      | filas -> filas
    in
    List.iter (fun f -> Option.iter (fun (a : Agente.t) -> Hashtbl.replace ultimos a.nombre a) (agente f)) filas;
    Hashtbl.to_seq_values ultimos |> List.of_seq |> List.sort (fun (a : Agente.t) b -> compare a.nombre b.nombre)
  in
  let historial t =
    let veredictos = Hashtbl.create 16 in
    let filas =
      match select columnas_veredicto "agencia_veredictos" (de_agente t) with
      | [] -> select columnas_veredicto_viejas "agencia_veredictos" (de_agente t)
      | filas -> filas
    in
    List.iter
      (fun f -> Option.iter (fun (id, v, nota, c) -> Hashtbl.replace veredictos id (v, nota, c)) (veredicto f))
      filas;
    select columnas_encargo "agencia_encargos" (de_agente t)
    |> List.filter_map encargo
    |> List.map (fun (e : Encargo.t) ->
           match Hashtbl.find_opt veredictos e.id with
           | Some (v, nota, corregida) -> { e with veredicto = Some v; nota; corregida }
           | None -> e)
  in
  { Archivo.guardar = (fun a -> ingerir "agencia_agentes" columnas_agente (fila_agente a));
    agentes;
    registrar = (fun e -> ingerir "agencia_encargos" columnas_encargo (fila_encargo e));
    juzgar =
      (fun ?corregida t id v nota ->
        ingerir "agencia_veredictos" columnas_veredicto (fila_veredicto ?corregida t id v nota));
    historial }
