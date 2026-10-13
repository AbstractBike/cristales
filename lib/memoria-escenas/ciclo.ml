(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type efectos = {
  encargar : Agencia.Agente.t -> string -> Agencia.Encargo.t;
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
  encargos : encargo list;
}

let lotes n atomos =
  let ordenados = List.stable_sort (fun (a : Atomo.t) (b : Atomo.t) -> compare (a.escena, a.ts) (b.escena, b.ts)) atomos in
  let rec ir acc actual k = function
    | [] -> List.rev (if actual = [] then acc else List.rev actual :: acc)
    | a :: r -> if k = n then ir (List.rev actual :: acc) [ a ] 1 r else ir acc (a :: actual) (k + 1) r
  in
  ir [] [] 0 ordenados

let union a b = a @ List.filter (fun x -> not (List.mem x a)) b

let contar (e : Agencia.Encargo.t) resumen =
  { agente = (e.agente :> string); id = e.id; modelo = e.modelo; ms = e.ms;
    tokens = e.tokens_entrada + e.tokens_salida; resumen }

let consolidar ef ~escenas_agente ~persona_agente ?(lote = 30) ~estado ~persona escenas atomos =
  let encargos = ref [] in
  let anotar e r = encargos := contar e r :: !encargos in
  (* Pide y entiende; un JSON que no se entiende se juzga mal ya. *)
  let pedir entrada =
    let e = ef.encargar escenas_agente entrada in
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
      @ List.map (fun (o, m) -> Printf.sprintf "RECHAZADA %s (%s)" (Operacion.describir o) m) r.rechazos)
  in
  let un_lote (escenas, escritas, borradas, senal) atomos =
    let ahora = ef.ahora () in
    let abiertas = Consolidacion.abiertas escenas atomos in
    let entrada = Consolidacion.entrada ~ahora ~escenas ~abiertas atomos in
    let aplicar ops = Consolidacion.aplicar ~ahora ~abiertas ~nuevos:atomos escenas ops in
    let final, senal' =
      match pedir entrada with
      | _, Error _ -> (None, None)
      | e, Ok (texto, s) -> (
          let r = aplicar s.operaciones in
          anotar e (resumen r);
          if r.rechazos = [] then (Some r, s.persona)
          else
            let motivos = List.map (fun (o, m) -> Operacion.describir o ^ ": " ^ m) r.rechazos in
            ef.log ("rechazos, se repite: " ^ String.concat " | " motivos);
            match pedir (Consolidacion.reintento ~entrada ~salida:texto motivos) with
            | e2, Ok (_, s2) ->
                let r2 = aplicar s2.operaciones in
                anotar e2 (resumen r2);
                (Some r2, match s2.persona with Some _ as p -> p | None -> s.persona)
            | _, Error _ -> (Some r, s.persona))
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
  let cursor = List.fold_left (fun m (a : Atomo.t) -> max m a.ts) estado.Estado.cursor atomos in
  let estado = { estado with cursor; atomos_desde_persona = estado.atomos_desde_persona + n } in
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
        let entrada = Persona.entrada ~actual:persona ~motivo ~cambiadas ~resto in
        let pedir_persona entrada =
          let e = ef.encargar persona_agente entrada in
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
                  `Mal (texto, err))
        in
        let resultado =
          match pedir_persona entrada with
          | `Bien p -> Some p
          | `Fallo -> None
          | `Mal (texto, err) -> (
              match
                pedir_persona
                  (Printf.sprintf "%s\n## Tu respuesta anterior\n\n%s\n\n## Rechazo\n\n%s. Devuelve la persona entera otra vez, por debajo de 1700 caracteres: quita secciones enteras antes que dejarla larga.\n" entrada texto err)
              with
              | `Bien p -> Some p
              | `Fallo | `Mal _ -> None)
        in
        match resultado with
        | Some p -> (Some p, { estado with persona = Some (ef.ahora ()); atomos_desde_persona = 0 })
        | None -> (None, estado))
  in
  { escenas = escenas'; escritas; borradas; persona = persona'; estado; consolidados = n;
    encargos = List.rev !encargos }
