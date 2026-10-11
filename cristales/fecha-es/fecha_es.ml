(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type fecha = { anyo : int; mes : int; dia : int }

let bisiesto a = (a mod 4 = 0 && a mod 100 <> 0) || a mod 400 = 0

let dias_del_mes a = function
  | 2 -> if bisiesto a then 29 else 28
  | 4 | 6 | 9 | 11 -> 30
  | _ -> 31

let valida { anyo; mes; dia } =
  mes >= 1 && mes <= 12 && dia >= 1 && dia <= dias_del_mes anyo mes

let iso { anyo; mes; dia } = Printf.sprintf "%04d-%02d-%02d" anyo mes dia

(* Días desde 1970-01-01 y vuelta (algoritmo civil de H. Hinnant). *)
let a_dias { anyo; mes; dia } =
  let y = if mes <= 2 then anyo - 1 else anyo in
  let era = (if y >= 0 then y else y - 399) / 400 in
  let yoe = y - (era * 400) in
  let mp = (mes + 9) mod 12 in
  let doy = ((153 * mp) + 2) / 5 + dia - 1 in
  let doe = (yoe * 365) + (yoe / 4) - (yoe / 100) + doy in
  (era * 146097) + doe - 719468

let de_dias n =
  let z = n + 719468 in
  let era = (if z >= 0 then z else z - 146096) / 146097 in
  let doe = z - (era * 146097) in
  let yoe = (doe - (doe / 1460) + (doe / 36524) - (doe / 146096)) / 365 in
  let doy = doe - ((365 * yoe) + (yoe / 4) - (yoe / 100)) in
  let mp = ((5 * doy) + 2) / 153 in
  let dia = doy - (((153 * mp) + 2) / 5) + 1 in
  let mes = if mp < 10 then mp + 3 else mp - 9 in
  let anyo = yoe + (era * 400) + if mes <= 2 then 1 else 0 in
  { anyo; mes; dia }

let relativas =
  [ ("hoy", 0); ("mañana", 1); ("pasado mañana", 2); ("ayer", -1); ("anteayer", -2) ]

let meses =
  [ "enero"; "febrero"; "marzo"; "abril"; "mayo"; "junio"; "julio"; "agosto";
    "septiembre"; "octubre"; "noviembre"; "diciembre" ]

let dias_semana =
  [ "lunes"; "martes"; "miércoles"; "miercoles"; "jueves"; "viernes"; "sábado";
    "sabado"; "domingo" ]

let num s =
  if s <> "" && String.for_all (fun c -> c >= '0' && c <= '9') s then
    int_of_string_opt s
  else None

let anyo_corto s =
  match (num s, String.length s) with
  | Some a, 2 -> Some (if a < 70 then 2000 + a else 1900 + a)
  | Some a, 4 -> Some a
  | _ -> None

let indice x l =
  let rec ir i = function
    | [] -> None
    | y :: _ when y = x -> Some i
    | _ :: r -> ir (i + 1) r
  in
  ir 1 l

let quitar_sufijo suf s =
  if String.ends_with ~suffix:suf s then
    String.sub s 0 (String.length s - String.length suf)
  else s

(* "3º", "3°", "1ro" → "3", "3", "1" *)
let ordinal s = s |> quitar_sufijo "º" |> quitar_sufijo "°" |> quitar_sufijo "ro"

let normalizar s =
  String.lowercase_ascii s
  |> String.map (fun c -> if c = ',' || c = '\t' then ' ' else c)
  |> String.split_on_char ' '
  |> List.filter (( <> ) "")

let numerica s =
  match String.split_on_char (if String.contains s '/' then '/' else '-') s with
  | [ a; m; d ] when String.length a = 4 -> (
      match (num a, num m, num d) with
      | Some anyo, Some mes, Some dia -> Some { anyo; mes; dia }
      | _ -> None)
  | [ d; m; a ] -> (
      match (num d, num m, anyo_corto a) with
      | Some dia, Some mes, Some anyo -> Some { anyo; mes; dia }
      | _ -> None)
  | _ -> None

let textual ~hoy palabras =
  let palabras =
    match palabras with
    | w :: r when List.mem w dias_semana -> r
    | p -> p
  in
  let palabras = match palabras with "el" :: r -> r | p -> p in
  let con_mes d m k =
    match (num (ordinal d), indice m meses) with
    | Some dia, Some mes -> k dia mes
    | _ -> None
  in
  match palabras with
  | [ d; "de"; m ] -> con_mes d m (fun dia mes -> Some { anyo = hoy.anyo; mes; dia })
  | [ d; "de"; m; ("de" | "del"); a ] ->
      con_mes d m (fun dia mes ->
          Option.map (fun anyo -> { anyo; mes; dia }) (num a))
  | _ -> None

let aplicar ~hoy texto =
  let palabras = normalizar texto in
  let junto = String.concat " " palabras in
  let candidata =
    match List.assoc_opt junto relativas with
    | Some n -> Some (de_dias (a_dias hoy + n))
    | None -> (
        match palabras with
        | [ p ] -> numerica p
        | _ -> textual ~hoy palabras)
  in
  match candidata with
  | None -> Error ("fuera de dominio: " ^ texto)
  | Some f when not (valida f) -> Error ("fecha imposible: " ^ texto)
  | Some f -> Ok f

let cristal ~hoy = Cristal.cristal "fecha-es" (aplicar ~hoy)
