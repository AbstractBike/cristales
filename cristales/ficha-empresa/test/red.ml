(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* La red de ficha-empresa: los casos de la semilla, uno por regla (la
   evidencia, recortada a lo que decide), y los invariantes. *)

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let evidencia ?(ubicaciones = "Berlin") ?(ofertas = [ "Software Engineer" ]) empresa extracto =
  Printf.sprintf
    "<evidence>\nEmpresa: %s\nUbicaciones vistas: %s\nOfertas suyas vistas:\n%s\n\nExtracto de una de sus ofertas: %s\n</evidence>"
    empresa ubicaciones
    (String.concat "\n" (List.map (( ^ ) "- ") ofertas))
    extracto

let campos m =
  match Ficha_empresa.cristal.aplicar m with
  | Ok s -> ( match Yojson.Safe.from_string s with `Assoc l -> l | _ -> [])
  | Error _ -> []

let vale m k = List.assoc_opt k (campos m)
let es m k v = vale m k = Some (`String v)
let calla m k = vale m k = None

let () =
  (* Fuera de dominio. *)
  comprueba "sin evidence es defecto" (Result.is_error (Ficha_empresa.cristal.aplicar "hola"));
  comprueba "sin empresa es defecto"
    (Result.is_error (Ficha_empresa.cristal.aplicar "<evidence>\nUbicaciones vistas: Remote\n</evidence>"));
  comprueba "sin nada que sostener es defecto"
    (Result.is_error (Ficha_empresa.cristal.aplicar (evidencia "Kalepa" "We build underwriting software.")));
  (* Lectura. *)
  (match
     Ficha_empresa.leer
       (evidencia ~ubicaciones:"Remote · Kyiv, UA" ~ofertas:[ "Uno"; "Dos" ] "S-PRO" "Primera.\nSegunda.")
   with
  | Some e ->
      comprueba "empresa" (e.empresa = "S-PRO");
      comprueba "ubicaciones por «·»" (e.ubicaciones = [ "Remote"; "Kyiv, UA" ]);
      comprueba "ofertas" (e.ofertas = [ "Uno"; "Dos" ]);
      comprueba "extracto hasta </evidence>" (e.extracto = "Primera.\nSegunda.")
  | None -> comprueba "lee la evidencia" false);
  (* remotePolicy: remoto (Flosum, Remote (Worldwide), Remote - Spain…). *)
  List.iter
    (fun u ->
      comprueba ("«" ^ u ^ "» es remote")
        (es (evidencia ~ubicaciones:u "Flosum" "Tipo: full-time · Área: sales") "remotePolicy" "remote"))
    [ "Remote - Germany"; "Remote (Worldwide)"; "Remote - USA, Remote - Canada"; "Flexible / Remote"; "Worldwide";
      "Remote, Spain · Remote, Serbia"; "Remoto - España" ];
  (* Con algo que no es remoto, o una oficina en la oferta, lo decide el LLM. *)
  List.iter
    (fun (u, x) ->
      comprueba ("«" ^ u ^ "» con «" ^ x ^ "» no es remote") (calla (evidencia ~ubicaciones:u "Ejemplo" x) "remotePolicy"))
    [ ("Remote · Zagreb, HR · Rome, IT", "x"); ("Remote - Amsterdam, Netherlands · Poznań, Poland", "x");
      ("Remote - Europe", "You are welcome to work at our head office in Amsterdam, or remotely.");
      ("Remote (Spain)", "Reporting to the CPTO Office."); ("Remote - Paris, France", "Hybrid: 2 days in the office.");
      ("Remote - Germany", "Tipo: Full-Time\nHeadquarters: Berlin, Germany; Munich, Germany; Remote, Germany");
      ("Berlin, Germany", "x"); ("London, United Kingdom", "x") ];
  (* Presencial (los anuncios de Málaga y de Suiza). *)
  List.iter
    (fun u ->
      comprueba ("«" ^ u ^ "» es onsite")
        (es (evidencia ~ubicaciones:u "Grupo Ñam Ñam" "Cocinero/a · Contrato indefinido") "remotePolicy" "onsite"))
    [ "Málaga (Presencial)"; "Churriana, Málaga (Presencial)"; "Switzerland (Presencial)" ];
  comprueba "presencial con teletrabajo no es onsite"
    (calla (evidencia ~ubicaciones:"Málaga (Presencial)" "Ejemplo" "Dos días de teletrabajo.") "remotePolicy");
  comprueba "solo una de dos presencial no es onsite"
    (calla (evidencia ~ubicaciones:"Málaga (Presencial) · Madrid" "Ejemplo" "x") "remotePolicy");
  (* website: el dominio que es el nombre de la empresa. *)
  let web empresa x = vale (evidencia ~ubicaciones:"Remote" empresa x) "website" in
  comprueba "Learn more at www.intellectsoft.net/"
    (web "Intellectsoft" "Learn more at www.intellectsoft.net/" = Some (`String "intellectsoft.net"));
  comprueba "el nombre es el dominio (Smartly.io Solutions GmbH)"
    (web "Smartly.io Solutions GmbH" "We build ad tech." = Some (`String "smartly.io"));
  comprueba "nombre de dos palabras (Sanctuary Computer)"
    (web "Sanctuary Computer" "URL: https://sanctuary.computer" = Some (`String "sanctuary.computer"));
  comprueba "saas.group en el texto" (web "Saas.group" "Our Central Marketing Team at saas.group." = Some (`String "saas.group"));
  comprueba "un dominio de empleo no es la web (getyourguide.careers)"
    (web "GetYourGuide" "Head to getyourguide.careers to take the first step." = None);
  comprueba "un correo no es la web (perzukunft.de)"
    (web "PerZukunft Arbeitsvermittlung GmbH & Co. KG" "per Email wedding.service@perzukunft.de" = None);
  comprueba "un dominio de otro no es la web" (web "Patient Reach 360" "We deploy on Fly.io." = None);
  comprueba "los productos de la empresa no son su web"
    (web "Ejemplo" "Our portfolio includes CryptoRunner.com and InvestoRunner.com." = None);
  comprueba "una etiqueta de una letra es ambigua (A.Team)" (web "A.Team" "A.Team is an invite-only network." = None);
  comprueba "sin dominio en la evidencia, nada (no adivina flosum.com)" (web "Flosum" "Tipo: full-time" = None);
  (* hqCountry: la sede en primera persona. *)
  let sede x =
    let m = evidencia ~ubicaciones:"Remote" "Ejemplo" x in
    (vale m "hqCountry", vale m "hqCountryEn")
  in
  let es_sede x (es, en) = sede x = (Some (`String es), Some (`String en)) in
  let sin_sede x = sede x = (None, None) in
  comprueba "our Berlin HQ"
    (es_sede "Find your next role at our Berlin HQ or one of our local offices around the globe, from New York to Bangkok."
       ("Alemania", "Germany"));
  comprueba "headquartered in Amsterdam, we"
    (es_sede "Listed on Nasdaq and headquartered in Amsterdam, we have a global footprint." ("Países Bajos", "Netherlands"));
  comprueba "our headquarters on Zürich’s Bahnhofstrasse"
    (es_sede "From our headquarters on Zürich’s Bahnhofstrasse, we’re expanding globally across Europe and the US."
       ("Suiza", "Switzerland"));
  comprueba "Headquarters: de portal no es la sede (JetBrains)"
    (sin_sede "Headquarters: Berlin, Germany; Munich, Germany; Remote, Germany");
  comprueba "una sede en tercera persona puede ser de una filial (BMG en Bertelsmann)"
    (sin_sede "Headquartered in Boston with 18 offices globally, BMG is privately held.");
  comprueba "dos países de sede, nada (Inner Circle Agency)"
    (sin_sede "We are an agency headquartered in Germany and Spain, a boutique management firm.");
  comprueba "un lugar fuera de la tabla, nada" (sin_sede "Our headquarters in Nashville are growing.");
  (* sizeBucket: una plantilla dicha. *)
  let tam x = vale (evidencia ~ubicaciones:"Remote" "Ejemplo" x) "sizeBucket" in
  List.iter
    (fun (x, f) -> comprueba ("«" ^ x ^ "» es " ^ f) (tam x = Some (`String f)))
    [ ("global distributed collaboration, with 1200+ colleagues in 75+ countries", "1000+");
      ("Join a diverse team of approx. 2000 professionals across four continents", "1000+");
      ("con cerca de 56.000 empleados en casi 30 países", "1000+");
      ("We're ~20 people with 7 of us on the engineering team", "11-50");
      ("a fully remote team of nearly 400 colleagues spanning 50+ countries", "201-500");
      ("We have 1000+ employees", "1000+"); ("Somos 45 personas", "11-50") ];
  List.iter
    (fun x -> comprueba ("«" ^ x ^ "» no es una plantilla") (tam x = None))
    [ "You will lead a team of 3-5 engineers"; "Our platform inspires over 300 million people in +55 countries";
      "closing deals at €50K–150K ACV"; "We have 30 employees in Madrid and 600 employees overall";
      "Since 2020, builders have earned more than $200M" ];
  (* Invariantes: solo campos de la ficha; nunca los de criterio; valores de
     sus enumeraciones; el país en inglés va con el español. *)
  let todos =
    [ evidencia ~ubicaciones:"Remote" "Intellectsoft" "Learn more at www.intellectsoft.net/. Our Berlin HQ. 1200+ colleagues.";
      evidencia ~ubicaciones:"Málaga (Presencial)" "Ejemplo" "Somos 12 personas.";
      evidencia ~ubicaciones:"Remote - Spain" "Saas.group" "Headquartered in Amsterdam, we are nearly 400 colleagues." ]
  in
  let ficha =
    [ "confidence"; "hqCity"; "hqCountry"; "hqCountryEn"; "redFlags"; "remotePolicy"; "sector"; "sectorEn"; "sizeBucket";
      "summary"; "summaryEn"; "techStack"; "website" ]
  in
  let criterio = [ "confidence"; "hqCity"; "redFlags"; "sector"; "sectorEn"; "summary"; "summaryEn"; "techStack" ] in
  List.iter
    (fun m ->
      let cs = campos m in
      comprueba "da algo" (cs <> []);
      comprueba "solo campos de la ficha" (List.for_all (fun (k, _) -> List.mem k ficha) cs);
      comprueba "nunca los de criterio" (List.for_all (fun k -> not (List.mem_assoc k cs)) criterio);
      comprueba "remotePolicy del enum"
        (match List.assoc_opt "remotePolicy" cs with
        | None | Some (`String ("remote" | "hybrid" | "onsite" | "unknown")) -> true
        | Some _ -> false);
      comprueba "sizeBucket del enum"
        (match List.assoc_opt "sizeBucket" cs with
        | None | Some (`String ("1-10" | "11-50" | "51-200" | "201-500" | "501-1000" | "1000+")) -> true
        | Some _ -> false);
      comprueba "hqCountry y hqCountryEn, juntos" (List.mem_assoc "hqCountry" cs = List.mem_assoc "hqCountryEn" cs);
      comprueba "website sin protocolo ni www"
        (match List.assoc_opt "website" cs with
        | None -> true
        | Some (`String w) ->
            (not (String.contains w '/')) && (not (String.starts_with ~prefix:"www." w)) && String.contains w '.'
        | Some _ -> false))
    todos;
  if !fallos > 0 then exit 1
