(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type oferta = {
  url : string;
  titulo : string;
  empresa : string;
  ubicacion : string;
  descripcion : string;
}

(* {1 Texto} *)

let indice s sub ~desde =
  let n = String.length sub and m = String.length s in
  let rec ir i = if i + n > m then None else if String.sub s i n = sub then Some i else ir (i + 1) in
  ir desde

let contiene s sub = Option.is_some (indice s sub ~desde:0)

(* Palabras en minúsculas: letras ASCII, dígitos y cualquier byte de UTF-8
   (así «años» es una palabra). *)
let palabras s =
  let s = String.lowercase_ascii s in
  let es c = match c with 'a' .. 'z' | '0' .. '9' -> true | c -> Char.code c >= 128 in
  let h = Hashtbl.create 64 and b = Buffer.create 16 in
  let cerrar () =
    if Buffer.length b > 0 then (
      Hashtbl.replace h (Buffer.contents b) ();
      Buffer.clear b)
  in
  String.iter (fun c -> if es c then Buffer.add_char b c else cerrar ()) s;
  cerrar ();
  h

let alguna ws l = List.exists (Hashtbl.mem ws) l

(* Alguna palabra que empiece por alguno de los prefijos. *)
let empieza ws ps =
  Hashtbl.fold (fun w () acc -> acc || List.exists (fun p -> String.starts_with ~prefix:p w) ps) ws false

(* {1 Lectura} *)

let linea s campo =
  match indice s ("\n" ^ campo ^ ": ") ~desde:0 with
  | None -> ""
  | Some i ->
      let a = i + String.length campo + 3 in
      let b = Option.value ~default:(String.length s) (indice s "\n" ~desde:a) in
      String.trim (String.sub s a (b - a))

let leer s =
  match indice s "<posting>" ~desde:0 with
  | None -> None
  | Some i ->
      let a = i + String.length "<posting>" in
      let b = Option.value ~default:(String.length s) (indice s "</posting>" ~desde:a) in
      let p = "\n" ^ String.sub s a (b - a) in
      let descripcion =
        match indice p "\nDescription:" ~desde:0 with
        | Some d -> String.sub p (d + 13) (String.length p - d - 13)
        | None -> ""
      in
      Some
        { url = linea p "URL";
          titulo = linea p "Title";
          empresa = linea p "Company";
          ubicacion = linea p "Location";
          descripcion }

(* {1 Campos} *)

(* Salario: si la oferta no da ninguna señal de dinero, los cuatro campos
   son null. Con alguna, los decide el LLM. *)
let senales_dinero =
  [ "salary"; "salaries"; "salario"; "sueldo"; "retribución"; "retribucion"; "gehalt"; "vergütung";
    "verguetung"; "lohn"; "stundenlohn"; "brutto"; "bruto"; "løn"; "lön"; "lønn"; "salaire";
    "rémunération"; "stipendio"; "compensation"; "pay"; "paid"; "wage"; "wages"; "eur"; "euro";
    "euros"; "gbp"; "usd"; "chf"; "dkk"; "sek"; "nok"; "pln"; "czk"; "huf"; "ron"; "aud"; "cad";
    "kr"; "annum"; "hourly"; "ote"; "k€"; "€k" ]

let simbolos_dinero = [ "€"; "£"; "$"; "¥"; "₹" ]

(* "60k", "60K", "60.000": un número seguido de k también es dinero. *)
let numero_k s =
  let s = String.lowercase_ascii s in
  let n = String.length s in
  let rec ir i =
    i + 1 < n
    && ((match s.[i] with '0' .. '9' -> s.[i + 1] = 'k' && (i + 2 >= n || not (match s.[i + 2] with 'a' .. 'z' -> true | _ -> false)) | _ -> false)
       || ir (i + 1))
  in
  ir 0

let sin_salario o ws =
  let todo = o.titulo ^ "\n" ^ o.descripcion in
  if alguna ws senales_dinero || List.exists (contiene todo) simbolos_dinero || numero_k todo then []
  else
    [ ("salaryMin", `Null); ("salaryMax", `Null); ("salaryCurrency", `Null); ("salaryPeriod", `Null) ]

(* Años de experiencia: sin ninguna palabra de años, null. *)
let senales_anyos =
  [ "year"; "years"; "yr"; "yrs"; "año"; "años"; "anos"; "jahr"; "jahre"; "jahren"; "ans"; "année";
    "années"; "år"; "års"; "anni"; "anno"; "jaar"; "jaren"; "lat"; "vuotta"; "yoe" ]

let sin_anyos ws = if alguna ws senales_anyos then [] else [ ("yoeMin", `Null); ("yoeMax", `Null) ]

(* Easy Apply: lo dice el texto, o no lo es. *)
let easy_apply o =
  let t = String.lowercase_ascii (o.titulo ^ "\n" ^ o.descripcion) in
  [ ("isEasyApply", `Bool (contiene t "easy apply")) ]

(* Seniority por el título, de más a menos: principal (o senior staff),
   lead (lead, director, head), senior, junior, entry (prácticas). Sin
   ninguna, o con «mid» (Mid/Senior), el LLM: manager y staff no dicen cuál. *)
let seniority o =
  let t = palabras o.titulo in
  let de v = [ ("seniority", `String v) ] in
  if alguna t [ "mid" ] then []
  else if alguna t [ "principal" ] || (alguna t [ "staff" ] && alguna t [ "senior"; "sr" ]) then de "principal"
  else if alguna t [ "lead"; "director"; "head" ] then de "lead"
  else if alguna t [ "senior"; "sr"; "snr" ] then de "senior"
  else if alguna t [ "junior"; "jr" ] then de "junior"
  else if alguna t [ "intern"; "internship"; "werkstudent"; "praktikant"; "praktikantin"; "becario"; "becaria" ]
  then de "entry"
  else []

(* Modalidad: sin ninguna palabra de remoto o híbrido en toda la oferta, la
   extracción dice onsite (su regla: «onsite si no se menciona»). *)
let senales_modalidad =
  [ "remote"; "remotely"; "remoto"; "remota"; "teletrabajo"; "telework"; "teletravail"; "hybrid";
    "hybride"; "hybridt"; "híbrido"; "hibrido"; "híbrida"; "homeoffice"; "wfh"; "anywhere";
    "distributed"; "fjernarbejde"; "hjemmefra"; "telearbeit"; "home"; "zuhause" ]

(* Flexible, mobiles Arbeiten, hjemmearbejde...: el LLM las lee como híbrido o
   remoto. *)
let prefijos_modalidad = [ "flexib"; "mobil"; "hjemme"; "ortsunabh"; "telecommut"; "virtual" ]

let modalidad o ws =
  let t = String.lowercase_ascii (o.titulo ^ "\n" ^ o.ubicacion ^ "\n" ^ o.descripcion) in
  if alguna ws senales_modalidad || empieza ws prefijos_modalidad || contiene t "home office" || contiene t "from home" then []
  else [ ("workMode", `String "onsite") ]

let campos o =
  let ws = palabras (o.titulo ^ "\n" ^ o.ubicacion ^ "\n" ^ o.descripcion) in
  List.concat
    [ sin_salario o ws; sin_anyos ws; easy_apply o; seniority o; modalidad o ws ]

let cristal =
  Cristal.cristal "oferta-trabajo" (fun s ->
      match leer s with
      | None -> Error "fuera de dominio: no hay <posting>"
      | Some o -> Ok (Yojson.Safe.to_string (`Assoc (campos o))))
