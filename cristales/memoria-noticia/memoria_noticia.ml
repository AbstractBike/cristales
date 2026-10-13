(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: de qué va una noticia de hardware, para quien sigue la memoria
   RAM. Ver SEMILLA.md.

   La entrada es la de grafica-noticia (líneas «Título: …», «Resumen: …» y
   «Fuente: …»; sin «Título:», todo es el título), y se lee con su [partes].
   El tema se decide por el título: memoria si habla de DRAM, de módulos o de
   quien los hace; almacenamiento si de SSD, NAND o discos; otro hardware si
   la memoria es la de un aparato que es el protagonista («Surface Laptop con
   128 GB de RAM»). El resumen suma generaciones, formatos, fabricantes y
   modelos cuando el título ya va de memoria. *)

open Memoria_modelo
module T = Memoria_modelo.Texto

(* --- palabras (plegadas) ----------------------------------------------------- *)

(* Lo que dice memoria sin dudas. *)
let memoria =
  [ "dram"; "drams"; "ram"; "rams"; "arbeitsspeicher"; "ramspeicher"; "memoria ram"; "memorias ram"; "memory module"; "memory modules";
    "memory kit"; "memory kits"; "ram kit"; "ram kits"; "memory chip"; "memory chips"; "memory maker"; "memory makers"; "memory price";
    "memory prices"; "memory pricing"; "memory shortage"; "memory market"; "memory business"; "memory industry"; "memory supply";
    "memory crunch"; "memory squeeze"; "memory sale"; "memory spot"; "memory contract"; "dimm"; "dimms"; "udimm"; "rdimm"; "sodimm";
    "cudimm"; "mrdimm"; "hudimm"; "camm"; "camm2"; "lpcamm2"; "socamm"; "socamm2"; "cxl"; "mram"; "rampocalyse"; "rampocalypse";
    "ramageddon"; "speicherknappheit"; "speicherkrise"; "speicherpreise"; "speicherchips"; "speichermangel"; "ram preise"; "ram krise";
    "optane dimm" ]

(* Lo que dice memoria, o no: «memory», «Speicher», «memoria». *)
let memoria_debil = [ "memory"; "memories"; "speicher"; "memoria"; "memorias"; "memorie"; "memoire" ]

(* Las empresas de memoria: su nombre basta si la noticia habla de memoria a medias. *)
let empresas_memoria =
  [ "cxmt"; "nanya"; "winbond"; "micron"; "sk hynix"; "hynix"; "skhynix"; "g skill"; "gskill"; "rambus"; "montage"; "netlist"; "everspin";
    "piecemakers"; "kingston"; "crucial"; "teamgroup"; "team group"; "patriot"; "apacer"; "kingbank" ]

let almacenamiento =
  [ "ssd"; "ssds"; "nand"; "flash"; "nvme"; "hdd"; "hdds"; "disco duro"; "discos duros"; "festplatte"; "festplatten"; "hard drive";
    "hard drives"; "nas"; "storage"; "almacenamiento"; "speicherplatz"; "tape"; "kioxia"; "solidigm"; "sandisk";
    "ymtc"; "seagate"; "western digital"; "tarjeta de memoria"; "speicherkarte"; "scheda di memoria"; "cartao de memoria"; "usb drive" ]

(* Lo que, con memoria, dice que el protagonista es un aparato: la RAM de un portátil, la VRAM de una gráfica. *)
let aparato =
  [ "laptop"; "laptops"; "notebook"; "notebooks"; "portatil"; "portatiles"; "macbook"; "mac studio"; "mac mini"; "imac"; "surface";
    "smartphone"; "iphone"; "galaxy"; "pixel"; "phone"; "tablet"; "ipad"; "console"; "ps5"; "xbox"; "switch"; "steam deck"; "steam machine";
    "mini pc"; "expertcenter"; "nuc"; "workstation"; "gpu"; "gpus"; "graphics card"; "grafikkarte"; "rtx"; "radeon"; "geforce"; "rdna"; "accelerator"; "chip";
    "maia"; "crescent island"; "gorgon"; "strix halo"; "raspberry"; "gaming pc"; "prebuilt"; "handheld"; "vram"; "gddr6"; "gddr6x"; "gddr7" ]

