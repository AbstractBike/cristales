(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type efectos = {
  encargar : ?modelo:Agencia.Modelo.t -> Agencia.Agente.t -> string -> Agencia.Encargo.t;
  juzgar_mal : Agencia.Encargo.t -> string -> unit;
  ahora : unit -> string;
  log : string -> unit;
}

type encargo = { agente : string; id : string; modelo : string; ms : int; tokens : int; resumen : string }

type salida = {
  escenas : Escena.t list;
  escritas : string list;
  borradas : string list;
  persona : string option;
  estado : Estado.t;
  consolidados : int;
  fallidos : int;
  encargos : encargo list;
}

let lotes n atomos =
  let ordenados = List.stable_sort (fun (a : Atomo.t) (b : Atomo.t) -> compare (a.escena, a.escrito) (b.escena, b.escrito)) atomos in
  let rec ir acc actual k = function
    | [] -> List.rev (if actual = [] then acc else List.rev actual :: acc)
    | a :: r -> if k = n then ir (List.rev actual :: acc) [ a ] 1 r else ir acc (a :: actual) (k + 1) r
  in
  ir [] [] 0 ordenados

let union a b = a @ List.filter (fun x -> not (List.mem x a)) b

(* El modelo de un encargo, para repetirle a él; y el más capaz del agente. *)
let mismo (e : Agencia.Encargo.t) = Result.to_option (Agencia.Modelo.de_texto e.modelo)

let mas_capaz (a : Agencia.Agente.t) = List.nth a.escalera (List.length a.escalera - 1)

let contar (e : Agencia.Encargo.t) resumen =
  { agente = (e.agente :> string); id = e.id; modelo = e.modelo; ms = e.ms;
    tokens = e.tokens_entrada + e.tokens_salida; resumen }

(* «2026-10-13T20:37:06Z» en ms (calendario civil, sin zona: siempre UTC). *)
let ms_de_iso s =
  try
    Scanf.sscanf s "%d-%d-%dT%d:%d:%d" (fun y m d hh mm ss ->
        let y = if m <= 2 then y - 1 else y in
        let era = (if y >= 0 then y else y - 399) / 400 in
        let yoe = y - (era * 400) in
        let mp = (m + 9) mod 12 in
        let doy = ((153 * mp) + 2) / 5 + d - 1 in
        let doe = (yoe * 365) + (yoe / 4) - (yoe / 100) + doy in
        let dias = (era * 146097) + doe - 719468 in
        Some ((((dias * 24 + hh) * 60 + mm) * 60 + ss) * 1000))
  with _ -> None

let ya_aplicados escenas atomos =
  List.filter
    (fun (a : Atomo.t) ->
      not
        (List.exists
           (fun (e : Escena.t) ->
             List.mem a.id e.atomos
             && match ms_de_iso e.actualizada with Some t -> t >= a.escrito | None -> false)
           escenas))
    atomos

let consolidar ef ~escenas_agente ~persona_agente ?(reglas = "") ?(anteriores = []) ?(lote = 30) ~estado ~persona
    escenas atomos =
  (* Lo que ya integró una pasada anterior (que no movió el cursor porque
     algún otro lote falló) no se vuelve a aplicar. *)
  let todos = atomos in
  let atomos = ya_aplicados escenas atomos in
  if List.length atomos < List.length todos then
    ef.log (Printf.sprintf "%d átomos ya estaban en sus escenas: no se repiten" (List.length todos - List.length atomos));
  let encargos = ref [] in
  let anotar e r = encargos := contar e r :: !encargos in
  (* Pide y entiende; un JSON que no se entiende se juzga mal ya. *)
  let fallidos = ref 0 in
  let pedir ?modelo entrada =
    let e = ef.encargar ?modelo escenas_agente entrada in
    match e.salida with
    | Error err ->
        anotar e ("error: " ^ err);
        (e, Error err)
    | Ok texto -> (
        match Operacion.de_texto texto with
        | Ok s -> (e, Ok (texto, s))
        | Error err ->
            ef.juzgar_mal e ("salida no válida: " ^ err);
            anotar e ("no se entiende: " ^ err);
            (e, Error err))
  in
  let resumen (r : Consolidacion.resultado) =
    String.concat "; "
      (List.map Operacion.describir r.aplicadas
      @ List.map (fun s -> "RECORTADA " ^ s) r.recortadas
      @ List.map (fun (o, m) -> Printf.sprintf "RECHAZADA %s (%s)" (Operacion.describir o) m) r.rechazos)
  in
  let un_lote (escenas, escritas, borradas, senal) atomos =
    let ahora = ef.ahora () in
    let abiertas = Consolidacion.abiertas escenas atomos in
    let entrada = Consolidacion.entrada ~reglas ~anteriores ~ahora ~escenas ~abiertas atomos in
    let aplicar ops = Consolidacion.aplicar ~ahora ~abiertas ~nuevos:atomos escenas ops in
    let final, senal' =
      (* Si la salida no sirve (error, o no es JSON), una vez más con el
         modelo por defecto del agente; si tampoco, el lote queda sin hacer y
         el cursor no avanza. *)
      let primera =
        match pedir entrada with
        | _, Ok _ as r -> r
        | _, Error _ -> pedir ~modelo:escenas_agente.defecto entrada
      in
      match primera with
      | _, Error _ ->
          incr fallidos;
          ef.log (Printf.sprintf "lote de %d átomos SIN HACER: el cursor no avanza" (List.length atomos));
          (None, None)
      | e, Ok (texto, s) ->
          let r = aplicar s.operaciones in
          anotar e (resumen r);
          (* Hasta dos correcciones: con el mismo modelo (que vea sus
             rechazos) y, si sigue, con el más capaz de la escalera. *)
          let rec corregir intentos (e : Agencia.Encargo.t) texto (s : Operacion.salida) r =
            match intentos with
            | [] -> (Some r, s.persona)
            | _ when r.Consolidacion.rechazos = [] -> (Some r, s.persona)
            | modelo :: resto -> (
                let motivos = List.map (fun (o, m) -> Operacion.describir o ^ ": " ^ m) r.rechazos in
                ef.log ("rechazos, se repite: " ^ String.concat " | " motivos);
                let modelo = modelo e in
                match pedir ?modelo (Consolidacion.reintento ~entrada ~salida:texto motivos) with
                | e2, Ok (texto2, s2) ->
                    let r2 = aplicar s2.operaciones in
                    anotar e2 (resumen r2);
                    let s2 = { s2 with persona = (match s2.persona with Some _ as p -> p | None -> s.persona) } in
                    corregir resto e2 texto2 s2 r2
                | _, Error _ -> (Some r, s.persona))
          in
          corregir [ mismo; (fun _ -> Some (mas_capaz escenas_agente)) ] e texto s r
    in
    match final with
    | None -> (escenas, escritas, borradas, senal)
    | Some r ->
        ef.log (Printf.sprintf "lote de %d átomos: %s" (List.length atomos) (resumen r));
        let escritas = union (List.filter (fun s -> not (List.mem s r.borradas)) escritas) r.escritas
        and borradas = union (List.filter (fun s -> not (List.mem s r.escritas)) borradas) r.borradas in
        (r.escenas, escritas, borradas, match senal' with Some _ -> senal' | None -> senal)
  in
  let escenas', escritas, borradas, senal =
    List.fold_left un_lote (escenas, [], [], None) (lotes lote atomos)
  in
  let n = List.length atomos in
  let estado =
    if !fallidos > 0 then estado
    else
      let cursor = List.fold_left (fun m (a : Atomo.t) -> max m a.escrito) estado.Estado.cursor todos in
      { estado with cursor; atomos_desde_persona = estado.atomos_desde_persona + n }
  in
  let motivo =
    Persona.disparo ~ultima:estado.persona ~escenas:escenas' ~senal ~atomos_desde:estado.atomos_desde_persona
  in
  let persona', estado =
    match motivo with
    | None -> (None, estado)
    | Some motivo -> (
        ef.log ("persona: " ^ motivo);
        let cambiadas = Persona.cambiadas ~ultima:estado.persona escenas' in
        let resto = List.filter (fun e -> not (List.memq e cambiadas)) escenas' in
        let entrada = Persona.entrada ~reglas ~actual:persona ~motivo ~cambiadas ~resto in
        let pedir_persona ?modelo entrada =
          let e = ef.encargar ?modelo persona_agente entrada in
          match e.salida with
          | Error err ->
              anotar e ("error: " ^ err);
              `Fallo
          | Ok texto -> (
              match Persona.validar texto with
              | Ok p ->
                  anotar e (Printf.sprintf "persona de %d caracteres" (Escena.longitud p));
                  `Bien p
              | Error err ->
                  ef.juzgar_mal e err;
                  anotar e ("rechazada: " ^ err);
                  `Mal (e, texto, err))
        in
        let corregir modelo texto err =
          pedir_persona ?modelo
            (Printf.sprintf
               "%s\n## Tu respuesta anterior\n\n%s\n\n## Rechazo\n\n%s. Devuelve la persona entera otra vez, por \
                debajo de 1700 caracteres: quita secciones enteras antes que dejarla larga.\n"
               entrada texto err)
        in
        let resultado =
          match pedir_persona entrada with
          | `Bien p -> Some p
          | `Fallo -> (
              match pedir_persona ~modelo:persona_agente.defecto entrada with `Bien p -> Some p | _ -> None)
          | `Mal (e, texto, err) -> (
              (* Como en las escenas: el mismo modelo y luego el más capaz. *)
              match corregir (mismo e) texto err with
              | `Bien p -> Some p
              | `Fallo -> None
              | `Mal (_, texto, err) -> (
                  match corregir (Some (mas_capaz persona_agente)) texto err with `Bien p -> Some p | _ -> None))
        in
        match resultado with
        | Some p -> (Some p, { estado with persona = Some (ef.ahora ()); atomos_desde_persona = 0 })
        | None -> (None, estado))
  in
  { escenas = escenas'; escritas; borradas; persona = persona'; estado; consolidados = n;
    encargos = List.rev !encargos; fallidos = !fallidos }
