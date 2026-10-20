(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type evidencia = {
  empresa : string;
  ubicaciones : string list;
  ofertas : string list;
  extracto : string;
}

(* {1 Texto} *)

let indice s sub ~desde =
  let n = String.length sub and m = String.length s in
  let rec ir i = if i + n > m then None else if String.sub s i n = sub then Some i else ir (i + 1) in
  if desde < 0 then None else ir desde

let contiene s sub = Option.is_some (indice s sub ~desde:0)

let ultimo s sub =
  let rec ir desde visto = match indice s sub ~desde with Some i -> ir (i + 1) (Some i) | None -> visto in
  ir 0 None

(* Letras ASCII, dígitos y cualquier byte de UTF-8: así «Zürich» y «Málaga»
   son una palabra. *)
let es_letra c = match c with 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' -> true | c -> Char.code c >= 128

(* [p] (en minúsculas) como palabra entera de [s] (en minúsculas). *)
let tiene_palabra s p =
  let n = String.length p and m = String.length s in
  let rec ir desde =
    match indice s p ~desde with
    | None -> false
    | Some i ->
        let antes = i = 0 || not (es_letra s.[i - 1]) in
        let despues =
          i + n >= m || (not (es_letra s.[i + n])) || (i + n + 3 <= m && String.sub s (i + n) 3 = "\xe2\x80\x99")
        in
        (antes && despues) || ir (i + 1)
  in
  n > 0 && ir 0

let palabras s =
  let s = String.lowercase_ascii s in
  let l = ref [] and b = Buffer.create 16 in
  let cerrar () =
    if Buffer.length b > 0 then (
      l := Buffer.contents b :: !l;
      Buffer.clear b)
  in
  String.iter (fun c -> if es_letra c then Buffer.add_char b c else cerrar ()) s;
  cerrar ();
  List.rev !l

let alguna ws l = List.exists (fun w -> List.mem w l) ws

(* Trozos de [s] separados por cualquiera de [seps]. *)
let partir seps s =
  let rec ir acc s =
    let primero =
      List.fold_left
        (fun mejor sep ->
          match (indice s sep ~desde:0, mejor) with
          | Some i, Some (j, _) when i >= j -> mejor
          | Some i, _ -> Some (i, sep)
          | None, _ -> mejor)
        None seps
    in
    match primero with
    | None -> List.rev (s :: acc)
    | Some (i, sep) ->
        let k = i + String.length sep in
        ir (String.sub s 0 i :: acc) (String.sub s k (String.length s - k))
  in
  ir [] s |> List.map String.trim |> List.filter (( <> ) "")

(* {1 Lectura} *)

let linea p campo =
  match indice p ("\n" ^ campo) ~desde:0 with
  | None -> None
  | Some i ->
      let a = i + 1 + String.length campo in
      let b = Option.value ~default:(String.length p) (indice p "\n" ~desde:a) in
      Some (String.trim (String.sub p a (b - a)))

let leer s =
  match indice s "<evidence>" ~desde:0 with
  | None -> None
  | Some i -> (
      let a = i + String.length "<evidence>" in
      let b = Option.value ~default:(String.length s) (indice s "</evidence>" ~desde:a) in
      let p = "\n" ^ String.sub s a (b - a) in
      match linea p "Empresa:" with
      | None | Some "" -> None
      | Some empresa ->
          let ubicaciones =
            match linea p "Ubicaciones vistas:" with None -> [] | Some u -> partir [ " · "; ";" ] u
          in
          let marca = "\nExtracto de una de sus ofertas:" in
          let extracto, hasta =
            match indice p marca ~desde:0 with
            | Some e ->
                let k = e + String.length marca in
                (String.trim (String.sub p k (String.length p - k)), e)
            | None -> ("", String.length p)
          in
          let ofertas =
            match indice p "\nOfertas suyas vistas:" ~desde:0 with
            | None -> []
            | Some o ->
                String.sub p o (hasta - o)
                |> String.split_on_char '\n'
                |> List.filter_map (fun l ->
                       let l = String.trim l in
                       if String.starts_with ~prefix:"- " l then Some (String.trim (String.sub l 2 (String.length l - 2)))
                       else None)
          in
          Some { empresa; ubicaciones; ofertas; extracto })

let texto e = String.lowercase_ascii (String.concat "\n" e.ofertas ^ "\n" ^ e.extracto)

(* {1 remotePolicy} *)

(* Una ubicación remota lo dice: «Remote - Spain», «Remote (Worldwide)»,
   «Flexible / Remote», «Worldwide», «Remoto - España». *)
let remotas = [ "remote"; "remoto"; "remota"; "worldwide"; "anywhere"; "teletrabajo" ]

(* Lo que, en la oferta, quita el remoto puro: una oficina a la que ir. *)
let hibridas =
  [ "hybrid"; "hybride"; "híbrido"; "híbrida"; "hibrido"; "hibrida"; "presencial"; "onsite"; "office";
    "offices"; "oficina"; "oficinas"; "büro"; "bureau"; "bureaux" ]

(* Las ubicaciones que da la propia oferta en una línea de cabecera
   («Headquarters: Berlin, Germany; Munich, Germany; Remote, Germany», en
   los portales que llaman así a la lista de ubicaciones; «Location: …»). *)
let cabeceras = [ "headquarters:"; "location:"; "locations:"; "ubicación:"; "ubicacion:" ]

let ubicaciones_del_extracto e =
  String.split_on_char '\n' e.extracto
  |> List.concat_map (fun l ->
         let l = String.trim (String.lowercase_ascii l) in
         match List.find_opt (fun c -> String.starts_with ~prefix:c l) cabeceras with
         | None -> []
         | Some c -> partir [ ";"; " · " ] (String.sub l (String.length c) (String.length l - String.length c)))

let politica e =
  let us = List.map palabras (e.ubicaciones @ ubicaciones_del_extracto e) in
  let t = palabras (texto e) in
  if e.ubicaciones = [] then []
  else if List.for_all (fun u -> alguna u remotas) us && not (alguna t hibridas) then
    [ ("remotePolicy", `String "remote") ]
  else if
    List.for_all (fun u -> contiene (String.lowercase_ascii (String.concat " " u)) "presencial") us
    && not (alguna t (remotas @ [ "hybrid"; "híbrido"; "híbrida"; "hibrido"; "hibrida" ]))
  then [ ("remotePolicy", `String "onsite") ]
  else []

(* {1 website} *)

(* La forma jurídica no es parte del nombre: «Smartly.io Solutions GmbH»,
   «Bertelsmann SE & Co. KGaA». *)
let formas =
  [ "gmbh"; "ag"; "se"; "kg"; "kgaa"; "co"; "inc"; "ltd"; "llc"; "plc"; "sl"; "sa"; "slu"; "sas"; "sarl";
    "srl"; "bv"; "nv"; "ab"; "as"; "oy"; "spa"; "limited"; "corp"; "corporation" ]

let compacto s =
  let b = Buffer.create 16 in
  String.iter (fun c -> match c with 'a' .. 'z' | '0' .. '9' -> Buffer.add_char b c | _ -> ()) s;
  Buffer.contents b

let nombre_compacto e =
  palabras e.empresa |> List.filter (fun w -> not (List.mem w formas)) |> String.concat "" |> compacto

(* Dominios de empleo, no de la empresa: «getyourguide.careers». *)
let tld_empleo = [ "careers"; "career"; "jobs"; "job" ]

let separa c = match c with ' ' | '\n' | '\t' | '(' | ')' | '<' | '>' | '"' | ',' | ';' | '[' | ']' | '|' -> true | _ -> false

let dominio token =
  let t = String.lowercase_ascii token in
  let quita p t = if String.starts_with ~prefix:p t then String.sub t (String.length p) (String.length t - String.length p) else t in
  let t = t |> quita "https://" |> quita "http://" |> quita "www." in
  let t = match String.index_opt t '/' with Some i -> String.sub t 0 i | None -> t in
  let rec sin_final t =
    let n = String.length t in
    if n > 0 && (match t.[n - 1] with '.' | ':' | '!' | '?' | '\'' -> true | _ -> false) then sin_final (String.sub t 0 (n - 1))
    else t
  in
  let t = sin_final t in
  let partes = String.split_on_char '.' t in
  let etiqueta p = p <> "" && String.for_all (fun c -> match c with 'a' .. 'z' | '0' .. '9' | '-' -> true | _ -> false) p in
  let tld = List.nth partes (List.length partes - 1) in
  if contiene token "@" || List.length partes < 2 || not (List.for_all etiqueta partes) then None
  else if String.length tld < 2 || not (String.for_all (fun c -> c >= 'a' && c <= 'z') tld) then None
  else if List.mem tld tld_empleo then None
  else Some t

let tokens s =
  let l = ref [] and b = Buffer.create 32 in
  let cerrar () =
    if Buffer.length b > 0 then (
      l := Buffer.contents b :: !l;
      Buffer.clear b)
  in
  String.iter (fun c -> if separa c then cerrar () else Buffer.add_char b c) s;
  cerrar ();
  List.rev !l

let web e =
  let nombre = nombre_compacto e in
  let empresa = String.lowercase_ascii e.empresa in
  let suyos =
    tokens (e.empresa ^ "\n" ^ String.concat "\n" e.ofertas ^ "\n" ^ e.extracto)
    |> List.filter_map dominio
    |> List.filter (fun d ->
           let etiqueta = List.hd (String.split_on_char '.' d) in
           String.length etiqueta >= 3
           && (tiene_palabra empresa d || (String.length nombre >= 3 && (compacto etiqueta = nombre || compacto d = nombre))))
    |> List.sort_uniq compare
  in
  match suyos with [ d ] -> [ ("website", `String d) ] | _ -> []

(* {1 hqCountry, hqCountryEn} *)

(* Una tabla pequeña: ciudades y países que se leen como sede. Cada entrada,
   el país en español y en inglés. *)
let alemania = ("Alemania", "Germany")
let espanya = ("España", "Spain")
let reino_unido = ("Reino Unido", "United Kingdom")
let francia = ("Francia", "France")
let paises_bajos = ("Países Bajos", "Netherlands")
let suiza = ("Suiza", "Switzerland")
let irlanda = ("Irlanda", "Ireland")
let eeuu = ("Estados Unidos", "United States")
let portugal = ("Portugal", "Portugal")
let italia = ("Italia", "Italy")
let belgica = ("Bélgica", "Belgium")
let austria = ("Austria", "Austria")
let suecia = ("Suecia", "Sweden")
let dinamarca = ("Dinamarca", "Denmark")
let finlandia = ("Finlandia", "Finland")
let polonia = ("Polonia", "Poland")
let chequia = ("República Checa", "Czech Republic")
let canada = ("Canadá", "Canada")

let lugares =
  [ ("berlin", alemania); ("munich", alemania); ("münchen", alemania); ("hamburg", alemania);
    ("frankfurt", alemania); ("cologne", alemania); ("köln", alemania); ("düsseldorf", alemania);
    ("stuttgart", alemania); ("germany", alemania); ("deutschland", alemania); ("alemania", alemania);
    ("madrid", espanya); ("barcelona", espanya); ("valencia", espanya); ("seville", espanya);
    ("sevilla", espanya); ("málaga", espanya); ("bilbao", espanya); ("spain", espanya); ("españa", espanya);
    ("london", reino_unido); ("manchester", reino_unido); ("edinburgh", reino_unido); ("bristol", reino_unido);
    ("cambridge", reino_unido); ("oxford", reino_unido); ("united kingdom", reino_unido); ("uk", reino_unido);
    ("reino unido", reino_unido); ("paris", francia); ("lyon", francia); ("france", francia);
    ("francia", francia); ("amsterdam", paises_bajos); ("rotterdam", paises_bajos); ("utrecht", paises_bajos);
    ("the netherlands", paises_bajos); ("netherlands", paises_bajos); ("países bajos", paises_bajos);
    ("zürich", suiza); ("zurich", suiza); ("geneva", suiza); ("genève", suiza); ("basel", suiza);
    ("switzerland", suiza); ("suiza", suiza); ("dublin", irlanda); ("ireland", irlanda); ("irlanda", irlanda);
    ("new york", eeuu); ("new york city", eeuu); ("san francisco", eeuu); ("boston", eeuu); ("seattle", eeuu);
    ("chicago", eeuu); ("austin", eeuu); ("los angeles", eeuu); ("palo alto", eeuu); ("united states", eeuu);
    ("usa", eeuu); ("estados unidos", eeuu); ("lisbon", portugal); ("lisboa", portugal); ("porto", portugal);
    ("portugal", portugal); ("milan", italia); ("rome", italia); ("italy", italia); ("italia", italia);
    ("brussels", belgica); ("belgium", belgica); ("vienna", austria); ("wien", austria); ("austria", austria);
    ("stockholm", suecia); ("sweden", suecia); ("copenhagen", dinamarca); ("denmark", dinamarca);
    ("helsinki", finlandia); ("finland", finlandia); ("warsaw", polonia); ("poland", polonia);
    ("prague", chequia); ("czech republic", chequia); ("czechia", chequia); ("toronto", canada);
    ("canada", canada) ]

let paises_en s = List.filter_map (fun (l, p) -> if tiene_palabra s l then Some p else None) lugares |> List.sort_uniq compare

(* La sede, dicha por la empresa en primera persona: «our Berlin HQ», «our
   headquarters on Zürich's Bahnhofstrasse», «headquartered in Amsterdam,
   we…», «nuestra sede en Madrid». Un «Headquarters: …» de cabecera de
   portal no vale: es la lista de ubicaciones de la oferta, no la sede (lo
   enseñaron JetBrains y Typeform); ni una sede en tercera persona, que puede
   ser de una filial («Headquartered in Nashville…, BMG» en una oferta de
   Bertelsmann). *)
let frase s i =
  (* La frase que contiene la posición [i]: de la anterior a la siguiente
     marca de fin. *)
  let fin c = c = '.' || c = '\n' || c = '!' || c = '?' in
  let rec atras j = if j <= 0 then 0 else if fin s.[j - 1] && (j >= String.length s || s.[j] = ' ' || s.[j] = '\n') then j else atras (j - 1) in
  let rec adelante j = if j >= String.length s then j else if fin s.[j] && (j + 1 >= String.length s || s.[j + 1] = ' ' || s.[j + 1] = '\n') then j else adelante (j + 1) in
  let a = atras i and b = adelante i in
  (String.sub s a (b - a), i - a)

let sede e =
  let t = String.lowercase_ascii e.extracto in
  let disparadores = [ "headquartered in"; "headquarters in"; "headquarters on"; "headquarters at"; "head office in"; " hq"; "nuestra sede" ] in
  let encontrados =
    List.concat_map
      (fun d ->
        let rec ir desde acc =
          match indice t d ~desde with
          | None -> acc
          | Some i ->
              let f, k = frase t i in
              let antes = String.sub f 0 k and despues = String.sub f k (String.length f - k) in
              let primera = tiene_palabra antes "our" || tiene_palabra antes "nuestra" in
              let candidatos =
                if d = " hq" then
                  (* «our Berlin HQ»: el lugar entre «our» y «hq». *)
                  match ultimo antes "our " with
                  | Some x -> paises_en (String.sub antes x (String.length antes - x))
                  | None -> []
                else
                  (* El lugar, justo detrás del disparador y antes de la
                     siguiente coma; la frase, en primera persona. *)
                  let tras = String.sub despues (String.length d) (String.length despues - String.length d) in
                  let corto = match partir [ ","; ";"; " with " ] tras with x :: _ -> x | [] -> "" in
                  let nosotros = primera || tiene_palabra despues "we" || tiene_palabra antes "we" || tiene_palabra antes "we're" in
                  if nosotros then paises_en corto else []
              in
              ir (i + 1) (candidatos @ acc)
        in
        ir 0 [])
      disparadores
    |> List.sort_uniq compare
  in
  match encontrados with
  | [ (es, en) ] -> [ ("hqCountry", `String es); ("hqCountryEn", `String en) ]
  | _ -> []

(* {1 sizeBucket} *)

(* Lo que cuenta personas de la empresa. «people» y «personas» solo tras
   «we're», «we are», «somos»: «300 million people» son sus usuarios. *)
let plantilla =
  [ "employees"; "empleados"; "colleagues"; "professionals"; "profesionales"; "mitarbeiter"; "mitarbeitende";
    "mitarbeiterinnen"; "beschäftigte"; "trabajadores"; "collaborateurs"; "salariés"; "staff"; "employés" ]

let gente = [ "people"; "personas"; "personnes" ]
let nosotros = [ "we're"; "we’re"; "are"; "somos"; "sommes" ]

(* «1200+», «~20», «56.000», «2,000», «2k»: (n, con «+»). Un rango («3-5»)
   no es una plantilla. *)
let numero tok =
  let t = String.lowercase_ascii tok in
  let quita_pref t =
    List.fold_left
      (fun t p -> if String.starts_with ~prefix:p t then String.sub t (String.length p) (String.length t - String.length p) else t)
      t [ "~"; "≈"; "("; "+" ]
  in
  let t = quita_pref t in
  if t = "" || contiene t "-" || contiene t "–" || not (match t.[0] with '0' .. '9' -> true | _ -> false) then None
  else
    let mas = contiene t "+" in
    let k = String.ends_with ~suffix:"k" t || String.ends_with ~suffix:"k+" t in
    let grupos = String.split_on_char '.' (String.concat "." (String.split_on_char ',' t)) in
    let solo_digitos g = String.concat "" (List.map (String.make 1) (List.filter (fun c -> c >= '0' && c <= '9') (List.of_seq (String.to_seq g)))) in
    let gs = List.map solo_digitos grupos in
    let miles = match gs with _ :: resto -> List.for_all (fun g -> String.length g = 3) resto | [] -> false in
    if List.exists (( = ) "") gs || (List.length gs > 1 && not miles) then None
    else
      match int_of_string_opt (String.concat "" gs) with
      | None -> None
      | Some n -> Some ((if k then n * 1000 else n), mas)

let franja (n, mas) =
  let n = if mas then n + 1 else n in
  if n <= 0 then None
  else if n <= 10 then Some "1-10"
  else if n <= 50 then Some "11-50"
  else if n <= 200 then Some "51-200"
  else if n <= 500 then Some "201-500"
  else if n <= 1000 then Some "501-1000"
  else Some "1000+"

let limpia w =
  let w = String.lowercase_ascii w in
  let n = String.length w in
  let rec fin j = if j > 0 && (match w.[j - 1] with '.' | ',' | ';' | ':' | ')' | '!' | '?' -> true | _ -> false) then fin (j - 1) else j in
  String.sub w 0 (fin n)

let tamanyo e =
  let ws = String.split_on_char ' ' (String.concat " " (String.split_on_char '\n' e.extracto)) |> List.filter (( <> ) "") |> Array.of_list in
  let n = Array.length ws in
  let franjas = ref [] in
  for i = 0 to n - 2 do
    match numero ws.(i) with
    | None -> ()
    | Some x ->
        let siguiente = limpia ws.(i + 1) in
        let previo j = if i - j >= 0 then limpia ws.(i - j) else "" in
        let de_plantilla =
          List.mem siguiente plantilla
          || (siguiente = "team" && i + 2 < n && limpia ws.(i + 2) = "members")
          || (List.mem siguiente gente && (List.mem (previo 1) nosotros || List.mem (previo 2) nosotros))
        in
        if de_plantilla then Option.iter (fun f -> franjas := f :: !franjas) (franja x)
  done;
  match List.sort_uniq compare !franjas with [ f ] -> [ ("sizeBucket", `String f) ] | _ -> []

let campos e = List.concat [ politica e; web e; sede e; tamanyo e ]

let cristal =
  Cristal.cristal "ficha-empresa" Cristal.texto (fun s ->
      match leer s with
      | None -> Error "fuera de dominio: no hay <evidence> con Empresa:"
      | Some e -> (
          match campos e with
          | [] -> Error "la evidencia no sostiene ningún campo"
          | cs -> Ok (Yojson.Safe.to_string (`Assoc cs))))