(* Lo que hace de la noticia de un aparato una de memoria: su precio, su escasez. *)
let mercado_memoria =
  [ "price"; "prices"; "pricing"; "shortage"; "shortages"; "squeeze"; "crunch"; "supply"; "costs"; "cost"; "hike"; "hikes"; "crisis";
    "precio"; "precios"; "escasez"; "preis"; "preise"; "knappheit"; "teurer" ]

(* «RAM usage», «in-memory», la memoria de un chatbot: no es hardware. *)
let fuera =
  [ "ram usage"; "memory usage"; "uso de ram"; "consumo de ram"; "ram verbrauch"; "in memory digital"; "in memory database"; "in memory computing"; "memory feature"; "chatgpt"; "chatbot";
    "siri"; "memory leak"; "memory safety"; "memory safe"; "dns cache"; "lego"; "ddr lok"; "onedrive"; "icloud"; "google drive"; "dropbox";
    "cloud storage" ]

let hardware =
  [ "cpu"; "cpus"; "gpu"; "gpus"; "processor"; "procesador"; "prozessor"; "chip"; "chips"; "chipmaker"; "semiconductor"; "semiconductors";
    "tsmc"; "foundry"; "intel"; "amd"; "nvidia"; "qualcomm"; "arm"; "motherboard"; "placa base"; "mainboard"; "laptop"; "notebook"; "pc";
    "pcs"; "monitor"; "router"; "rtx"; "radeon"; "geforce"; "ryzen"; "xeon"; "epyc"; "server"; "servers"; "data center"; "rack"; "racks";
    "smartphone"; "console"; "ps5"; "xbox"; "switch 2"; "mini pc"; "handheld"; "keyboard"; "mouse"; "headset"; "cooler"; "psu"; "wafer";
    "wafers"; "fab"; "fabs"; "gddr7"; "vram"; "grafikkarte"; "grafikkarten"; "tastatur"; "maus"; "gehause"; "lufter"; "netzteil"; "tarjeta grafica";
    "graficas"; "procesadores"; "portatil"; "placa"; "chipsatz"; "socket"; "am5"; "lga1700"; "lga1851"; "steam frame"; "steam machine";
    "raspberry pi"; "nas"; "wifi"; "wi fi"; "oled"; "display"; "displays" ]

