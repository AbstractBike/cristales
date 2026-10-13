(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let max_texto = 3000

(* Retrocede hasta el principio de un carácter UTF-8 (los bytes de
   continuación son 10xxxxxx). *)
let rec frontera s i = if i > 0 && i < String.length s && Char.code s.[i] land 0xC0 = 0x80 then frontera s (i - 1) else i

let recortar n s =
  if String.length s <= n then s
  else
    let mitad = n / 2 in
    let a = frontera s mitad and b = frontera s (String.length s - mitad) in
    String.sub s 0 a ^ " […] " ^ String.sub s b (String.length s - b)

let rol (m : Atomo.mensaje) =
  match Atomo.autor m with
  | Atomo.Usuario -> "usuario"
  | Atomo.Asistente -> "asistente"
  | Atomo.Agente_padre -> "agente padre"
  | Atomo.Tarea_programada -> "tarea programada"

let linea etiqueta (m : Atomo.mensaje) =
  Printf.sprintf "[%s] [%s] [%s UTC]\n%s" etiqueta (rol m) (Atomo.hora m.ts) (recortar max_texto (String.trim m.texto))

let etiquetar prefijo l = List.mapi (fun i m -> (Printf.sprintf "%s%d" prefijo (i + 1), m)) l

let entrada ~escena_previa ~fondo ~nuevos =
  let bloque prefijo l =
    match l with
    | [] -> "(ninguno)"
    | l -> String.concat "\n\n" (List.map (fun (e, m) -> linea e m) (etiquetar prefijo l))
  in
  Printf.sprintf
    "【escena anterior】 %s\n\n\
     【fondo】 (solo contexto: prohibido extraer de aquí)\n\n\
     %s\n\n\
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n\
     【nuevos】 (extrae solo de aquí; fechas absolutas a partir de la hora de cada mensaje)\n\n\
     %s\n"
    (Option.value ~default:"ninguna" escena_previa)
    (bloque "f" fondo) (bloque "m" nuevos)

type resultado = {
  escenas : string list;
  ultima_escena : string option;
  atomos : Atomo.nuevo list;
  descartados : (string * string) list;
}

let escenas_de j =
  match j with
  | `List l -> Some l (* el formato de Tencent: un array de escenas *)
  | `Assoc _ -> ( match Yojson.Safe.Util.member "escenas" j with `List l -> Some l | _ -> None)
  | _ -> None

let leer ~clave ~nuevos respuesta =
  match Json_llm.extraer respuesta with
  | Error e -> Error e
  | Ok j -> (
      match escenas_de j with
      | None -> Error "sin «escenas»"
      | Some escenas ->
          let por_etiqueta = etiquetar "m" nuevos in
          let descartados = ref [] and indice = ref 0 in
          let descartar c motivo = descartados := (c, motivo) :: !descartados in
          let atomo escena a =
            match Json_llm.texto a "contenido" with
            | None -> descartar "" "sin contenido"; None
            | Some contenido -> (
                let mensajes = List.filter_map (fun e -> List.assoc_opt e por_etiqueta) (Json_llm.textos a "origen") in
                let mensajes = List.sort_uniq (fun (a : Atomo.mensaje) b -> compare (a.ts, a.uuid) (b.ts, b.uuid)) mensajes in
                match (Option.bind (Json_llm.texto a "tipo") Atomo.tipo_de_texto, Json_llm.entero a "prioridad", mensajes) with
                | None, _, _ -> descartar contenido "tipo desconocido"; None
                | _, _, [] -> descartar contenido "sin origen entre los nuevos"; None
                | Some tipo, prioridad, (primero :: _ as mensajes) ->
                    let prioridad = Atomo.prioridad_valida (Option.value ~default:0 prioridad) in
                    if not (Atomo.conservar tipo prioridad) then (
                      descartar contenido (Printf.sprintf "prioridad %d bajo el umbral" prioridad);
                      None)
                    else if
                      (tipo = Atomo.Persona || tipo = Atomo.Regla)
                      && not (List.exists (fun m -> Atomo.autor m = Atomo.Usuario) mensajes)
                    then (
                      descartar contenido "persona o regla sin un mensaje del usuario";
                      None)
                    else (
                      incr indice;
                      Some
                        { Atomo.id = Atomo.id_de ~clave !indice;
                          contenido;
                          tipo;
                          prioridad;
                          escena;
                          proyecto = primero.proyecto;
                          origen = List.map Atomo.origen mensajes;
                          fechas = List.sort_uniq String.compare (List.map (fun (m : Atomo.mensaje) -> Atomo.fecha m.ts) mensajes) }))
          in
          let leidas =
            List.filter_map
              (fun e ->
                match Json_llm.texto e "escena" with
                | None -> None
                | Some escena ->
                    let atomos = match Yojson.Safe.Util.member "atomos" e with `List l -> l | _ -> [] | exception _ -> [] in
                    Some (escena, List.filter_map (atomo escena) atomos))
              escenas
          in
          let nombres = List.map fst leidas in
          Ok
            { escenas = nombres;
              ultima_escena = List.fold_left (fun _ e -> Some e) None nombres;
              atomos = List.concat_map snd leidas;
              descartados = List.rev !descartados })
