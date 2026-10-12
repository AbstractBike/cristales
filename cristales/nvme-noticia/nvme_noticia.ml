(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: de qué va una noticia de hardware, para quien sigue los SSD y el
   almacenamiento. Ver SEMILLA.md.

   La entrada es la de grafica-noticia (líneas «Título: …», «Resumen: …» y
   «Fuente: …»; sin «Título:», todo es el título), y se lee con su [partes].
   Se decide por el título; el resumen solo suma modelos y marcas cuando el
   título ya va de almacenamiento. *)

open Nvme_modelo
module G = Grafica_modelo.Texto

(* --- palabras (plegadas) ------------------------------------------------- *)

let ssd =
  [ "ssd"; "ssds"; "nvme"; "nand"; "flash"; "3d nand"; "qlc"; "tlc"; "plc"; "slc"; "solid state"; "m 2"; "e1 s"; "e1 l"; "e3 s";
    "u 2"; "u 3"; "optane"; "festkorperlaufwerk"; "almacenamiento flash"; "pcie 5 0 ssd"; "ssd controller"; "controladora ssd" ]

let almacenamiento =
  [ "hdd"; "hdds"; "disco duro"; "discos duros"; "festplatte"; "festplatten"; "hard drive"; "hard drives"; "hard disk"; "disk drive";
    "disk drives"; "nas"; "storage"; "almacenamiento"; "speicherlosung"; "tape"; "object storage"; "raid"; "nearline"; "read write head";
    "read write heads"; "lto" ]

(* Lo que no es de discos aunque diga «storage»: la nube, la memoria de los PCs y de la IA. *)
let fuera = [ "onedrive"; "icloud"; "google drive"; "dropbox"; "cloud storage"; "microsoft 365"; "android"; "iphone"; "galaxy s" ]
let memoria = [ "hbm"; "hbm3e"; "hbm4"; "hbm4e"; "dram"; "ddr5"; "ddr4"; "gddr7"; "lpddr5"; "memory"; "ram"; "mram" ]

(* Las empresas que solo hacen flash o controladoras: su nombre basta. *)
let solo_flash = [ "kioxia"; "solidigm"; "sandisk"; "phison"; "silicon motion"; "ymtc"; "dapustor"; "maxio"; "innogrit"; "biwin" ]

let enterprise =
  [ "enterprise"; "data center"; "datacenter"; "data centers"; "hyperscale"; "hyperscaler"; "server"; "servers"; "e1 s"; "e1 l"; "e3 s";
    "u 2"; "u 3"; "dwpd"; "rack"; "kv cache"; "ai data"; "ai inference"; "hpc"; "supercomputer"; "raid"; "cluster"; "storage array";
    "all flash array"; "nearline"; "rechenzentrum" ]

let consumo = [ "gaming"; "ps5"; "consumer"; "desktop"; "pc"; "prime day"; "deal"; "heatsink"; "m 2"; "laptop"; "portatil"; "steam deck"; "handheld" ]