let tipos =
  [ ("analisis",
     [ "review"; "reviewed"; "tested"; "testing"; "test"; "tests"; "benchmark"; "benchmarks"; "analisis"; "a prueba"; "probamos"; "im test";
       "hands on"; "shows"; "re examining"; "examining"; "works better"; "guide"; "how to"; "que hacer"; "explained"; "tuning guide";
       "early testing"; "comparativa"; "vergleich"; "faq"; "deep dive" ]);
    ("estandar", [ "jedec"; "standard"; "specification"; "spec"; "estandar"; "norma"; "spezifikation"; "standardisiert" ]);
    ("precio",
     [ "price"; "prices"; "pricing"; "priced"; "cost"; "costs"; "deal"; "deals"; "discount"; "sale"; "cheapest"; "cheaper"; "expensive";
       "off"; "cheap"; "precio"; "precios"; "preis"; "preise"; "teurer"; "gunstiger"; "spot"; "contract prices"; "price hike"; "hikes"; "abnormally";
       "oferta"; "ofertas"; "rebaja"; "angebot"; "euro"; "euros"; "dollar"; "free"; "savings"; "barato"; "barata"; "coste"; "costo"; "for only" ]);
    ("fabrica",
     [ "fab"; "fabs"; "plant"; "factory"; "wafer"; "wafers"; "mass production"; "production"; "risk production"; "production capacity"; "wafer capacity"; "capacity expansion"; "memory capacity"; "dram capacity"; "breaks ground";
       "strike"; "fabrica"; "werk"; "fertigung"; "produktion"; "yield"; "euv"; "process tech"; "12nm"; "1c"; "1 gamma"; "node"; "nodes";
       "manufacturing"; "produccion"; "toxic gas"; "fire" ]);
    ("mercado",
     [ "shortage"; "shortages"; "supply"; "demand"; "revenue"; "earnings"; "profit"; "profits"; "margin"; "results"; "ipo"; "market";
       "share"; "lawsuit"; "settlement"; "settle"; "sues"; "court"; "ban"; "blacklist"; "blacklisting"; "lobbying"; "investment"; "invest";
       "spending"; "capex"; "billion"; "billions"; "expansion"; "union"; "unions"; "workers"; "bonus"; "bonuses"; "acquisition"; "acquire";
       "agreement"; "agreements"; "shipments"; "forecast"; "outlook"; "report"; "escasez"; "mercado"; "knappheit"; "markt"; "umsatz";
       "gewinn"; "crisis"; "crunch"; "squeeze"; "rampocalyse"; "rampocalypse"; "ramageddon"; "steal"; "stolen"; "patent"; "adr"; "class action";
       "manipulation"; "chairman"; "ceo"; "boss"; "speicherknappheit"; "speicherkrise"; "gold rush"; "bonanza" ]);
    ("lanzamiento",
     [ "launch"; "launches"; "launched"; "announce"; "announces"; "announced"; "unveil"; "unveils"; "unveiled"; "debut"; "debuts"; "introduce";
       "introduces"; "reveal"; "reveals"; "tease"; "teases"; "lists"; "drops new"; "available"; "ships"; "shipping"; "sampling"; "brings";
       "lanza"; "presenta"; "anuncia"; "llega"; "llegan"; "vorgestellt"; "kundigt"; "stellt"; "bringt"; "erscheint"; "new"; "nuevo"; "nueva";
       "neue"; "neuer"; "neues"; "roadmap" ]) ]

(* Las generaciones que nombra: DDR5, LPDDR5X, GDDR7, HBM4E. *)
let generaciones ws =
  Array.to_list ws
  |> List.filter_map (fun w ->
         match T.trozos w with
         | [ ("ddr" | "lpddr" | "gddr"); d ] when String.length d = 1 -> Some w
         | [ ("lpddr" | "gddr"); d; "x" ] when String.length d = 1 -> Some w
         | [ "hbm" ] -> Some "hbm"
         | [ "hbm"; d ] when String.length d = 1 -> Some w
         | [ "hbm"; d; "e" ] when String.length d = 1 -> Some w
         | [ ("zhbm" | "ihbm" | "nvhbm") ] -> Some "hbm"
         | _ -> None)
  |> sin_repetir

let formatos ws =
  List.filter_map
    (fun (frases, f) -> if T.hay ws frases then Some f else None)
    [ ([ "udimm"; "udimms" ], "udimm"); ([ "sodimm"; "so dimm"; "sodimms" ], "sodimm"); ([ "rdimm"; "rdimms" ], "rdimm");
      ([ "lrdimm"; "lrdimms" ], "lrdimm"); ([ "mrdimm"; "mrdimms" ], "mrdimm"); ([ "cudimm"; "cudimms" ], "cudimm");
      ([ "csodimm"; "csodimms" ], "csodimm"); ([ "camm"; "camm2"; "lpcamm2"; "lpcamm" ], "camm2"); ([ "socamm"; "socamm2" ], "socamm");
      ([ "hudimm"; "hudimms" ], "hudimm"); ([ "cxl" ], "cxl") ]

