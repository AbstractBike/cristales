(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type post = Greptime.post

let columnas =
  [ "tarea"; "plantilla"; "entrada"; "salida"; "contrastada"; "contraste"; "defecto"; "respondida"; "ejemplos" ]

(* Las columnas opcionales se escriben siempre (cadena vacía si no hay) para
   que existan desde la primera fila y el SELECT no falle. *)
let json (m : Forja.Cantera.muestra) =
  let s x = `String x and o x = `String (Option.value ~default:"" x) in
  `Assoc
    [ ("tarea", s (Forja.Tarea.to_string m.tarea));
      ("plantilla", s m.plantilla);
      ("entrada", s m.entrada);
      ("salida", o m.salida);
      ("contrastada", `Bool (Option.is_some m.contraste));
      ("contraste", o m.contraste);
      ("defecto", o m.defecto);
      ("respondida", `Bool (Option.is_some m.salida));
      ("ejemplos", `Bool m.ejemplos) ]

let rec fila = function
  (* Una fila de antes de [ejemplos] (o leída sin ella). *)
  | `List ([ _; _; _; _; _; _; _; _ ] as l) -> fila (`List (l @ [ `Null ]))
  | `List
      [ `String tarea; `String plantilla; `String entrada; `String salida;
        `Bool contrastada; `String contraste; `String defecto; respondida; ejemplos ] -> (
      match Forja.Tarea.explicita tarea with
      | Error _ -> None
      | Ok tarea ->
          Some
            { Forja.Cantera.tarea; plantilla; entrada;
              (* Las filas de antes de [respondida] la tienen a null: todas
                 venían del LLM. *)
              salida = (if respondida = `Bool false then None else Some salida);
              contraste = (if contrastada then Some contraste else None);
              defecto = (if defecto = "" then None else Some defecto);
              (* Las de antes de [ejemplos], a null: no los llevaban. *)
              ejemplos = ejemplos = `Bool true })
  | _ -> None

let filas j = List.filter_map fila (Greptime.crudas j)

let crear ~post ~url ?(db = "public") ?(tabla = "forja_cantera") () =
  let g = Greptime.conectar ~post ~url ~db in
  (* Una tabla de antes no tiene las columnas nuevas hasta la primera
     ingesta que las traiga, y el SELECT de [muestras] fallaría. Si la tabla
     aún no existe, falla sin más: la crea la primera ingesta. *)
  ignore (Greptime.sql g (Printf.sprintf "ALTER TABLE %s ADD COLUMN IF NOT EXISTS respondida BOOLEAN" tabla));
  ignore (Greptime.sql g (Printf.sprintf "ALTER TABLE %s ADD COLUMN IF NOT EXISTS ejemplos BOOLEAN" tabla));
  let registrar m = Greptime.ingerir g ~tabla (json m) in
  let leer = Greptime.leer g in
  (* La tarea es un nombre validado ([a-z0-9-]): se puede citar sin
     escapar. *)
  let muestras tarea =
    leer
      (Printf.sprintf "SELECT %s FROM %s WHERE tarea = '%s' ORDER BY greptime_timestamp"
         (String.concat ", " columnas) tabla (Forja.Tarea.to_string tarea))
    |> List.filter_map fila
  in
  let tareas () =
    leer (Printf.sprintf "SELECT DISTINCT tarea FROM %s ORDER BY tarea" tabla)
    |> List.filter_map (function
         | `List [ `String t ] -> Result.to_option (Forja.Tarea.explicita t)
         | _ -> None)
  in
  { Forja.Cantera.registrar; muestras; tareas }
