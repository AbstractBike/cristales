(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* La red de oferta-trabajo: un caso por regla y los invariantes. Las
   ofertas son de mentira, con la forma del mensaje de la extracción. *)

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let mensaje ?(ubicacion = "Berlin") titulo descripcion =
  Printf.sprintf
    "Extract structured job information from the following job posting:\n\n<posting>\nURL: https://example.com/1\nTitle: %s\nCompany: Ejemplo\nLocation: %s\n\nDescription:\n%s\n</posting>"
    titulo ubicacion descripcion

let campos m =
  match Oferta_trabajo.cristal.aplicar m with
  | Ok s -> ( match Yojson.Safe.from_string s with `Assoc l -> l | _ -> [])
  | Error _ -> []

let vale m k = List.assoc_opt k (campos m)
let da m k = Option.is_some (vale m k)

let () =
  (* Fuera de dominio. *)
  comprueba "sin posting es defecto" (Result.is_error (Oferta_trabajo.cristal.aplicar "hola"));
  (* Lectura. *)
  (match Oferta_trabajo.leer (mensaje ~ubicacion:"Remote" "Data Engineer" "Uno.\nDos.") with
  | Some o ->
      comprueba "título" (o.titulo = "Data Engineer");
      comprueba "ubicación" (o.ubicacion = "Remote");
      comprueba "descripción hasta el final" (String.trim o.descripcion = "Uno.\nDos.")
  | None -> comprueba "lee el posting" false);
  (* Salario. *)
  let sin = mensaje "Data Engineer" "We build pipelines in OCaml." in
  comprueba "sin dinero, salario null"
    (List.for_all (fun k -> vale sin k = Some `Null) [ "salaryMin"; "salaryMax"; "salaryCurrency"; "salaryPeriod" ]);
  List.iter
    (fun (que, d) -> comprueba ("con " ^ que ^ ", el salario es del LLM") (not (da (mensaje "Data Engineer" d) "salaryMin")))
    [ ("€", "Bis 60.000 € im Jahr."); ("£", "£45,000"); ("salary", "Competitive salary."); ("60k", "60k-70k");
      ("Gehalt", "Attraktives Gehalt."); ("løn", "God løn og pension."); ("EUR", "55000 EUR") ];
  (* Años de experiencia. *)
  comprueba "sin años, yoe null" (vale sin "yoeMin" = Some `Null && vale sin "yoeMax" = Some `Null);
  List.iter
    (fun d -> comprueba ("con «" ^ d ^ "», los años son del LLM") (not (da (mensaje "Data Engineer" d) "yoeMin")))
    [ "5+ years of experience"; "3 Jahre Berufserfahrung"; "2 años de experiencia"; "minimum 4 år" ];
  (* Easy Apply. *)
  comprueba "sin easy apply, false" (vale sin "isEasyApply" = Some (`Bool false));
  comprueba "con easy apply, true"
    (vale (mensaje "Data Engineer" "Use Easy Apply below.") "isEasyApply" = Some (`Bool true));
  (* Seniority por el título. *)
  List.iter
    (fun (t, s) ->
      comprueba ("seniority de «" ^ t ^ "»")
        (vale (mensaje t "x") "seniority" = Option.map (fun s -> `String s) s))
    [ ("Senior Backend Engineer", Some "senior"); ("Sr. Data Analyst", Some "senior");
      ("Principal Engineer", Some "principal"); ("Senior Staff Software Engineer", Some "principal");
      ("Team Lead Platform", Some "lead"); ("Director of Sales", Some "lead"); ("Head of Product", Some "lead");
      ("Junior Developer", Some "junior"); ("Werkstudent Marketing", Some "entry"); ("Software Intern", Some "entry");
      ("Mid/Senior Gameplay Programmer", None); ("Software Engineer", None); ("Product Manager", None);
      ("Staff Engineer", None) ];
  (* Modalidad. *)
  comprueba "sin remoto ni híbrido, onsite" (vale sin "workMode" = Some (`String "onsite"));
  List.iter
    (fun d -> comprueba ("con «" ^ d ^ "», la modalidad es del LLM") (not (da (mensaje "Data Engineer" d) "workMode")))
    [ "Fully remote."; "Hybrid, 2 days in office."; "Home office möglich."; "Flexible working hours.";
      "Mobiles Arbeiten."; "Mulighed for hjemmearbejde."; "Work from home on Fridays." ];
  comprueba "Remote en la ubicación cuenta"
    (not (da (mensaje ~ubicacion:"Remote, Europe" "Data Engineer" "x") "workMode"));
  (* Invariantes: solo campos de la extracción, nunca los de criterio, y
     valores de sus enumeraciones. *)
  let todos =
    [ sin; mensaje "Senior Staff Engineer" "Easy Apply. 60k. Hybrid. 5 years.";
      mensaje "Werkstudent" "Deutschkenntnisse erforderlich." ]
  in
  let extraccion =
    [ "salaryMin"; "salaryMax"; "salaryCurrency"; "salaryPeriod"; "workMode"; "seniority"; "yoeMin";
      "yoeMax"; "hardSkills"; "languages"; "contractType"; "isAgency"; "isEasyApply"; "companySize" ]
  in
  List.iter
    (fun m ->
      let cs = campos m in
      comprueba "solo campos de la extracción" (List.for_all (fun (k, _) -> List.mem k extraccion) cs);
      comprueba "nunca los de criterio"
        (List.for_all
           (fun k -> not (List.mem_assoc k cs))
           [ "hardSkills"; "languages"; "contractType"; "isAgency"; "companySize" ]);
      comprueba "seniority del enum"
        (match List.assoc_opt "seniority" cs with
        | None -> true
        | Some (`String s) -> List.mem s [ "entry"; "junior"; "mid"; "senior"; "lead"; "principal" ]
        | Some _ -> false);
      comprueba "workMode del enum"
        (match List.assoc_opt "workMode" cs with
        | None | Some (`String ("remote" | "hybrid" | "onsite")) -> true
        | Some _ -> false))
    todos;
  if !fallos > 0 then exit 1
