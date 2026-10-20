(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

(* Lee el registro de una pipeline (doc/registro.md) y responde lo que el
   protocolo de doc/pipelines.md necesita saber de él:

     cristales grado    REGISTRO           grado y acuerdo por etapa
     cristales semillas REGISTRO ETAPA     candidatos a SEMILLA.md *)

let uso () =
  prerr_endline
    "uso: cristales grado REGISTRO\n\
    \     cristales semillas REGISTRO ETAPA";
  exit 2

let porcentaje = function
  | None -> "—"
  | Some f -> Printf.sprintf "%.1f%%" (100. *. f)

let grado eventos =
  let m = Cristal.Medidor.crear () in
  List.iter (Cristal.Medidor.observar m) eventos;
  let entradas n =
    List.length (List.filter (fun ev -> Cristal.etapa_de ev = n) eventos)
  in
  print_endline "| Etapa | Entradas | Grado | Acuerdo en sombra |";
  print_endline "|---|---:|---:|---:|";
  List.iter
    (fun n ->
      Printf.printf "| %s | %d | %s | %s |\n" n (entradas n)
        (porcentaje (Cristal.Medidor.grado m n))
        (porcentaje (Cristal.Medidor.acuerdo m n)))
    (Cristal.Medidor.etapas m);
  Printf.printf "| **pipeline** | %d | %s | |\n" (List.length eventos)
    (porcentaje (Cristal.Medidor.grado_total m))

(* Una semilla candidata es una entrada que el cristal no resolvió bien,
   con lo que respondió el LLM como salida propuesta. Se revisa a mano antes
   de entrar en SEMILLA.md: a veces el que se equivocaba era el líquido. *)
type semilla = { entrada : string; propuesta : string option; nota : string }

let semilla_de etapa (ev : Cristal.evento) =
  if Cristal.etapa_de ev <> etapa then None
  else
    match ev with
    | Defecto { entrada; motivo; liquido; _ } ->
        Some { entrada; propuesta = liquido; nota = "defecto: " ^ motivo }
    | Comparado { entrada; liquido; cristal = Error m; _ } ->
        Some { entrada; propuesta = Some liquido; nota = "defecto: " ^ m }
    | Comparado { entrada; liquido; cristal = Ok c; _ } when c <> liquido ->
        Some { entrada; propuesta = Some liquido; nota = "el cristal dio " ^ c }
    | Por_cristal _ | Por_liquido _ | Comparado _ -> None

(* Celda de tabla markdown en una línea, como las de SEMILLA.md. *)
let celda s =
  String.concat "\\|" (String.split_on_char '|' s)
  |> String.map (function '\n' | '\r' -> ' ' | c -> c)

let semillas eventos etapa =
  let vistas = Hashtbl.create 64 in
  let nuevas =
    List.filter_map
      (fun ev ->
        match semilla_de etapa ev with
        | Some s when not (Hashtbl.mem vistas s.entrada) ->
            Hashtbl.add vistas s.entrada ();
            Some s
        | _ -> None)
      eventos
  in
  print_endline "| Entrada | Salida (propuesta del líquido) | Nota |";
  print_endline "|---|---|---|";
  List.iter
    (fun s ->
      Printf.printf "| `%s` | %s | %s |\n" (celda s.entrada)
        (Option.fold ~none:"*por decidir*" ~some:celda s.propuesta)
        (celda s.nota))
    nuevas;
  Printf.eprintf "%d semillas candidatas en %s\n" (List.length nuevas) etapa

let () =
  let leer f =
    match Registro.leer f with
    | Ok evs -> evs
    | Error e ->
        prerr_endline e;
        exit 1
  in
  match Array.to_list Sys.argv |> List.tl with
  | [ "grado"; f ] -> grado (leer f)
  | [ "semillas"; f; etapa ] -> semillas (leer f) etapa
  | _ -> uso ()
