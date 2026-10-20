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
let contiene_alguna s l = List.exists (contiene s) l

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

(* {2 Fichas}

   El texto en minúsculas como una secuencia de fichas: números (con sus
   separadores de miles o decimales: «45.000», «117,000», «2,5»), palabras
   (letras y bytes de UTF-8: «Profile5+» son «profile», «5» y «+») y signos sueltos. Los
   símbolos de moneda, los guiones largos y los puntos medios de UTF-8 son
   signos, no letras. *)

type ficha = Num of string | Pal of string | Sig of string

let signos_utf8 =
  [ ("\xe2\x82\xac", "€"); ("\xc2\xa3", "£"); ("\xc2\xa5", "¥"); ("\xe2\x82\xb9", "₹");
    ("\xe2\x80\x93", "-"); ("\xe2\x80\x94", "-"); ("\xc2\xb7", "·"); ("\xe2\x80\xa2", "·");
    (* Espacios duros y comillas tipográficas: separan, como un espacio o un apóstrofo. *)
    ("\xc2\xa0", ""); ("\xe2\x80\xaf", ""); ("\xe2\x80\x89", ""); ("\xe2\x80\x99", "'");
    ("\xe2\x80\x98", "'"); ("\xe2\x80\x9c", "\""); ("\xe2\x80\x9d", "\""); ("\xe2\x80\xa6", ".");
    ("\xc2\xab", "\""); ("\xc2\xbb", "\"") ]

let fichas s =
  let s = String.lowercase_ascii s in
  let n = String.length s in
  let signo i =
    List.find_map
      (fun (b, v) ->
        let l = String.length b in
        if i + l <= n && String.sub s i l = b then Some (v, l) else None)
      signos_utf8
  in
  let digito i = i < n && match s.[i] with '0' .. '9' -> true | _ -> false in
  let letra i =
    i < n && (match s.[i] with 'a' .. 'z' -> true | c -> Char.code c >= 128) && signo i = None
  in
  let rec ir i acc =
    if i >= n then List.rev acc
    else
      match signo i with
      | Some ("", l) -> ir (i + l) acc
      | Some (v, l) -> ir (i + l) (Sig v :: acc)
      | None ->
          if digito i then (
            let j = ref i in
            while digito !j || (!j < n && (s.[!j] = '.' || s.[!j] = ',') && digito (!j + 1)) do incr j done;
            ir !j (Num (String.sub s i (!j - i)) :: acc))
          else if letra i then (
            let j = ref i in
            while letra !j do incr j done;
            ir !j (Pal (String.sub s i (!j - i)) :: acc))
          else
            match s.[i] with
            | ' ' | '\n' | '\t' | '\r' -> ir (i + 1) acc
            | c -> ir (i + 1) (Sig (String.make 1 c) :: acc)
  in
  Array.of_list (ir 0 [])

(* Un número entero: «45.000» y «117,000» son miles; «2,5», no. *)
let entero t =
  match String.split_on_char '.' (String.concat "." (String.split_on_char ',' t)) with
  | [ a ] -> int_of_string_opt a
  | a :: resto when String.length a <= 3 && List.for_all (fun g -> String.length g = 3) resto ->
      int_of_string_opt (String.concat "" (a :: resto))
  | _ -> None

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

(* Las fichas con que los portales resumen la oferta («Salario: 22000 -
   23000 EUR/año · Contrato: indefinido · Jornada: completa»): el valor de
   un campo, hasta el siguiente «·» o el final de la línea, en minúsculas.
   Solo si dice uno. *)
let ficha_portal o campo =
  let t = String.lowercase_ascii ("\n" ^ o.descripcion) in
  let valores =
    List.concat_map
      (fun pre ->
        let clave = pre ^ campo ^ ": " in
        let rec todas desde acc =
          match indice t clave ~desde with
          | None -> acc
          | Some i ->
              let a = i + String.length clave in
              let fin =
                List.fold_left
                  (fun m sep -> match indice t sep ~desde:a with Some j -> min m j | None -> m)
                  (String.length t) [ "\n"; "\xc2\xb7" ]
              in
              todas a (String.trim (String.sub t a (fin - a)) :: acc)
        in
        todas 0 [])
      [ "\n"; "\xc2\xb7 " ]
  in
  match List.sort_uniq compare valores with [ v ] -> Some v | _ -> None

(* {1 Campos} *)

(* {2 Salario}

   Sin ningún importe en la oferta (un número junto a una moneda, «60k», o
   una palabra de sueldo y una cifra de cinco dígitos), los cuatro campos
   son null: «competitive salary», «paid holidays» o «11 EUR meal vouchers»
   no los dan. Con la ficha del portal y un importe anual claro («Salary:
   70000 - 90000 EUR per year», «Salario: 45.000€ - 55.000€ por año»), los
   cuatro. Lo demás (mensual, por horas, en el texto libre) el LLM, que lo
   anualiza a su manera. *)

let monedas =
  [ ("eur", "EUR"); ("euro", "EUR"); ("euros", "EUR"); ("€", "EUR"); ("gbp", "GBP"); ("£", "GBP");
    ("usd", "USD"); ("$", "USD"); ("chf", "CHF"); ("dkk", "DKK"); ("sek", "SEK"); ("nok", "NOK");
    ("pln", "PLN"); ("czk", "CZK"); ("huf", "HUF"); ("ron", "RON"); ("aud", "AUD"); ("cad", "CAD");
    ("krw", "KRW"); ("inr", "INR"); ("₹", "INR"); ("¥", "JPY"); ("jpy", "JPY"); ("kr", "SEK") ]

