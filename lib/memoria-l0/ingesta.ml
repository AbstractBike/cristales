(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type estadisticas = {
  mutable ficheros : int;
  mutable bytes : int;
  mutable lineas : int;
  mutable mensajes : int;
  mutable usuario : int;
  mutable asistente : int;
  mutable de_subagentes : int;
  mutable truncados : int;
  mutable fallidos : int;
  redacciones : (Redaccion.tipo, int) Hashtbl.t;
  mensajes_redactados : int ref;
}

let directorios d =
  match Sys.readdir d with
  | exception Sys_error _ -> []
  | xs -> Array.to_list xs |> List.sort compare |> List.map (Filename.concat d) |> List.filter Sys.is_directory

let jsonl d =
  match Sys.readdir d with
  | exception Sys_error _ -> []
  | xs ->
      Array.to_list xs |> List.sort compare
      |> List.filter (fun f -> Filename.check_suffix f ".jsonl")
      |> List.map (Filename.concat d)

(* Los de los subagentes, también los de los workflows
   ([subagents/workflows/wf_*/agent-*.jsonl]; su [journal.jsonl] no es un
   transcript). *)
let rec agentes d =
  List.filter (fun f -> String.starts_with ~prefix:"agent-" (Filename.basename f)) (jsonl d)
  @ List.concat_map agentes (directorios d)

let ficheros raiz =
  directorios raiz
  |> List.concat_map (fun p ->
         jsonl p @ List.concat_map (fun s -> agentes (Filename.concat s "subagents")) (directorios p))

let lineas_desde f desde =
  In_channel.with_open_bin f (fun ic ->
      let tam = Int64.to_int (In_channel.length ic) in
      let desde = if desde > tam then 0 else desde in
      In_channel.seek ic (Int64.of_int desde);
      let s = really_input_string ic (tam - desde) in
      match String.rindex_opt s '\n' with
      | None -> ([], desde)
      | Some i ->
          (String.split_on_char '\n' (String.sub s 0 i) |> List.filter (( <> ) ""), desde + i + 1))

let pasar ~raiz ~cursor ?escribir ?(al_fichero = ignore) ?al_redactar () =
  let e =
    { ficheros = 0; bytes = 0; lineas = 0; mensajes = 0; usuario = 0; asistente = 0; de_subagentes = 0;
      truncados = 0; fallidos = 0; redacciones = Hashtbl.create 16; mensajes_redactados = ref 0 }
  in
  List.iter
    (fun f ->
      let desde = Cursor.desde cursor f in
      match lineas_desde f desde with
      | exception Sys_error m -> Printf.eprintf "memoria-ingesta: %s\n%!" m
      | [], _ -> ()
      | lineas, hasta ->
          e.ficheros <- e.ficheros + 1;
          e.bytes <- e.bytes + (hasta - desde);
          e.lineas <- e.lineas + List.length lineas;
          let ms = List.filter_map (Transcript.de_linea ?al_redactar:(Option.map (fun a -> a f) al_redactar)) lineas in
          List.iter
            (fun (m : Transcript.mensaje) ->
              e.mensajes <- e.mensajes + 1;
              if m.rol = "user" then e.usuario <- e.usuario + 1 else e.asistente <- e.asistente + 1;
              if m.agente <> "" then e.de_subagentes <- e.de_subagentes + 1;
              if m.truncado then e.truncados <- e.truncados + 1;
              if m.redacciones <> [] then incr e.mensajes_redactados;
              List.iter
                (fun (t, n) ->
                  Hashtbl.replace e.redacciones t (n + Option.value ~default:0 (Hashtbl.find_opt e.redacciones t)))
                m.redacciones)
            ms;
          match escribir with
          | None -> ()
          | Some escribir ->
              let errores =
                List.filter_map
                  (fun lote -> match escribir lote with Ok () -> None | Error m -> Some m)
                  (if ms = [] then [] else Tabla.lotes ms)
              in
              if errores = [] then (
                Cursor.fijar cursor f hasta;
                al_fichero f)
              else (
                e.fallidos <- e.fallidos + 1;
                Printf.eprintf "memoria-ingesta: %s: %s\n%!" f (List.hd errores)))
    (ficheros raiz);
  e

let informe e =
  let red =
    List.filter_map
      (fun t ->
        Option.map (fun n -> Printf.sprintf "  %s: %d" (Redaccion.nombre t) n) (Hashtbl.find_opt e.redacciones t))
      Redaccion.todos
  in
  String.concat "\n"
    ([ Printf.sprintf "ficheros con algo nuevo: %d" e.ficheros;
       Printf.sprintf "bytes leídos: %d" e.bytes;
       Printf.sprintf "líneas: %d" e.lineas;
       Printf.sprintf "mensajes: %d (usuario %d, asistente %d; de subagentes %d)" e.mensajes e.usuario e.asistente
         e.de_subagentes;
       Printf.sprintf "truncados: %d" e.truncados;
       Printf.sprintf "mensajes con alguna redacción: %d" !(e.mensajes_redactados);
       "redacciones por tipo:" ]
    @ red
    @ if e.fallidos > 0 then [ Printf.sprintf "ficheros con lotes fallidos: %d" e.fallidos ] else [])