(* Lo que aún no está en las tiendas: generaciones y formatos por venir. *)
let por_venir = [ "ddr6"; "lpddr6"; "hbm4e"; "hbm5"; "gddr7x"; "gddr8"; "socamm2"; "hudimm"; "zhbm"; "ihbm"; "nvhbm"; "xbm"; "lpddr6x" ]

let segmentos =
  [ ("hbm-ia", [ "hbm"; "hbm2"; "hbm2e"; "hbm3"; "hbm3e"; "hbm4"; "hbm4e"; "hbm5"; "zhbm"; "ihbm"; "nvhbm"; "socamm"; "socamm2"; "ai memory"; "kv cache"; "ai accelerator"; "inference"; "rubin" ]);
    ("servidor", [ "server"; "servers"; "data center"; "data centers"; "datacenter"; "hyperscaler"; "hyperscalers"; "rdimm"; "mrdimm"; "cxl"; "enterprise"; "epyc"; "xeon"; "ai servers"; "ai server"; "rechenzentrum"; "servidor"; "servidores" ]);
    ("movil", [ "lpddr4"; "lpddr4x"; "lpddr5"; "lpddr5x"; "lpddr6"; "smartphone"; "smartphones"; "phone"; "phones"; "iphone"; "android"; "mobile"; "movil"; "tablet"; "tablets" ]);
    ("consumo", [ "gaming"; "desktop"; "pc"; "pcs"; "kit"; "kits"; "udimm"; "sodimm"; "cudimm"; "laptop"; "laptops"; "notebook"; "consumer"; "consumers"; "overclocking"; "xmp"; "expo"; "diy"; "ryzen"; "am5"; "vengeance"; "trident"; "fury"; "ripjaws"; "t create"; "novakey"; "gaming rigs"; "rigs"; "ram deals"; "camm2"; "lpcamm2" ]) ]

let marcas_memoria =
  [ "samsung"; "skhynix"; "micron"; "crucial"; "kingston"; "corsair"; "gskill"; "teamgroup"; "patriot"; "adata"; "lexar"; "pny";
    "siliconpower"; "apacer"; "transcend"; "cxmt"; "nanya"; "goodram"; "kingbank"; "klevv"; "netac" ]

(* Las de la noticia que no están en las marcas de memoria-modelo. *)
let otras_marcas = [ ("winbond", "winbond"); ("rambus", "rambus"); ("montage", "montage"); ("netlist", "netlist"); ("everspin", "everspin") ]

(* --- decidir ------------------------------------------------------------------------ *)

let tema ws =
  let pos frases = T.posicion ws frases in
  let gens = List.filter (fun g -> not (String.length g >= 4 && String.sub g 0 4 = "gddr")) (generaciones ws) in
  let p_gen = if gens = [] then None else pos gens in
  let primera = List.fold_left (fun acc p -> match (acc, p) with Some a, Some b -> Some (min a b) | None, b -> b | a, None -> a) None in
  let fuerte = T.hay ws memoria || gens <> [] in
  let debil = T.hay ws memoria_debil in
  let empresa = T.hay ws empresas_memoria in
  let p_mem = primera [ pos memoria; p_gen; pos memoria_debil ] in
  let p_aparato = pos aparato in
  (* El precio o la escasez de la memoria: la palabra junto a la de la memoria («precios de la RAM», «RAM
     prices», «DDR5 shortage»), no la del aparato («a pesar de su alto precio, la Surface Laptop … con 128 GB
     de RAM»). *)
  let n = Array.length ws in
  let de_memoria i = List.exists (T.encaja ws i) memoria || List.exists (T.encaja ws i) memoria_debil || List.mem ws.(i) gens in
  let mercado_de_la_memoria =
    List.exists
      (fun i -> List.exists (T.encaja ws i) mercado_memoria && List.exists (fun d -> i + d >= 0 && i + d < n && de_memoria (i + d)) [ -3; -2; -1; 1; 2; 3 ])
      (List.init n Fun.id)
  in
  (* El aparato va antes que la memoria, o justo detrás de ella («DDR5 gaming PC»), y la noticia no es del
     precio de la memoria: va del aparato. *)
  let de_aparato =
    (match (p_aparato, p_mem) with Some a, Some m -> a < m || a <= m + 2 | Some _, None -> true | None, _ -> false)
    && not mercado_de_la_memoria
  in
  let de_disco = T.hay ws almacenamiento in
  let solo_speicher = debil && (not fuerte) && T.hay ws [ "speicher" ] && not (T.hay ws [ "memory"; "memories"; "memoria"; "memorias" ]) in
  if T.hay ws fuera then Some "otro"
  else if (fuerte || debil) && de_aparato && not empresa then Some "hardware"
  else if fuerte then Some "memoria"
  else if solo_speicher && not empresa then
    (* «Speicher» solo: el de un aparato, el de un disco o no se sabe. *)
    if p_aparato <> None || T.hay ws hardware then Some "hardware" else if de_disco then Some "almacenamiento" else None
  else if debil && (empresa || not de_disco) then Some "memoria"
  else if de_disco then Some "almacenamiento"
  else if empresa && p_aparato = None then Some "memoria"
  else if T.hay ws hardware then Some "hardware"
  else Some "otro"