let moneda = function Pal w | Sig w -> List.assoc_opt w monedas | Num _ -> None
let es_moneda f = Option.is_some (moneda f) || f = Pal "eu"

let palabras_sueldo =
  [ "salary"; "salaries"; "salario"; "sueldo"; "retribución"; "retribucion"; "gehalt"; "vergütung";
    "jahresgehalt"; "bruttogehalt"; "løn"; "lön"; "lønn"; "salaire"; "rémunération"; "stipendio"; "ral";
    "compensation"; "pay"; "wage"; "wages"; "ote"; "base"; "brutto"; "bruto"; "annum" ]

let importe fs =
  let n = Array.length fs in
  let junto j = j >= 0 && j < n && es_moneda fs.(j) in
  let miles j = j < n && match fs.(j) with Pal ("k" | "tsd" | "mil" | "m") -> true | _ -> false in
  let hay_importe = ref false in
  Array.iteri
    (fun i f -> match f with Num _ -> if junto (i - 1) || junto (i + 1) || miles (i + 1) then hay_importe := true | _ -> ())
    fs;
  let sueldo_y_cifra =
    Array.exists (function Pal w -> List.mem w palabras_sueldo | _ -> false) fs
    && Array.exists
         (function Num t -> ( match entero t with Some v -> v >= 10000 | None -> false) | _ -> false)
         fs
  in
  !hay_importe || sueldo_y_cifra

let anual = [ "year"; "yr"; "año"; "anual"; "annum"; "jahr"; "p"; "pa" ]

let otro_periodo =
  [ "month"; "mes"; "monat"; "monthly"; "hour"; "hora"; "hourly"; "day"; "día"; "dia"; "daily"; "week";
    "semana"; "rata"; "tag"; "stunde"; "k"; "m"; "desde"; "from"; "up"; "hasta"; "bis"; "ab"; "ote" ]

(* «70000 - 90000 eur per year», «45.000€ - 55.000€ por año», «24000 eur/año»:
   uno o dos importes enteros, una sola moneda, un periodo anual y nada más.
   Con un solo importe, el máximo lo pone el LLM: el esquema dice «igual al
   mínimo si es un importe único», pero gemma lo deja null la mitad de las
   veces. *)
let salario_portal v =
  let fs = Array.to_list (fichas v) in
  let pals = List.filter_map (function Pal w -> Some w | _ -> None) fs in
  let nums = List.filter_map (function Num t -> Some t | _ -> None) fs in
  let mons = List.sort_uniq compare (List.filter_map moneda fs) in
  let solo_importe =
    List.for_all
      (function
        | Num _ | Sig ("-" | "€" | "£" | "$" | "/" | ".") -> true
        | Pal w ->
            List.mem w anual
            || List.mem w [ "per"; "por"; "a"; "im"; "pro"; "brutto"; "bruto"; "gross" ]
            || Option.is_some (moneda (Pal w))
        | Sig _ -> false)
      fs
  in
  if (not solo_importe) || List.exists (fun w -> List.mem w otro_periodo) pals
     || not (List.exists (fun w -> List.mem w anual) pals)
  then None
  else
    match (mons, List.map entero nums) with
    | [ m ], [ Some a ] when a >= 1000 -> Some (a, None, m)
    | [ m ], [ Some a; Some b ] when a >= 1000 && a <= b -> Some (a, Some b, m)
    | _ -> None

let salario o fs =
  let portal = List.find_map (ficha_portal o) [ "salary"; "salario" ] in
  match Option.bind portal salario_portal with
  | Some (a, b, m) ->
      [ ("salaryMin", `Int a); ("salaryCurrency", `String m); ("salaryPeriod", `String "ANNUAL") ]
      @ (match b with Some b -> [ ("salaryMax", `Int b) ] | None -> [])
  | None ->
      if portal = None && not (importe fs) then
        [ ("salaryMin", `Null); ("salaryMax", `Null); ("salaryCurrency", `Null); ("salaryPeriod", `Null) ]
      else []

(* {2 Años de experiencia}

   Una cifra a pocas fichas de una palabra de años («5+ years», «3-5 Jahre»,
   «1 año», «two years») es una pista; sin ninguna, y sin «sin
   experiencia», «mehrjährige» ni «several years» (que el LLM convierte en
   una cifra), null. Con pistas, el LLM: no hay regla que separe la
   experiencia pedida de «10 years in business». *)

let palabras_anyo =
  [ "year"; "years"; "yr"; "yrs"; "año"; "años"; "anos"; "jahr"; "jahre"; "jahren"; "jahres"; "ans";
    "année"; "années"; "år"; "års"; "anni"; "anno"; "jaar"; "jaren"; "lat"; "vuotta"; "yoe" ]

let cifras_escritas =
  [ "one"; "two"; "three"; "four"; "five"; "six"; "seven"; "eight"; "nine"; "ten"; "ein"; "einem";
    "zwei"; "drei"; "vier"; "fünf"; "sechs"; "un"; "uno"; "dos"; "tres"; "cuatro"; "cinco"; "seis";
    "to"; "tre"; "fire"; "fem"; "seks"; "deux"; "trois"; "cinq"; "several"; "many"; "mehrere";
    "mehreren"; "einige"; "einigen"; "varios"; "multiple"; "few"; "couple"; "flere"; "några" ]

