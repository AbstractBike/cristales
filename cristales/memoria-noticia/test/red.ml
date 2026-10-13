(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de memoria-noticia: titulares reales de la semilla (RSS del
   2026-10-13) con su tema, su tipo, su segmento, lo que nombran y lo nuevo. *)

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let lista j k = match j with `Assoc l -> (match List.assoc_opt k l with Some (`List xs) -> List.map (function `String s -> s | _ -> "?") xs | _ -> []) | _ -> []
let campo j k = match j with `Assoc l -> (match List.assoc_opt k l with Some (`String s) -> s | _ -> "?") | _ -> "?"

let comprueba ?(resumen = "") ?segmento ?generaciones ?fabricantes ?nuevos titulo (tema, tipo) =
  match Memoria_noticia.aplicar ("Título: " ^ titulo ^ if resumen = "" then "" else "\nResumen: " ^ resumen) with
  | Error m -> falla "%S: defecto «%s»" titulo m
  | Ok s ->
    let j = Yojson.Safe.from_string s in
    let mal = ref [] in
    if campo j "tema" <> tema then mal := ("tema " ^ campo j "tema") :: !mal;
    if campo j "tipo" <> tipo then mal := ("tipo " ^ campo j "tipo") :: !mal;
    Option.iter (fun x -> if campo j "segmento" <> x then mal := ("segmento " ^ campo j "segmento") :: !mal) segmento;
    let l k = Option.iter (fun x -> if lista j k <> x then mal := (k ^ " " ^ String.concat "," (lista j k)) :: !mal) in
    l "generaciones" generaciones;
    l "fabricantes" fabricantes;
    l "nuevos" nuevos;
    if !mal <> [] then falla "%S: %s" titulo (String.concat "; " !mal)

let () =
  (* precios y mercado de la DRAM *)
  comprueba "After jumping 2,200% over the last twelve months, DDR4 spot prices fall 5%, the first decline in nearly a year — DDR5 pricing sees some relief in China channel market"
    ~generaciones:[ "ddr4"; "ddr5" ] ("memoria", "precio");
  comprueba "Memory chip boss admits RAM prices are 'abnormally high'" ("memoria", "precio");
  comprueba "AI Server Demand Sustains Memory Contract Price Increases in 4Q26, While Consumer-Side Pressure Persists, Says TrendForce" ("memoria", "precio");
  comprueba "Corsair's 32GB Vengeance kits are the cheapest DDR5 RAM on the market right now" ~segmento:"consumo" ~fabricantes:[ "corsair" ] ("memoria", "precio");
  comprueba "DDR5 laptop memory prices surge 6X in 12 months" ~segmento:"consumo" ("memoria", "precio");
  comprueba "Micron projects tightening RAM shortages through 2028 as it generates record profit" ~fabricantes:[ "micron" ] ("memoria", "mercado");
  comprueba "SK Hynix raises a record $26.5 billion in historic U.S. IPO" ~fabricantes:[ "skhynix" ] ("memoria", "mercado");
  comprueba "Memory will consume 30% of hyperscaler data center spending this year, a 4X increase over 2023" ~segmento:"servidor" ("memoria", "mercado");
  comprueba "Memory gold rush bonanza makes billions for Micron" ("memoria", "mercado");
  comprueba "Micron commits $500 million to GlobalWafers' Texas wafer plant as it raises U.S. spending to $250 billion" ("memoria", "fabrica");
  comprueba "G.Skill wins PC enthusiast as 'customer for life' by simply honoring its warranty replacement policy" ("memoria", "otro");
  (* fábricas, lanzamientos, estándares, análisis *)
  comprueba "China's CXMT hits 12nm-class DRAM milestone" ~fabricantes:[ "cxmt" ] ("memoria", "fabrica");
  comprueba "SK hynix breaks ground on the first HBM plant in the US, bringing key AI component production to the States" ~segmento:"hbm-ia" ("memoria", "fabrica");
  comprueba "China's CXMT beats Western chipmakers to announcement of LPDDR6 mass production" ~segmento:"movil" ~nuevos:[ "lpddr6" ] ("memoria", "fabrica");
  comprueba "Micron announces 512GB DDR5-9200 memory modules with 16W power draw" ("memoria", "lanzamiento");
  comprueba "Samsung teases new HBM5 with twice the performance of HBM4E" ~segmento:"hbm-ia" ~generaciones:[ "hbm5"; "hbm4e" ] ~nuevos:[ "hbm5"; "hbm4e" ]
    ("memoria", "lanzamiento");
  comprueba "New HUDIMM memory specification debuts with goal of slashing DDR5 prices during RAM shortages" ~nuevos:[ "hudimm" ] ("memoria", "estandar");
  comprueba "G.Skill Trident Z5 NeoX RGB DDR5-6000 C30 2x16GB Review — EXPO ULL memory kit to max out your Ryzen" ~segmento:"consumo" ("memoria", "analisis");
  comprueba "Re-examining the DDR4 gaming gap with Intel’s LGA 1700 CPUs in mid-2026" ("memoria", "analisis");
  comprueba "Qué hacer si Windows detecta menos RAM de la que tienes instalada" ("memoria", "analisis");
  comprueba "RAMageddon: Wer hat in den letzten 12 Monaten noch RAM gekauft?" ("memoria", "mercado");
  comprueba "Marvell Structera X 3406 and 3506 CXL 3.2 Memory Expanders" ~segmento:"servidor" ("memoria", "otro");
  comprueba "768GB of cheap Intel Optane DIMM memory sticks used to run 1-trillion-parameter LLM on a system with a single GPU" ("memoria", "precio");
  (* la memoria de un aparato: hardware *)
  comprueba "Microsoft Surface Laptop mit Nvidia RTX Spark: High-End-Modell mit 128 GiB RAM bereits ausverkauft" ("hardware", "otro");
  comprueba "Intel GPU D-Series Packs 480GB LPDDR5X and 1.3 PFLOPS FP8 into a 350W PCIe Card" ("hardware", "otro");
  comprueba "Microsoft Maia 300 Puts 288GB of HBM4 at 18TB/s on an N2P Chiplet and 96 Accelerators in a 167kW Rack" ("hardware", "otro");
  comprueba "AMD Rumored To Launch RDNA 5 In Second Half Of 2027; Also Quashes Rumors Of Next-Gen Using 4 GB GDDR7 Memory" ("hardware", "otro");
  comprueba "192 GB Speicher: AMD stellt Gorgon Halo ins Schaufenster" ("hardware", "otro");
  comprueba "Neue NVIDIA-Gerüchte: RTX 5090 geht EOL und mögliche RTX 5080 mit 24 GB VRAM" ("hardware", "otro");
  (* almacenamiento y otras cosas *)
  comprueba "YMTC breaks into the top three NAND makers for the first time as AI servers swallow 48% of all flash" ("almacenamiento", "otro");
  comprueba "Seagate CCO says storage price hikes are ‘the new normal’" ("almacenamiento", "otro");
  comprueba "SK Hynix considering US Solidigm fab" ("almacenamiento", "otro");
  comprueba "Microsoft 365 Family: OneDrive-Speicher sinkt von 6 auf 2 TB" ("otro", "otro");
  comprueba "Spotifast lets you enjoy Spotify tracks while lowering RAM usage by 5x or more" ("otro", "otro");
  comprueba "Scaleout Software’s in-memory digital twins for generative AI" ("otro", "otro");
  comprueba "11.109 Teile, über einen Meter lang: Lego-Rivale Bluebrixx zeigt berühmte DDR‑Lok" ("otro", "otro");
  comprueba "GTA 6: Rockstar gibt neue Einblicke in Jason, Lucia und Leonida" ("otro", "otro")

(* La revisión del 2026-10-13: el precio de un aparato no es el de su memoria;
   la memoria que adjetiva un aparato («DDR5 gaming PC»), tampoco; la capacidad
   de un equipo no es la de una fábrica; «Impact» sin marca no es un modelo. *)
let () =
  comprueba "A pesar de su alto precio, la Surface Laptop Ultra de Microsoft con 128 GB de RAM se ha agotado en unos días" ("hardware", "otro");
  comprueba "$899 gets you a fully fledged DDR5 gaming PC in Best Buy's Labor Day sales — save $300 off the iBuypower Slate PC" ("hardware", "otro");
  comprueba "ASUS ExpertCenter PN55 Review: Ryzen AI 7 450, Dual 2.5GbE, and 64GB of DDR5 in 0.57 Liters" ("hardware", "otro");
  comprueba "32GB dethrones 16GB as top RAM capacity in gaming rigs despite memory shortage" ("memoria", "mercado");
  comprueba "CXMT close to matching Micron's memory capacity in 2026, research claims" ("memoria", "fabrica");
  comprueba "Get 32GB of RAM for only $241 in this 3-item gaming combo from Newegg" ("memoria", "precio");
  comprueba "DDR5 laptop memory prices surge 6X in 12 months" ("memoria", "precio");
  (match Memoria_noticia.aplicar "Título: MSI brings DDR4 back to gaming laptops amidst DRAM crisis\nResumen: to reduce the impact of soaring memory prices" with
   | Ok s -> if lista (Yojson.Safe.from_string s) "modelos" <> [] then falla "«the impact of»: %s" s
   | Error m -> falla "MSI DDR4: %s" m);
  match Memoria_noticia.aplicar "Título: Just $284.99 for 32GB of Team T-Create Classic DDR5-6000 RAM is the cheapest going right now" with
  | Ok s -> if lista (Yojson.Safe.from_string s) "modelos" <> [ "T-Create" ] then falla "T-Create: %s" s
  | Error m -> falla "T-Create: %s" m

(* Fuera de la memoria, listas vacías y segmento «?»; sin «Título:», el titular entero; «Speicher» solo, defecto. *)
let () =
  (match Memoria_noticia.aplicar "Título: Seagate CCO says storage price hikes are ‘the new normal’" with
   | Ok s ->
     let j = Yojson.Safe.from_string s in
     if campo j "segmento" <> "?" || lista j "fabricantes" <> [] || lista j "generaciones" <> [] then falla "almacenamiento con listas: %s" s
   | Error m -> falla "almacenamiento: %s" m);
  (match Memoria_noticia.aplicar "Micron announces 512GB DDR5-9200 memory modules" with Ok _ -> () | Error m -> falla "sin «Título:»: %s" m);
  match Memoria_noticia.aplicar "Título: Mehr Speicher für alle" with Error _ -> () | Ok s -> falla "«Speicher» solo debía ser defecto: %s" s

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de memoria-noticia\n" !fallos;
    exit 1)