let tipos =
  [ ("firmware", [ "firmware"; "fw update"; "firmware update"; "actualizacion de firmware" ]);
    ("analisis", [ "review"; "reviewed"; "tested"; "benchmark"; "benchmarks"; "analisis"; "a prueba"; "probamos"; "im test"; "test"; "hands on"; "podcast" ]);
    ("rumor", [ "rumor"; "rumors"; "rumour"; "rumored"; "reportedly"; "leak"; "leaks"; "leaked"; "allegedly"; "expected"; "spotted";
                "filtra"; "filtrado"; "rumorea"; "llegaria"; "lanzaria"; "habria"; "tendria"; "seria"; "soll"; "sollen"; "angeblich";
                "considering"; "could"; "might"; "likely"; "geruecht"; "gerucht" ]);
    ("precio", [ "price"; "prices"; "pricing"; "precio"; "precios"; "preis"; "preise"; "deal"; "deals"; "discount"; "off"; "oferta";
                 "ofertas"; "rebaja"; "cheaper"; "barato"; "barata"; "angebot"; "teurer"; "gunstiger"; "contract prices"; "coste"; "cost";
                 "costs"; "subida"; "sube"; "suben" ]);
    ("mercado", [ "shortage"; "shortages"; "supply"; "acquire"; "acquires"; "acquisition"; "buys"; "merger"; "earnings"; "revenue";
                  "profit"; "billions"; "ipo"; "listing"; "fab"; "capacity"; "market"; "settle"; "lawsuit"; "patent"; "invest";
                  "investment"; "spending"; "tracker"; "escasez"; "mercado"; "produccion"; "production"; "eol"; "discontinued" ]);
    ("lanzamiento", [ "launch"; "launches"; "launched"; "available"; "availability"; "now shipping"; "ships"; "shipping"; "sampling";
                      "release"; "releases"; "released"; "lanza"; "a la venta"; "disponible"; "llega"; "llegan"; "erscheint"; "startet";
                      "verfugbar"; "brings" ]);
    ("anuncio", [ "announce"; "announces"; "announced"; "unveil"; "unveils"; "unveiled"; "introduces"; "reveals"; "debuts"; "anuncia";
                  "presenta"; "desvela"; "vorgestellt"; "kundigt"; "enthullt"; "pr"; "adds"; "expands" ]) ]

let tema t (l : lectura) =
  let es_ssd = l.modelos <> [] || Texto.posicion t ssd <> None || Texto.posicion t solo_flash <> None in
  let es_alm = Texto.posicion t almacenamiento <> None in
  if Texto.posicion t fuera <> None then Some "otro"
  else if es_ssd then Some "ssd"
  else if es_alm && Texto.posicion t memoria <> None then None
  else if es_alm then Some "almacenamiento"
  else Some "otro"

let segmento t (l : lectura) =
  let e = Texto.posicion t enterprise <> None || List.exists (fun s -> s.modelo.Catalogo.segmento = Catalogo.Enterprise) l.modelos in
  let c = Texto.posicion t consumo <> None || List.exists (fun s -> s.modelo.Catalogo.segmento = Catalogo.Consumo) l.modelos in
  match (e, c) with true, false -> "enterprise" | false, true -> "consumo" | _ -> "?"

let marcas_de_discos =
  [ "samsung"; "wd"; "crucial"; "micron"; "kingston"; "skhynix"; "solidigm"; "intel"; "lexar"; "corsair"; "seagate"; "sabrent"; "kioxia";
    "adata"; "teamgroup"; "patriot"; "pny"; "transcend"; "phison"; "ymtc"; "biwin"; "goodram"; "siliconpower"; "netac"; "fikwot" ]

let aplicar entrada : (string, string) result =
  let n = Grafica_noticia.partes entrada in
  let t = n.titulo in
  if String.trim t = "" then Error "sin título"
  else
    let lt = leer t in
    match tema t lt with
    | None -> Error "no sé si va de almacenamiento"
    | Some tema ->
      let dentro = tema <> "otro" in
      let tipo =
        if dentro then Option.value ~default:"otro" (List.find_map (fun (k, ws) -> if Texto.posicion t ws <> None then Some k else None) tipos)
        else "otro"
      in
      let lr = leer (t ^ "\n" ^ n.resumen) in
      let marcas = List.filter (fun m -> List.mem m marcas_de_discos) (Texto.marcas (t ^ "\n" ^ n.resumen)) in
      let lista xs = `List (List.map (fun s -> `String s) (if dentro then xs else [])) in
      let modelos = List.sort_uniq compare (List.map (fun s -> s.modelo.Catalogo.clave) lr.modelos) in
      Ok
        (Yojson.Safe.to_string
           (`Assoc
              [ ("tema", `String tema);
                ("tipo", `String tipo);
                ("segmento", `String (if dentro then segmento t lt else "?"));
                ("fabricantes", lista marcas);
                ("modelos", lista modelos);
                ("nuevos", lista lt.desconocidos) ]))

let cristal = Cristal.cristal "nvme-noticia" aplicar