let pista_anyos fs =
  let r = ref false in
  Array.iteri
    (fun i f ->
      match f with
      | Pal w when List.mem w palabras_anyo ->
          (* Hasta cuatro fichas atrás: «5+ years», «3 - 5 years», «3 or more years». *)
          for j = max 0 (i - 4) to i - 1 do
            match fs.(j) with Num _ -> r := true | Pal p when List.mem p cifras_escritas -> r := true | _ -> ()
          done
      | _ -> ())
    fs;
  !r

let experiencia_vaga =
  [ "sin experiencia"; "no experience"; "no prior experience"; "no previous experience"; "keine erfahrung";
    "keine berufserfahrung"; "ohne erfahrung"; "ohne berufserfahrung"; "no se requiere experiencia";
    "no requiere experiencia"; "mehrjährig"; "langjährig"; "erste berufserfahrung"; "erste erfahrung";
    "several years"; "many years"; "varios años"; "flerårig"; "årelang" ]

let anyos o fs =
  let t = String.lowercase_ascii (o.titulo ^ "\n" ^ o.descripcion) in
  if pista_anyos fs || contiene_alguna t experiencia_vaga then [] else [ ("yoeMin", `Null); ("yoeMax", `Null) ]

(* {2 Easy Apply}: lo dice el texto, o no lo es. *)
let easy_apply o =
  let t = String.lowercase_ascii (o.titulo ^ "\n" ^ o.descripcion) in
  [ ("isEasyApply", `Bool (contiene t "easy apply")) ]

(* {2 Seniority} por el título, de más a menos: principal (o senior staff),
   lead (lead, director, head, VP), senior, junior, entry (prácticas,
   Werkstudent, Ausbildung). Sin ninguna, o con «mid» (Mid/Senior), el LLM:
   manager y staff no dicen cuál. *)
let seniority o =
  let t = palabras o.titulo and tl = String.lowercase_ascii o.titulo in
  let de v = [ ("seniority", `String v) ] in
  if alguna t [ "mid" ] then []
  else if alguna t [ "principal" ] || (alguna t [ "staff" ] && alguna t [ "senior"; "sr" ]) then de "principal"
  else if alguna t [ "lead"; "director"; "head"; "vp" ] || contiene tl "vice president" then de "lead"
  else if alguna t [ "senior"; "sr"; "snr" ] then de "senior"
  else if alguna t [ "junior"; "jr" ] then de "junior"
  else if
    alguna t
      [ "intern"; "internship"; "werkstudent"; "praktikant"; "praktikantin"; "becario"; "becaria"; "ausbildung";
        "prácticas"; "practicas"; "studentische" ]
    || contiene tl "working student"
  then de "entry"
  else []

(* {2 Modalidad}

   La ficha del portal («Modalidad: presencial») si es una sola. Si no, sin
   ninguna señal de remoto, híbrido, home office, flexible o móvil, onsite
   (la regla del propio prompt). Con la ubicación «Remote…» y nada que hable
   de oficina, horario flexible o híbrido, remote. Con trabajo híbrido
   («hybrid work», «hybrides Arbeiten»; no «hybrid cloud») y ninguna señal de
   remoto, hybrid. *)

let senales_remoto =
  [ "remote"; "remotely"; "remoto"; "remota"; "teletrabajo"; "telework"; "teletravail"; "homeoffice"; "wfh";
    "anywhere"; "distributed"; "fjernarbejde"; "hjemmefra"; "telearbeit"; "home"; "zuhause" ]

let senales_hibrido =
  [ "hybrid"; "hybride"; "hybridt"; "híbrido"; "hibrido"; "híbrida"; "hibrida"; "hybrides"; "hybriden";
    "hybrider"; "hybridem" ]

(* Flexible, mobiles Arbeiten, hjemmearbejde...: el LLM las lee como híbrido o
   remoto. *)
let prefijos_modalidad = [ "flexib"; "mobil"; "hjemme"; "ortsunabh"; "telecommut"; "virtual" ]

(* Lo que sigue a un «hybrid» que no es de trabajo: hybrid cloud, hybride
   Umgebungen, hybrid & multi-cloud... *)
let hibrido_tecnico =
  [ "cloud"; "clouds"; "umgebung"; "umgebungen"; "environment"; "environments"; "infrastructure";
    "infrastructures"; "it"; "systems"; "system"; "apps"; "app"; "solutions"; "lösungen"; "multi";
    "mobile"; "integration"; "networks"; "network"; "architecture"; "architectures"; "approach";
    "vehicles"; "vehicle"; "car"; "cars"; "electric"; "engine"; "powertrain"; "drive"; "search";
    "storage"; "data"; "on"; "workloads"; "multicloud"; "models"; "model"; "ai"; "methods"; "agile";
    "nube"; "aws"; "azure"; "&"; "and"; "und"; "y"; "or"; "oder"; "/"; "-" ]

(* (hay trabajo híbrido, hay un «hybrid» técnico) *)
let hibrido_de_trabajo fs =
  let n = Array.length fs in
  let trabajo = ref false and tecnico = ref false in
  let es_tec = function Pal p | Sig p -> List.mem p hibrido_tecnico | Num _ -> false in
  Array.iteri
    (fun i f ->
      match f with
      | Pal w when List.mem w senales_hibrido ->
          let siguiente = if i + 1 < n then fs.(i + 1) else Sig "" in
          let previa = if i > 0 then fs.(i - 1) else Sig "" in
          if es_tec siguiente || List.mem previa [ Pal "or"; Pal "oder"; Pal "and" ] then tecnico := true
          else trabajo := true
      | _ -> ())
    fs;
  (!trabajo, !tecnico)

