(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

let version = 1

let a_json (ev : Cristal.evento) =
  let s x = `String x in
  let campos =
    match ev with
    | Por_cristal { etapa; entrada; salida } ->
        [ ("etapa", s etapa); ("evento", s "cristal"); ("entrada", s entrada);
          ("salida", s salida) ]
    | Por_liquido { etapa; entrada; salida } ->
        [ ("etapa", s etapa); ("evento", s "liquido"); ("entrada", s entrada);
          ("salida", s salida) ]
    | Defecto { etapa; entrada; motivo; liquido } ->
        [ ("etapa", s etapa); ("evento", s "defecto"); ("entrada", s entrada);
          ("motivo", s motivo);
          ("liquido", Option.fold ~none:`Null ~some:s liquido) ]
    | Comparado { etapa; entrada; liquido; cristal } ->
        [ ("etapa", s etapa); ("evento", s "comparado"); ("entrada", s entrada);
          ("liquido", s liquido);
          (match cristal with
          | Ok c -> ("cristal", s c)
          | Error m -> ("motivo", s m)) ]
  in
  Yojson.Safe.to_string (`Assoc (("v", `Int version) :: campos))

let de_json linea : (Cristal.evento, string) result =
  let ( let* ) = Result.bind in
  let* j =
    try Ok (Yojson.Safe.from_string linea)
    with Yojson.Json_error e -> Error ("JSON inválido: " ^ e)
  in
  let campo k =
    match j with `Assoc l -> List.assoc_opt k l | _ -> None
  in
  let texto k =
    match campo k with
    | Some (`String x) -> Ok x
    | _ -> Error (Printf.sprintf "falta el campo de texto %S" k)
  in
  let* () =
    match campo "v" with
    | Some (`Int v) when v = version -> Ok ()
    | Some (`Int v) -> Error (Printf.sprintf "versión %d desconocida" v)
    | _ -> Error "falta el campo \"v\""
  in
  let* etapa = texto "etapa" in
  let* entrada = texto "entrada" in
  let* evento = texto "evento" in
  match evento with
  | "cristal" ->
      let* salida = texto "salida" in
      Ok (Cristal.Por_cristal { etapa; entrada; salida })
  | "liquido" ->
      let* salida = texto "salida" in
      Ok (Cristal.Por_liquido { etapa; entrada; salida })
  | "defecto" ->
      let* motivo = texto "motivo" in
      let* liquido =
        match campo "liquido" with
        | None | Some `Null -> Ok None
        | Some (`String x) -> Ok (Some x)
        | Some _ -> Error "\"liquido\" debe ser texto o null"
      in
      Ok (Cristal.Defecto { etapa; entrada; motivo; liquido })
  | "comparado" ->
      let* liquido = texto "liquido" in
      let* cristal =
        match (campo "cristal", campo "motivo") with
        | Some (`String c), _ -> Ok (Ok c)
        | _, Some (`String m) -> Ok (Error m)
        | _ -> Error "\"comparado\" necesita \"cristal\" o \"motivo\""
      in
      Ok (Cristal.Comparado { etapa; entrada; liquido; cristal })
  | otro -> Error (Printf.sprintf "evento %S desconocido" otro)

let escribir oc ev =
  output_string oc (a_json ev);
  output_char oc '\n';
  flush oc

let leer fichero =
  In_channel.with_open_text fichero In_channel.input_lines
  |> List.mapi (fun i l -> (i + 1, l))
  |> List.filter (fun (_, l) -> String.trim l <> "")
  |> List.fold_left
       (fun acc (n, l) ->
         Result.bind acc (fun evs ->
             match de_json l with
             | Ok ev -> Ok (ev :: evs)
             | Error e -> Error (Printf.sprintf "%s:%d: %s" fichero n e)))
       (Ok [])
  |> Result.map List.rev
