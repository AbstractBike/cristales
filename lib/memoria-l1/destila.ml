(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Agencia

type efectos = {
  encargar : Agente.t -> ?modelo:Modelo.t -> string -> Encargo.t;
  juzgar_mal : Encargo.t -> string -> unit;
  candidatos : Atomo.nuevo -> Atomo.t list;
  escribir : Atomo.t list -> (unit, string) result;
  guardar_cursor : sesion:string -> hasta:int -> escena:string option -> (unit, string) result;
  avisar : string -> unit;
}

type agentes = { atomos : Agente.t; dedup : Agente.t }

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

let ( let* ) = Result.bind

(* El siguiente más capaz que el que respondió, si lo hay. *)
let siguiente_modelo (a : Agente.t) (e : Encargo.t) =
  let rec tras = function
    | m :: (s :: _ as r) -> if Modelo.to_string m = e.modelo then Some s else tras r
    | _ -> None
  in
  tras a.escalera

let extraer ef ags ~escena_previa (l : Lote.t) =
  let entrada = Extraccion.entrada ~escena_previa ~fondo:l.fondo ~nuevos:l.nuevos in
  let intento ?modelo () =
    let e = ef.encargar ags.atomos ?modelo entrada in
    match e.salida with
    | Error err -> (e, Error (`Sin_respuesta err))
    | Ok texto -> (
        match Extraccion.leer ~nuevos:l.nuevos texto with
        | Ok r -> (e, Ok r)
        | Error err ->
            ef.juzgar_mal e ("salida ilegible: " ^ err);
            (e, Error (`Basura err)))
  in
  match intento () with
  | e, Ok r -> ([ e ], Ok (Some r))
  | e, Error (`Sin_respuesta err) -> ([ e ], Error ("memoria-atomos sin respuesta: " ^ err))
  | e, Error (`Basura err) -> (
      match siguiente_modelo ags.atomos e with
      | None ->
          ef.avisar ("memoria-atomos: salida ilegible y sin modelo más capaz; se salta el lote (" ^ err ^ ")");
          ([ e ], Ok None)
      | Some modelo -> (
          match intento ~modelo () with
          | e2, Ok r -> ([ e; e2 ], Ok (Some r))
          | e2, Error (`Sin_respuesta err) -> ([ e; e2 ], Error ("memoria-atomos sin respuesta: " ^ err))
          | e2, Error (`Basura err) ->
              ef.avisar ("memoria-atomos: salida ilegible dos veces; se salta el lote (" ^ err ^ ")");
              ([ e; e2 ], Ok None)))

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
        | Ok d -> ([ e ], d)
        | Error err ->
            ef.juzgar_mal e ("salida ilegible: " ^ err);
            ef.avisar ("memoria-dedup: salida ilegible; se guarda todo: " ^ err);
            ([ e ], Dedup.guardar_todo casos))

let lote ef ags ~sesion ~escena_previa (l : Lote.t) =
  let encargos_ext, r = extraer ef ags ~escena_previa l in
  let* r = r in
  let escenas, extraidos, descartados, ultima =
    match r with
    | None -> ([], [], [], escena_previa)
    | Some r ->
        (r.escenas, r.atomos, r.descartados, match r.ultima_escena with Some e -> Some e | None -> escena_previa)
  in
  let casos = Dedup.casos (List.map (fun n -> (n, ef.candidatos n)) extraidos) in
  let encargos_juez, decisiones = if casos = [] then ([], []) else juzgar ef ags casos in
  let filas = Dedup.plan casos decisiones in
  let* () = ef.escribir filas in
  let* () = ef.guardar_cursor ~sesion ~hasta:l.hasta ~escena:ultima in
  Ok
    { sesion;
      lote = l;
      encargos = encargos_ext @ encargos_juez;
      escenas;
      extraidos;
      descartados;
      decisiones = List.combine casos (List.map (fun (c : Dedup.caso) -> List.find (fun (d : Dedup.decision) -> d.caso = c.etiqueta) decisiones) casos);
      filas }

let sesion ef ags ?limite ~sesion ~cursor mensajes =
  let rec seguir hechos n cursor escena =
    if match limite with Some l -> n >= l | None -> false then (List.rev hechos, None)
    else
      match Lote.siguiente ~cursor mensajes with
      | Lote.Nada -> (List.rev hechos, None)
      | Lote.Avanzar hasta -> (
          match ef.guardar_cursor ~sesion ~hasta ~escena with
          | Ok () -> (List.rev hechos, None)
          | Error e -> (List.rev hechos, Some e))
      | Lote.Lote l -> (
          match lote ef ags ~sesion ~escena_previa:escena l with
          | Error e -> (List.rev hechos, Some e)
          | Ok i ->
              let escena = match List.rev i.escenas with e :: _ -> Some e | [] -> escena in
              seguir (i :: hechos) (n + 1) (Some l.hasta) escena)
  in
  match cursor with
  | Some (c, escena) -> seguir [] 0 (Some c) escena
  | None -> seguir [] 0 None None