let senales_oficina =
  [ "office"; "büro"; "oficina"; "on-site"; "onsite"; "on site"; "in-person"; "in person"; "presencial";
    "days a week"; "days per week"; "tage pro woche"; "días a la semana"; "flexib"; "hybrid"; "hybride";
    "híbrid"; "hibrid"; "workation"; "commut"; "relocat"; "kontor"; "standort"; "vor ort" ]

let modalidad_portal = function
  | "presencial" -> Some "onsite"
  | "teletrabajo" | "remoto" | "100% remoto" -> Some "remote"
  | "híbrido" | "hibrido" -> Some "hybrid"
  | _ -> None

let modalidad o fs ws =
  let t = String.lowercase_ascii (o.titulo ^ "\n" ^ o.ubicacion ^ "\n" ^ o.descripcion) in
  let remoto =
    alguna ws senales_remoto || empieza ws prefijos_modalidad || contiene t "home office" || contiene t "from home"
    || contiene (String.lowercase_ascii o.url) "remote"
  in
  let hibrido, hibrido_tec = hibrido_de_trabajo fs in
  let de v = [ ("workMode", `String v) ] in
  match Option.bind (ficha_portal o "modalidad") modalidad_portal with
  | Some v -> de v
  | None ->
      if not (remoto || hibrido || hibrido_tec) then de "onsite"
      else if
        contiene (String.lowercase_ascii o.ubicacion) "remote"
        && (not hibrido)
        && not (contiene_alguna (String.lowercase_ascii o.descripcion) senales_oficina)
      then de "remote"
      else if hibrido && not (remoto || hibrido_tec) then de "hybrid"
      else []

(* {2 Contrato}

   Con la ficha del portal («Contrato: indefinido»), su tipo cuando es
   inequívoco. Sin ninguna palabra de contrato, jornada, prácticas,
   formación, duración, plazas o autónomos en la oferta, null: el LLM no se
   inventa el contrato que la oferta no dice. *)

let contrato_portal = function
  | "indefinido" | "indefinido." | "laboral indefinido" | "permanente" | "permanent" | "permanent (cdi)"
  | "festanstellung" ->
      Some "permanent"
  | "freelance" -> Some "freelance"
  | "de duración determinada" -> Some "fixed_term"
  | "arbeitnehmerüberlassung" -> Some "temporary"
  | "prácticas" | "practicas" | "internship" -> Some "internship"
  | _ -> None

let senales_contrato =
  [ "permanen"; "indefinid"; "unbefristet"; "befristet"; "festanstellung"; "fest angestellt"; "feste anstellung";
    "fastansættelse"; "fast stilling"; "fast anställning"; "tillsvidare"; "temporary"; "temporal"; "temporär";
    "vikar"; "fixed-term"; "fixed term"; "duración determinada"; "freelance"; "freiberuf"; "contractor";
    "contract"; "contrato"; "vertrag"; "interim"; "intern"; "praktik"; "ausbildung"; "apprentic"; "azubi";
    "werkstudent"; "working student"; "student"; "prácticas"; "practicas"; "práctica"; "practica"; "becari";
    "trainee"; "duales"; "stage"; "stagiaire"; "thesis"; "phd"; "doctoral"; "postdoc"; "post-doc"; "tenure";
    "seasonal"; "saison"; "summer"; "sommer"; "verano"; "maternity"; "elternzeit"; "cover"; "zeitarbeit";
    "leiharbeit"; "arbeitnehmerüberlassung"; " ett "; "project"; "projekt"; "months"; "monate"; "meses";
    "måneder"; "full-time"; "full time"; "fulltime"; "vollzeit"; "jornada"; "tiempo completo"; "part-time";
    "part time"; "teilzeit"; "deltid"; "fuldtid"; "heltid"; "w2"; "1099"; "b2b"; "self-employed";
    "selbstständig"; "selbständig"; "autónomo"; "day rate"; "daily rate"; "ir35"; "elev"; "lærling";
    "studiejob"; "plaza"; "convocatoria"; "oposici"; "funcionari"; "minijob"; "aushilfe"; "kesä"; "harjoitt";
    "määräaika"; "vakituinen"; "tutkij"; "henkilöstö"; "tirocinio"; "indeterminato"; "determinato"; "cdi"; "cdd"; "alternance";
    "employment type"; "job type"; "anstellungsart"; "tipo:" ]

let contrato o =
  match ficha_portal o "contrato" with
  | Some v -> ( match contrato_portal v with Some c -> [ ("contractType", `String c) ] | None -> [])
  | None ->
      let t = " " ^ String.lowercase_ascii (o.titulo ^ "\n" ^ o.descripcion) ^ " " in
      if contiene_alguna t senales_contrato then [] else [ ("contractType", `Null) ]

(* {2 Agencia}

   «Publica: Randstad…», una cesión de trabajadores (Arbeitnehmerüberlassung)
   o «unser Kunde» / «nuestro cliente»: agencia. Sin ninguna señal de
   selección, ETT, consultoría o cliente en la oferta, con la empresa
   nombrada y un nombre que no suena a agencia, no lo es. Lo demás
   (consultoras, RPO, «our client») el LLM. *)

let senales_agencia =
  [ "recruit"; "agency"; "agencia"; "agentur"; "staffing"; "personalvermittl"; "personaldienst";
    "personalberat"; "arbeitnehmerüberlassung"; "zeitarbeit"; "leiharbeit"; " ett "; " ett,"; "randstad";
    "adecco"; "hays"; "manpower"; "michael page"; "robert half"; "page personnel"; "gi group"; "eurofirms";
    "synergie"; "experis"; "client"; "kunde"; "cliente"; "on behalf of"; "im auftrag"; "en nombre de";
    "headhunt"; "talent acquisition"; "rpo"; "outsourc"; "consultanc"; "vermittl"; "placement";
    "search firm"; "executive search"; "rekrutter"; "rekryter"; "bemanning"; "vikarbureau"; "barona";
    "dm me"; "employment business"; "employment agency"; "interim"; "empresa del sector";
    "empresa industrial"; "empresa tecnol"; "compañía del"; "compañía internacional"; "comañía";
    "henkilöstö"; "human capital"; "toimeksian" ]

(* Nombres de empresa que suenan a agencia, o que no dicen quién contrata. *)
let empresa_de_agencia =
  [ "unknown"; "resourc"; "staff"; "nash"; "halian"; "temp"; "hire"; "talent"; "toptal"; "people"; "jobs";
    "career"; "personal"; "consult"; "search"; "select"; "solutions"; "group"; "grupo"; "partners"; "hr ";
    "hrconnect"; "recruit"; "human"; "henkilöstö"; "work"; "reed"; "experis"; "anson"; "murray"; "arelance";
    "skills" ]

(* Empresas que son agencias por su nombre: selección de personal, cazatalentos,
   ETT y las grandes de la selección. *)
let agencias_por_nombre =
  [ " recruit"; "headhunt"; "staffing"; "randstad"; "adecco"; "manpower"; " hays "; "michael page";
    "page personnel"; "robert half"; "harvey nash"; "experis"; " reed technology"; "anson mccade"; "barona" ]

let agencia o =
  let t = " " ^ String.lowercase_ascii (o.titulo ^ "\n" ^ o.descripcion) ^ " " in
  let e = " " ^ String.lowercase_ascii o.empresa ^ " " in
  match ficha_portal o "publica" with
  | Some p when String.starts_with ~prefix:"randstad" p -> [ ("isAgency", `Bool true) ]
  | _ ->
      if contiene_alguna e agencias_por_nombre
         || contiene_alguna t [ "arbeitnehmerüberlassung"; "unser kunde"; "unseres kunden"; "unserem kunden"; "nuestro cliente" ]
      then [ ("isAgency", `Bool true) ]
      else if String.trim e = "" || contiene_alguna e empresa_de_agencia || contiene_alguna e senales_agencia
              || contiene_alguna t senales_agencia then []
      else [ ("isAgency", `Bool false) ]

