(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Agencia

type efectos = {
  encargar : Agente.t -> ?modelo:Modelo.t -> string -> Encargo.t;
  juzgar : Encargo.t -> veredicto -> string -> unit;
  candidatos : Atomo.nuevo -> (Atomo.t list, string) result;
  escrito : sesion:string -> hasta:int -> (bool, string) result;
  escribir : hasta:int -> Atomo.t list -> (unit, string) result;
  guardar_cursor : sesion:string -> Lote.cursor -> (unit, string) result;
  avisar : string -> unit;
}

type agentes = { atomos : Agente.t; dedup : Agente.t }

let max_fallos = 3

type informe = {
  sesion : string;
  lote : Lote.t;
  encargos : Encargo.t list;
  escenas : string list;
  extraidos : Atomo.nuevo list;
  descartados : (string * string) list;
  decisiones : (Dedup.caso * Dedup.decision) list;
  filas : Atomo.t list;
}

type paso = Destilado of informe | Recuperado | Ilegible of { fallos : int; saltado : bool }

let ( let* ) = Result.bind

(* El siguiente más capaz que el que respondió, si lo hay. *)
let siguiente_modelo (a : Agente.t) (e : Encargo.t) =
  let rec tras = function
    | m :: (s :: _ as r) -> if Modelo.to_string m = e.modelo then Some s else tras r
    | _ -> None
  in
  tras a.escalera

let clave sesion (l : Lote.t) = Printf.sprintf "%s/%d" sesion l.hasta

let extraer ef ags ~sesion ~escena_previa (l : Lote.t) =
  let entrada = Extraccion.entrada ~escena_previa ~fondo:l.fondo ~nuevos:l.nuevos in
  let intento ?modelo () =
    let e = ef.encargar ags.atomos ?modelo entrada in
    match e.salida with
    | Error err -> (e, Error (`Sin_respuesta err))
    | Ok texto -> (
        match Extraccion.leer ~clave:(clave sesion l) ~nuevos:l.nuevos texto with
        | Ok r ->
            ef.juzgar e Bien (Printf.sprintf "legible: %d átomos" (List.length r.atomos));
            (e, Ok r)
        | Error err ->
            ef.juzgar e Mal ("salida ilegible: " ^ err);
            (e, Error (`Basura err)))
  in
  let sin_respuesta err = Error ("memoria-atomos sin respuesta: " ^ err) in
  match intento () with
  | e, Ok r -> ([ e ], Ok (Some r))
  | e, Error (`Sin_respuesta err) -> ([ e ], sin_respuesta err)
  | e, Error (`Basura err) -> (
      match siguiente_modelo ags.atomos e with
      | None -> ([ e ], Ok None)
      | Some modelo -> (
          match intento ~modelo () with
          | e2, Ok r -> ([ e; e2 ], Ok (Some r))
          | e2, Error (`Sin_respuesta err) -> ([ e; e2 ], sin_respuesta err)
          | e2, Error (`Basura _) -> ([ e; e2 ], Ok None)))

let juzgar ef ags casos =
  if not (Dedup.hace_falta_juez casos) then ([], Dedup.guardar_todo casos)
  else
    let e = ef.encargar ags.dedup (Dedup.entrada casos) in
    match e.salida with
    | Error err ->
        ef.avisar ("memoria-dedup sin respuesta; se guarda todo: " ^ err);
        ([ e ], Dedup.guardar_todo casos)
    | Ok texto -> (
        match Dedup.leer casos texto with
        | Ok d ->
            ef.juzgar e Bien "legible";
            ([ e ], d)
        | Error err ->
            ef.juzgar e Mal ("salida ilegible: " ^ err);
            ef.avisar ("memoria-dedup: salida ilegible; se guarda todo: " ^ err);
            ([ e ], Dedup.guardar_todo casos))

let rec todos = function [] -> Ok [] | Ok x :: r -> Result.map (List.cons x) (todos r) | Error e :: _ -> Error e