let segmento ws =
  let es k = T.hay ws (List.assoc k segmentos) in
  if es "hbm-ia" then "hbm-ia"
  else
    match (es "servidor", es "consumo", es "movil") with
    | true, false, _ -> "servidor"
    | false, true, _ -> "consumo"
    | false, false, true -> "movil"
    | _ -> "?"

let aplicar entrada : (string, string) result =
  let n = Grafica_noticia.partes entrada in
  let t = n.titulo in
  if String.trim t = "" then Error "sin título"
  else
    let ws = T.palabras t in
    match tema ws with
    | None -> Error "no sé si va de memoria o de almacenamiento"
    | Some tema ->
      let dentro = tema = "memoria" in
      let todo = T.palabras (t ^ "\n" ^ n.resumen) in
      let tipo =
        if dentro then Option.value ~default:"otro" (List.find_map (fun (k, frases) -> if T.hay ws frases then Some k else None) tipos)
        else "otro"
      in
      let lt = leer t and lr = leer (t ^ "\n" ^ n.resumen) in
      let marcas =
        List.filter (fun m -> List.mem m marcas_memoria) lr.marcas
        @ List.filter_map (fun (w, m) -> if T.hay todo [ w ] then Some m else None) otras_marcas
      in
      let gens = generaciones todo in
      (* Las líneas que son palabras corrientes («Impact», «Elite», «Shadow»), solo con una marca de memoria:
         «the impact of soaring memory prices» no es la Fury Impact. *)
      let corrientes = [ "Impact"; "Elite"; "Shadow"; "Delta"; "Ares"; "Predator"; "Lancer"; "Redline"; "Game Pro"; "Fury" ] in
      let lineas = List.filter (fun l -> marcas <> [] || not (List.mem l corrientes)) lr.lineas in
      let modelos = sin_repetir (List.map (fun ((m : Catalogo.modulo), _) -> m.pn) lr.modulos @ lineas) in
      let nuevos = sin_repetir (List.filter (fun w -> List.mem w por_venir) (Array.to_list todo) @ lt.desconocidos) in
      let lista xs = `List (List.map (fun s -> `String s) (if dentro then xs else [])) in
      Ok
        (Yojson.Safe.to_string
           (`Assoc
              [ ("tema", `String tema);
                ("tipo", `String tipo);
                ("segmento", `String (if dentro then segmento todo else "?"));
                ("fabricantes", lista marcas);
                ("generaciones", lista gens);
                ("formatos", lista (formatos todo));
                ("modelos", lista modelos);
                ("nuevos", lista nuevos) ]))

let cristal = Cristal.cristal "memoria-noticia" aplicar