(* {2 Idiomas exigidos}

   Los que la oferta pide, en ISO 639-1, ordenados; [] si no exige ninguno.
   No los que valora («a plus», «se valorará», «von Vorteil»), ni el idioma en
   que está escrita, ni los gentilicios («Dutch market», «territorio
   español»). Se exige un idioma que la oferta nombra en una frase con una
   señal de exigencia (nivel, «fluent», «Kenntnisse», «imprescindible»…) o en
   la ficha del portal («Idiomas: english», «Idioma de trabajo: alemán»). *)

(* Minúsculas también para las letras latinas con tilde («INGLÉS»): en UTF-8,
   C3 80–9E son las mayúsculas de Latin-1 y la minúscula está 0x20 más allá. *)
let minusculas s =
  let b = Bytes.of_string (String.lowercase_ascii s) in
  Bytes.iteri
    (fun i c ->
      if c = '\xc3' && i + 1 < Bytes.length b then
        let d = Char.code (Bytes.get b (i + 1)) in
        if d >= 0x80 && d <= 0x9e && d <> 0x97 then Bytes.set b (i + 1) (Char.chr (d + 0x20)))
    b;
  Bytes.to_string b

(* Los signos de UTF-8 que separan palabras: «¡» y «¿», comillas, guiones y
   viñetas. Sin esto «¡Bonus» sería una palabra que no empieza por «bonus». *)
let signos_separadores =
  [ "\xc2\xa1"; "\xc2\xbf"; "\xc2\xb7"; "\xc2\xab"; "\xc2\xbb"; "\xe2\x80\x93"; "\xe2\x80\x94"; "\xe2\x80\x98";
    "\xe2\x80\x99"; "\xe2\x80\x9c"; "\xe2\x80\x9d"; "\xe2\x80\xa2" ]

let sin_signos s =
  List.fold_left
    (fun s sg -> String.concat " " (let rec partes t = match indice t sg ~desde:0 with None -> [ t ] | Some i -> String.sub t 0 i :: partes (String.sub t (i + String.length sg) (String.length t - i - String.length sg)) in partes s))
    s signos_separadores

(* Las palabras en orden: hacen falta la anterior y la siguiente. *)
let lista_palabras s =
  let es c = match c with 'a' .. 'z' | '0' .. '9' -> true | c -> Char.code c >= 128 in
  let b = Buffer.create 16 and acc = ref [] in
  let cerrar () = if Buffer.length b > 0 then (acc := Buffer.contents b :: !acc; Buffer.clear b) in
  String.iter (fun c -> if es c then Buffer.add_char b c else cerrar ()) (minusculas (sin_signos s));
  cerrar ();
  List.rev !acc