let lote ef ags ~sesion ~cursor (l : Lote.t) =
  let escena_previa = Option.bind cursor (fun (c : Lote.cursor) -> c.escena) in
  let* ya = ef.escrito ~sesion ~hasta:l.hasta in
  if ya then
    let* () = ef.guardar_cursor ~sesion { hasta = l.hasta; escena = escena_previa; fallos = 0 } in
    Ok Recuperado
  else
    let encargos_ext, r = extraer ef ags ~sesion ~escena_previa l in
    let* r = r in
    match r with
    | None ->
        let fallos = 1 + match cursor with Some c -> c.fallos | None -> 0 in
        if fallos >= max_fallos then (
          ef.avisar
            (Printf.sprintf "memoria-atomos: lote de %s hasta %s ilegible %d pasadas seguidas; se salta" sesion
               (Atomo.hora l.hasta) fallos);
          let* () = ef.guardar_cursor ~sesion { hasta = l.hasta; escena = escena_previa; fallos = 0 } in
          Ok (Ilegible { fallos; saltado = true }))
        else
          (* El cursor se queda donde estaba (o justo antes del lote, si no
             había), con el fallo contado. *)
          let hasta =
            match cursor with Some c -> c.hasta | None -> (List.hd l.nuevos).ts - 1
          in
          let* () = ef.guardar_cursor ~sesion { hasta; escena = escena_previa; fallos } in
          Ok (Ilegible { fallos; saltado = false })
    | Some r ->
        let propios = List.map (fun (n : Atomo.nuevo) -> n.id) r.atomos in
        let* candidatos =
          todos
            (List.map
               (fun n ->
                 Result.map (List.filter (fun (a : Atomo.t) -> not (List.mem a.id propios))) (ef.candidatos n))
               r.atomos)
        in
        let casos = Dedup.casos (List.combine r.atomos candidatos) in
        let encargos_juez, decisiones = if casos = [] then ([], []) else juzgar ef ags casos in
        let filas = Dedup.plan casos decisiones in
        let* () = ef.escribir ~hasta:l.hasta filas in
        let escena = match r.ultima_escena with Some e -> Some e | None -> escena_previa in
        let* () = ef.guardar_cursor ~sesion { hasta = l.hasta; escena; fallos = 0 } in
        Ok
          (Destilado
             { sesion;
               lote = l;
               encargos = encargos_ext @ encargos_juez;
               escenas = r.escenas;
               extraidos = r.atomos;
               descartados = r.descartados;
               decisiones =
                 List.map
                   (fun (c : Dedup.caso) -> (c, List.find (fun (d : Dedup.decision) -> d.caso = c.etiqueta) decisiones))
                   casos;
               filas })

type resumen = { informes : informe list; recuperados : int; ilegibles : int; saltados : int; error : string option }

let avanzo r = r.informes <> [] || r.recuperados > 0 || r.saltados > 0

let sesion ef ags ?limite ~sesion ~cursor mensajes =
  let vacio = { informes = []; recuperados = 0; ilegibles = 0; saltados = 0; error = None } in
  let fin r = { r with informes = List.rev r.informes } in
  let rec seguir r n (cursor : Lote.cursor option) =
    if match limite with Some l -> n >= l | None -> false then fin r
    else
      match Lote.siguiente ~cursor:(Option.map (fun (c : Lote.cursor) -> c.hasta) cursor) mensajes with
      | Lote.Nada -> fin r
      | Lote.Avanzar hasta -> (
          let c = { Lote.hasta; escena = Option.bind cursor (fun c -> c.escena); fallos = 0 } in
          match ef.guardar_cursor ~sesion c with Ok () -> fin r | Error e -> fin { r with error = Some e })
      | Lote.Lote l -> (
          let escena = Option.bind cursor (fun (c : Lote.cursor) -> c.escena) in
          let siguiente_cursor e = Some { Lote.hasta = l.hasta; escena = e; fallos = 0 } in
          match lote ef ags ~sesion ~cursor l with
          | Error e -> fin { r with error = Some e }
          | Ok (Destilado i) ->
              let e = match List.rev i.escenas with e :: _ -> Some e | [] -> escena in
              seguir { r with informes = i :: r.informes } (n + 1) (siguiente_cursor e)
          | Ok Recuperado -> seguir { r with recuperados = r.recuperados + 1 } (n + 1) (siguiente_cursor escena)
          | Ok (Ilegible { saltado = true; _ }) -> seguir { r with saltados = r.saltados + 1 } (n + 1) (siguiente_cursor escena)
          | Ok (Ilegible { saltado = false; _ }) -> fin { r with ilegibles = r.ilegibles + 1 })
  in
  seguir vacio 0 cursor