let nombres_idioma =
  [ ("en", [ "english"; "englisch"; "inglés"; "ingles"; "anglais"; "engelsk"; "engels"; "inglese" ]);
    ("de", [ "german"; "deutsch"; "alemán"; "aleman"; "allemand"; "tysk"; "duits"; "tedesco" ]);
    ("es", [ "spanish"; "español"; "espanol"; "castellano"; "spansk"; "spanisch"; "espagnol"; "spaans"; "spagnolo" ]);
    ("fr", [ "french"; "français"; "francais"; "francés"; "französisch"; "fransk"; "francese" ]);
    ("it", [ "italian"; "italiano"; "italienisch"; "italiensk"; "italiaans" ]);
    ("nl", [ "dutch"; "nederlands"; "niederländisch"; "holandés"; "neerlandés"; "néerlandais"; "hollandsk" ]);
    ("pt", [ "portuguese"; "português"; "portugués"; "portugiesisch"; "portugais" ]);
    ("da", [ "danish"; "dansk"; "danés"; "dänisch"; "danois"; "deens" ]);
    ("sv", [ "swedish"; "svenska"; "svensk"; "sueco"; "schwedisch"; "suédois"; "zweeds" ]);
    ("no", [ "norwegian"; "norsk"; "noruego"; "norwegisch"; "norvégien" ]);
    ("fi", [ "finnish"; "suomi"; "finés"; "finlandés"; "finnisch" ]);
    ("pl", [ "polaco"; "polnisch"; "polonais"; "polski" ]);
    ("ru", [ "russian"; "russisch"; "ruso"; "russe"; "russisk" ]);
    ("ar", [ "arabic"; "árabe"; "arabisch" ]);
    ("zh", [ "chinese"; "mandarin"; "chino"; "chinesisch"; "mandarín" ]);
    ("ja", [ "japanese"; "japonés"; "japanisch"; "japonais" ]);
    ("ko", [ "korean"; "coreano"; "koreanisch" ]);
    ("tr", [ "turkish"; "turco"; "türkisch" ]);
    ("cs", [ "czech"; "checo"; "tschechisch" ]);
    ("ro", [ "romanian"; "rumano"; "rumänisch"; "roumain" ]);
    ("el", [ "greek"; "griego"; "griechisch" ]);
    ("hu", [ "hungarian"; "húngaro"; "ungarisch"; "hongrois" ]);
    ("ca", [ "catalán"; "català"; "catalan" ]);
    ("eu", [ "euskera"; "euskara" ]);
    ("gl", [ "gallego"; "galego" ]) ]

let codigo_de w = List.find_map (fun (c, ns) -> if List.mem w ns then Some c else None) nombres_idioma

(* Las compuestas del alemán y del danés nombran el idioma y la exigencia a la
   vez: Deutschkenntnisse, englischsprachig, danskkundskaber. *)
let compuestas =
  [ ("deutsch", "de"); ("englisch", "en"); ("französisch", "fr"); ("spanisch", "es"); ("italienisch", "it");
    ("niederländisch", "nl"); ("polnisch", "pl"); ("russisch", "ru"); ("türkisch", "tr"); ("dansk", "da");
    ("engelsk", "en"); ("tysk", "de") ]

let colas_de_exigencia = [ "kenntnis"; "sprachig"; "kundskab"; "sprachkennt" ]

let compuesta w =
  List.find_map
    (fun (raiz, c) ->
      if String.starts_with ~prefix:raiz w then
        let resto = String.sub w (String.length raiz) (String.length w - String.length raiz) in
        if List.exists (fun p -> String.starts_with ~prefix:p resto) colas_de_exigencia then Some c else None
      else None)
    compuestas

(* El gentilicio de un nombre: «Dutch market», «territorio español». *)
let sustantivo_despues =
  [ "market"; "markets"; "markt"; "company"; "companies"; "culture"; "customers"; "clients"; "law"; "government";
    "citizens"; "nationality"; "ticket"; "speaking"; "speaker"; "speakers" ]

let sustantivo_antes = [ "territorio"; "mercado"; "mercados"; "empresa"; "estado"; "gobierno"; "nacionalidad"; "sector" ]

let senal_prefijos =
  [ "fluen"; "flie"; "proficien"; "level"; "nivel"; "niveau"; "skill"; "kenntnis"; "verhandlungssicher";
    "muttersprach"; "native"; "nativ"; "requir"; "must"; "essential"; "imprescindible"; "obligatori"; "requisit";
    "requerid"; "necesari"; "excellent"; "excelente"; "strong"; "high"; "avanzad"; "advanced"; "intermedi";
    "business"; "written"; "spoken"; "schrift"; "communicat"; "comunica"; "kommunik"; "speak"; "spreek"; "sprich";
    "spricht"; "beherrsch"; "bilingu"; "bilingü"; "dominio"; "domin"; "habla"; "command"; "mother"; "sicher";
    "perfect"; "perfekt"; "parler"; "básic"; "basic"; "elemental"; "maîtris"; "courant"; "flydende"; "kundskab"; "vloeiend"; "beheers"; "fließ" ]

let senal_palabras = [ "good"; "gute"; "guten"; "sehr"; "alto"; "alta"; "buen"; "buena"; "god"; "gode"; "goed"; "goede";
                       "wort"; "a1"; "a2"; "b1"; "b2"; "c1"; "c2" ]

let quita_prefijos =
  [ "advantage"; "ventaja"; "vorteil"; "plus"; "bonus"; "nice"; "desirable"; "deseable"; "valor"; "wünschenswert";
    "optional"; "opcional"; "preferib"; "preferred"; "additional"; "adicional"; "otros"; "otras"; "other"; "weitere";
    "ideally"; "idealmente"; "beneficial"; "asset"; "gerne"; "welcome"; "valued"; "valuable"; "appreciat" ]

let genericos = [ "language"; "languages"; "idioma"; "idiomas"; "sprache"; "sprachen"; "langue"; "langues"; "sprog" ]

(* Lo que el portal añade a todas sus ofertas: «Find more English Speaking Jobs
   in Germany on Arbeitnow», la navegación de englishjobs.de. *)
let relleno = [ "speaking jobs in"; "english jobs in"; "jobs in germany on arbeitnow"; "find jobs in" ]

let fichas_idioma = [ "idiomas:"; "idioma:"; "idioma de trabajo:"; "languages:"; "language:"; "sprachen:"; "sprache:"; "sprog:" ]

let local = [ "idioma local"; "local language"; "lengua local"; "landessprache"; "idioma del país" ]

(* El idioma del país de la oferta, para «idioma local imprescindible»: por la
   ubicación y, si no lo dice, por el dominio del portal. *)
let idioma_del_pais o =
  let u = minusculas o.ubicacion in
  let por_ubicacion =
    [ ("es", [ "spain"; "españa"; "espana"; "málaga"; "malaga"; "madrid"; "barcelona"; "sevilla"; "valencia"; "marbella" ]);
      ("de", [ "germany"; "deutschland"; "alemania"; "berlin"; "münchen"; "munich"; "hamburg"; "frankfurt" ]);
      ("da", [ "denmark"; "danmark"; "københavn"; "copenhagen"; "aarhus" ]);
      ("nl", [ "netherlands"; "nederland"; "amsterdam"; "rotterdam" ]);
      ("fr", [ "france"; "paris"; "lyon" ]);
      ("it", [ "italy"; "italia"; "milano"; "roma" ]);
      ("pt", [ "portugal"; "lisboa"; "porto" ]) ]
  in
  match List.find_opt (fun (_, ls) -> contiene_alguna u ls) por_ubicacion with
  | Some (c, _) -> Some c
  | None ->
      let host = match String.split_on_char '/' o.url with _ :: _ :: h :: _ -> h | _ -> "" in
      List.find_map
        (fun (tld, c) -> if String.ends_with ~suffix:tld host then Some c else None)
        [ (".es", "es"); (".de", "de"); (".at", "de"); (".dk", "da"); (".nl", "nl"); (".fr", "fr"); (".it", "it"); (".pt", "pt") ]

(* Trozos del texto que se juzgan juntos: líneas, viñetas y frases. *)
let segmentos s =
  let partir seps l = List.concat_map (fun x -> String.split_on_char seps x) l in
  let frases t =
    let rec ir acc i desde =
      match indice t ". " ~desde:i with
      | None -> List.rev (String.sub t desde (String.length t - desde) :: acc)
      | Some j -> ir (String.sub t desde (j - desde) :: acc) (j + 2) (j + 2)
    in
    ir [] 0 0
  in
  [ s ] |> partir '\n' |> partir ';' |> List.concat_map (String.split_on_char '\xb7' (* «·» acaba en B7 *))
  |> List.concat_map (fun t ->
         (* «•» es E2 80 A2 *)
         let rec cortar t =
           match indice t "\xe2\x80\xa2" ~desde:0 with
           | None -> [ t ]
           | Some i -> String.sub t 0 i :: cortar (String.sub t (i + 3) (String.length t - i - 3))
         in
         cortar t)
  |> List.concat_map frases

(* Las menciones de idioma de un trozo, con su posición en las palabras. *)
let menciones_en ws =
  let a = Array.of_list ws in
  let n = Array.length a in
  List.concat
    (List.mapi
       (fun i w ->
         match compuesta w with
         | Some c -> [ (i, c, true) ]
         | None -> (
             match codigo_de w with
             | None -> []
             | Some c ->
                 let siguiente = if i + 1 < n then a.(i + 1) else "" and anterior = if i > 0 then a.(i - 1) else "" in
                 if List.mem siguiente sustantivo_despues && not (List.mem siguiente [ "speaking"; "speaker"; "speakers" ])
                 then []
                 else if List.mem anterior sustantivo_antes then []
                 else [ (i, c, false) ]))
       ws)

let menciones ws = List.map (fun (_, c, s) -> (c, s)) (menciones_en ws)

let disyuntivas = [ "or"; "o"; "u"; "oder"; "ou"; "eller"; "of"; "oppure"; "lub" ]

(* Los idiomas que la oferta da como alternativa: «Spanish, Italian, or
   Portuguese», «German, French, Dutch, or other», «Catalan or French».
   Una lista de idiomas seguidos (las comas no son palabras) es alternativa
   si entre dos de ellos, o justo después del último, hay un «or». Ninguno
   queda exigido: no se sabe cuál. *)
let alternativas ws =
  let a = Array.of_list ws in
  let n = Array.length a in
  let ms = menciones_en ws in
  let rec tramos acc actual = function
    | [] -> List.rev (List.rev actual :: acc)
    | ((i, _, _) as m) :: resto -> (
        match actual with
        | (j, _, _) :: _ when i = j + 1 || (i = j + 2 && List.mem a.(j + 1) disyuntivas) -> tramos acc (m :: actual) resto
        | [] -> tramos acc [ m ] resto
        | _ -> tramos (List.rev actual :: acc) [ m ] resto)
  in
  tramos [] [] ms
  |> List.filter (fun t ->
         let rec pares = function
           | (i, _, _) :: ((j, _, _) :: _ as r) -> (j = i + 2 && List.mem a.(i + 1) disyuntivas) || pares r
           | [ (i, _, _) ] -> i + 1 < n && List.mem a.(i + 1) disyuntivas
           | [] -> false
         in
         List.length t >= 1 && pares t && (List.length t >= 2 || (match t with [ (i, _, _) ] -> i + 2 < n && List.mem a.(i + 2) [ "other"; "otros"; "otro"; "andere"; "anderen"; "autres" ] | _ -> false)))
  |> List.concat_map (List.map (fun (_, c, _) -> c))

let tiene_senal ws =
  List.exists (fun w -> List.mem w senal_palabras || List.exists (fun p -> String.starts_with ~prefix:p w) senal_prefijos) ws

let quita ws = List.exists (fun w -> List.exists (fun p -> String.starts_with ~prefix:p w) quita_prefijos) ws

(* Un trozo: si es ficha, todo lo que nombra; si no, lo que nombra con señal de
   exigencia, menos lo de las cláusulas que lo rebajan. Una cláusula que rebaja
   («a plus», «deseable») vale para ella y las que la siguen; si no nombra
   ningún idioma (ni siquiera «idioma»), para la última que sí nombraba uno:
   «Inglés alto (C1): deseable pero no obligatorio». *)
let exigidos_de_segmento o seg =
  let l = minusculas seg in
  let limpio = String.trim (String.concat "" (String.split_on_char '*' l)) in
  let limpio = if String.starts_with ~prefix:"-" limpio then String.trim (String.sub limpio 1 (String.length limpio - 1)) else limpio in
  if contiene_alguna l relleno then []
  else if List.exists (fun f -> String.starts_with ~prefix:f limpio) fichas_idioma then
    List.map fst (menciones (lista_palabras limpio))
  else
    let clausulas =
      List.concat_map (String.split_on_char ',') (List.concat_map (String.split_on_char ')') (String.split_on_char '(' l))
      |> List.map lista_palabras
    in
    let todas = List.concat clausulas in
    let alternativa = alternativas (lista_palabras l) in
    let sin_alternativas = List.filter (fun c -> not (List.mem c alternativa)) in
    sin_alternativas @@
    if not (tiene_senal todas) then
      (* Sin señal fuera de las compuestas: solo «Deutschkenntnisse», que la lleva dentro. *)
      List.concat_map (fun ws -> if quita ws then [] else List.filter_map (fun (c, s) -> if s then Some c else None) (menciones ws)) clausulas
    else
      let n = List.length clausulas in
      let fuera = Array.make n false in
      (* Si la única señal de exigencia está en lo que rebaja («Additional fluency
         in…»), la frase entera es de lo que se valora. *)
      let solo_rebaja =
        List.exists quita clausulas && not (List.exists (fun ws -> tiene_senal ws && not (quita ws)) clausulas)
      in
      if solo_rebaja then Array.fill fuera 0 n true;
      List.iteri
        (fun i ws ->
          if quita ws then (
            for j = i to n - 1 do fuera.(j) <- true done;
            let sin_idioma = menciones ws = [] && not (List.exists (fun w -> List.mem w genericos) ws) in
            if sin_idioma then
              let rec atras k = if k < 0 then () else if menciones (List.nth clausulas k) <> [] then fuera.(k) <- true else atras (k - 1) in
              atras (i - 1)))
        clausulas;
      let exigidos = List.concat (List.mapi (fun i ws -> if fuera.(i) then [] else List.map fst (menciones ws)) clausulas) in
      let local_exigido =
        contiene_alguna l local && not (quita (lista_palabras (String.concat " " (List.filteri (fun i _ -> i = 0) (String.split_on_char '(' l)))))
      in
      exigidos @ if local_exigido then Option.to_list (idioma_del_pais o) else []

let idiomas o =
  let codigos =
    List.concat_map (exigidos_de_segmento o) (segmentos (o.titulo ^ "\n" ^ o.descripcion)) |> List.sort_uniq compare
  in
  [ ("languages", `List (List.map (fun c -> `String c) codigos)) ]

let campos o =
  let todo = o.titulo ^ "\n" ^ o.ubicacion ^ "\n" ^ o.descripcion in
  let ws = palabras todo and fs = fichas todo in
  List.concat [ salario o fs; anyos o fs; easy_apply o; seniority o; modalidad o fs ws; contrato o; agencia o; idiomas o ]

let cristal =
  Cristal.cristal "oferta-trabajo" Cristal.texto (fun s ->
      match leer s with
      | None -> Error "fuera de dominio: no hay <posting>"
      | Some o -> Ok (Yojson.Safe.to_string (`Assoc (campos o))))

let descripcion =
  "De una oferta de trabajo (el mensaje de la extracción de trabajo.email, con <posting> y sus \
   líneas Title:, Company:, Location:, Description:), los campos que se deciden por reglas: el \
   salario (null si no da ningún importe; el de la ficha del portal si es anual y claro), años \
   de experiencia null si no da ninguna cifra de años, Easy Apply, seniority por el título, la \
   modalidad (onsite si no menciona remoto ni híbrido, remote con la ubicación «Remote» y sin \
   oficina, hybrid con trabajo híbrido y sin remoto, o la ficha del portal), el contrato (null \
   si no habla de él, o la ficha «Contrato:») y si es una agencia (por su nombre, «Publica: \
   Randstad» o la cesión de trabajadores; false si nada lo sugiere) y los idiomas que exige, en ISO \
   639-1 ([] si no exige ninguno; no los que valora, ni el de la oferta, ni las alternativas «German \
   or French»). Un objeto parcial: habilidades y tamaño de empresa no los da."
