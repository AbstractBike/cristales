(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de grafica-anuncio: los anuncios reales de SEMILLA.md
   (Wallapop con su categoría, Kleinanzeigen en Grafikkarten; 2026-10-12) y lo
   que son; el estado que dicen título y descripción; y los defectos. *)

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let entrada ?(categoria = "") ?(descripcion = "") titulo =
  "Título: " ^ titulo
  ^ (if categoria = "" then "" else "\nCategoría: " ^ categoria)
  ^ if descripcion = "" then "" else "\nDescripción: " ^ descripcion

let campo json k = match json with `Assoc l -> (match List.assoc_opt k l with Some (`String s) -> s | Some (`Int i) -> string_of_int i | Some `Null | None -> "-" | Some _ -> "?") | _ -> "?"

(* tipo, modelo («-» si no), y si se da, la memoria *)
let comprueba ?categoria ?descripcion titulo (tipo, modelo) =
  match Grafica_anuncio.aplicar (entrada ?categoria ?descripcion titulo) with
  | Error m -> falla "%S: defecto «%s», se esperaba %s %s" titulo m tipo modelo
  | Ok s ->
    let j = Yojson.Safe.from_string s in
    if campo j "tipo" <> tipo || campo j "modelo" <> modelo then
      falla "%S: %s %s, se esperaba %s %s" titulo (campo j "tipo") (campo j "modelo") tipo modelo

let comp = "Computer components & parts"
let gaming_pc = "Gaming desktops"
let desktops = "Desktop computers"
let laptops = "Laptops"
let ka = "Grafikkarten"

let wallapop =
  [ ("ASUS Dual GeForce RTX 3060 ti V2 OC Edition", comp, ("grafica", "rtx-3060-ti"));
    ("ASUS GTX 1660 Super Strix", comp, ("grafica", "gtx-1660-super"));
    ("ASUS ROG Strix GTX 1080 Ti 11GB VRAM", comp, ("grafica", "gtx-1080-ti"));
    ("Asus ROG Strix LC RTX 4090 OC 24GB", comp, ("grafica", "rtx-4090"));
    ("Asus TUF Gaming RTX 4090 24GB GDDR6X", comp, ("grafica", "rtx-4090"));
    ("ASUS TUF RTX 3080 OC 10GB GDDR6X", comp, ("grafica", "rtx-3080"));
    ("Gigabyte Radeon RX 6800 XT 16GB GDDR6 Gaming OC", comp, ("grafica", "rx-6800-xt"));
    ("Gigabyte RTX 2060 Super Windforce OC 8G", comp, ("grafica", "rtx-2060-super"));
    ("MSI RTX 4090 Gaming X Trio 24GB GDDR6X", comp, ("grafica", "rtx-4090"));
    ("Nvidia RTX 3060 12GB KFA2", comp, ("grafica", "rtx-3060"));
    ("Placa Gráfica PowerColor RX 5700 XT 8GB", comp, ("grafica", "rx-5700-xt"));
    ("RTX 3060TI Gigabyte Eagle 8GB Tarjeta Grafica", comp, ("grafica", "rtx-3060-ti"));
    ("RTX 4070 Ti", comp, ("grafica", "rtx-4070-ti"));
    ("RTX 5060 Ti 16GB Gigabyte Gaming OC", comp, ("grafica", "rtx-5060-ti"));
    ("Sparkle Intel Arc A770 16GB GDDR6 OC", comp, ("grafica", "arc-a770"));
    ("Tarjeta Gráfica ASUS Dual Radeon RX 580 8GB", comp, ("grafica", "rx-580"));
    ("Tarjeta Gráfica Asus R9 270X 4GB DDR5", comp, ("grafica", "r9-270x"));
    ("Tarjeta Gráfica ELSA Rx580 2048sp averiada", comp, ("grafica", "rx-580"));
    ("Tarjeta Gráfica MSI GTX 1080 Gaming x 8GB", gaming_pc, ("grafica", "gtx-1080"));
    ("EVGA GeForce RTX 2070 Tarjeta Gráfica", "Gaming components", ("grafica", "rtx-2070"));
    ("Zotac RTX 3070 Ti Trinity OC", comp, ("grafica", "rtx-3070-ti"));
    ("Tarjeta Gráfica Zotac RTX 3080 AMP Holo 10GB", comp, ("grafica", "rtx-3080"));
    (* lo que no es una gráfica suelta *)
    ("Alienware M18 R1 RTX 4090", laptops, ("portatil", "-"));
    ("ASUS ROG STRIG G16 | I9 14900HX - RTX 4070", "Gaming laptops", ("portatil", "-"));
    ("ASUS ROG Strix G16 | i9-13980HX + RTX 4070", "Gaming laptops", ("portatil", "-"));
    ("MSI Vector GP76", laptops, ("portatil", "-"));
    ("PORTATIL GAMING HP VICTUS I7 13GEN 16GB 4070", laptops, ("portatil", "-"));
    ("Lenovo IdeaPad 330 15,6\" I7, 16GB RAM, GTX 1050", laptops, ("portatil", "-"));
    ("Ordenador Gaming RTX 3080 10GB", gaming_pc, ("pc", "-"));
    ("PC Gaming Ryzen 7 5800X3D + RTX 3080 10GB", gaming_pc, ("pc", "-"));
    ("PC 5060TI 16GB+5800X/32GB RAM+1TB M.2", gaming_pc, ("pc", "-"));
    ("Pack Setup Gaming Pro RGB RTX3080 5900X Razer+Asus", gaming_pc, ("pc", "-"));
    ("HYPERX OMEN 45L - Ultra 7 270K plus + 3080 MSI", desktops, ("pc", "-"));
    ("PC Completo Gigabyte GeForce RTX", gaming_pc, ("pc", "-"));
    ("TORRE i5 9400F 8Gb GRAFICA 16Gb RAM", desktops, ("pc", "-"));
    ("Gaming PC intel i5 GTX1660 SUPER SSD NVMe RAM 16gb", desktops, ("pc", "-"));
    ("PC Gamer RTX 1660 + i5 7500", gaming_pc, ("pc", "-"));
    ("Backplate original MSI RTX 4090 Trio", comp, ("pieza", "-"));
    ("Disipador Gráfica Zotac 3 Ventiladores", comp, ("pieza", "-"));
    ("Soporte Low Profile para Nvidia Quadro", comp, ("pieza", "-"));
    ("Minisforum DEG1 eGPU OCuLink, sin usar", comp, ("pieza", "-"));
    ("Razer Core con Gráfica GTX 1060g1 gaming 3g", comp, ("pieza", "-"));
    ("Pack de 4 Tarjetas Gráficas vintage", comp, ("lote", "-"));
    ("Procesador i7 8700 (1151)", comp, ("componente", "-"));
    ("Fuente de Alimentación NOX AT-500P12P 500W", comp, ("componente", "-"));
    ("Monitor Samsung S22D390H 21.5\" 16:9", "Monitors", ("componente", "-"));
    ("Ventilador Noctua NF-A9 PWM", comp, ("pieza", "-"));
    ("Kit RAM 32G (2x16) Corsair Vengeance DDR4", comp, ("componente", "-"));
    ("Tarjeta Gráfica Gigabyte GTX 260 OC", comp, ("antigua", "-"));
    ("Tarjeta Gráfica GeForce FX 5200 128MB DDR", comp, ("antigua", "-"));
    ("Gráfica AMD HD 6750M 512MB iMac 21,5 2011", comp, ("antigua", "-")) ]

let kleinanzeigen =
  [ ("Gigabyte RTX 3080 10GB Aorus Xtreme mit OVP ►Händler◄", ("grafica", "rtx-3080"));
    ("MSI GeForce RTX 3080 Suprim X 10GB (inkl. OVP & Zubehör)", ("grafica", "rtx-3080"));
    ("Asus TUF Gaming RTX 3080 OC mit Alphacool Wasserkühlung", ("grafica", "rtx-3080"));
    ("Sapphire Nitro+ RX 6800 XT + Alphacool Eiswolf 2 AIO - DEFEKT", ("grafica", "rx-6800-xt"));
    ("Sapphire Radeon RX 580 Nitro+ 8GB in OVP – Inkl. Bykski Fullcover", ("grafica", "rx-580"));
    ("GTX 1080Ti Wassergekühlt", ("grafica", "gtx-1080-ti"));
    ("INNO3D GeForce RTX 3080 X3 12GB Grafikkarte in OVP", ("grafica", "rtx-3080"));
    ("MSI GeForce RTX 3060 Ti Ventus 2x 8GB LHR - OVP", ("grafica", "rtx-3060-ti"));
    ("Gigabyte RTX 4070 Ti SUPER Gaming OC 16GB", ("grafica", "rtx-4070-ti-super"));
    ("AMD Radeon™ RX 7900 GRE Neu!", ("grafica", "rx-7900-gre"));
    ("AMD Radeon RX 7900 XT 20 GB – Verkauf oder Tausch", ("grafica", "rx-7900-xt"));
    ("Gigabyte RTX 4070 TI Aorus Master Tausch Radeon RX7900/9070XT", ("grafica", "rtx-4070-ti"));
    ("Rx 6800xt msi x trio tausch gegen nvidia oder verkauf", ("grafica", "rx-6800-xt"));
    ("RX-580P8D V8.0 GTS XXX ED 8GB OC+ 1386M D5 BP 3xDP HDMI DVI", ("grafica", "rx-580"));
    ("AMD Radeon RX 580 8 GB – funktionsfähig", ("grafica", "rx-580"));
    ("✨SUCHE: NVIDIA GeForce RTX 2080 3050 2070 2060 GTX 1080 1070 1660 1650 1060 Super Ti MSI ASUS", ("busca", "-"));
    ("[SUCHE] NVIDIA RTX 3080 TI 12GB Founders Edition", ("busca", "-"));
    ("EK Waterblocks Backplate für RTX 3080/3090", ("pieza", "-"));
    ("EKWB Wasserblock für MSI Gaming Trio RTX 3080", ("pieza", "-"));
    ("Alphacool GPX | EVGA XC3 RTX 3080 | Eisblock NEU", ("pieza", "-"));
    ("Alphacool RX 6800 XT / 6900 XT Wasserkühler RGB + Backplate", ("pieza", "-"));
    ("Gaming PC GeForce RTX 3060 OC - AMD Ryzen 5 3600 6-Core Processor", ("pc", "-"));
    ("Gaming PC Ryzen 9 9950X / RX 7900 X", ("pc", "-"));
    ("Gaming Setup: PC I5-10400F, GTX1080TI, 32GB,+Monitor+mouse+gamepa", ("pc", "-")) ]

let () =
  List.iter (fun (t, categoria, e) -> comprueba ~categoria t e) wallapop;
  List.iter (fun (t, e) -> comprueba ~categoria:ka t e) kleinanzeigen

(* Lo que no sabe: defectos, y con la descripción sí. *)
let () =
  let defecto ?descripcion t prefijo =
    match Grafica_anuncio.aplicar (entrada ~categoria:comp ?descripcion t) with
    | Error m when String.starts_with ~prefix:prefijo m -> ()
    | Error m -> falla "%S: defecto «%s», se esperaba «%s…»" t m prefijo
    | Ok s -> falla "%S: %s, se esperaba defecto «%s…»" t s prefijo
  in
  defecto "Tarjeta Gráfica Gigabyte GeForce" "gráfica sin modelo";
  defecto "Rx 6800 bzw 6800xt" "varios modelos: rx-6800, rx-6800-xt";
  defecto "RTX 4060 Super 8GB nueva" "modelo desconocido: rtx 4060 super";
  comprueba ~categoria:comp ~descripcion:"Vendo mi RTX 3060 Gaming OC 12GB, funciona perfecta." "Tarjeta Gráfica Gigabyte GeForce" ("grafica", "rtx-3060")

(* El estado y lo que dice: averiada, nueva, como nueva, minería, garantía, factura, caja. *)
let () =
  let estado ?(descripcion = "") t esperado =
    match Grafica_anuncio.aplicar (entrada ~categoria:comp ~descripcion t) with
    | Ok s ->
      let j = Yojson.Safe.from_string s in
      List.iter (fun (k, v) -> if campo j k <> v then falla "%S: %s=%s, se esperaba %s" t k (campo j k) v) esperado
    | Error m -> falla "%S: defecto %s" t m
  in
  estado "Tarjeta Gráfica ELSA Rx580 2048sp averiada" [ ("estado", "averiada") ];
  estado "MSI GeForce RTX 3080 (leichter Defekt)" [ ("estado", "averiada") ];
  estado "INNO3D GeForce RTX 3060 Ti Twin X2 OC 8GB – Defekt / Bastler" [ ("estado", "averiada") ];
  estado "RTX 4070 Super precintada" [ ("estado", "nueva") ];
  estado "AMD Radeon™ RX 7900 GRE Neu!" [ ("estado", "nueva") ];
  estado "RTX 3070 como nueva" [ ("estado", "usada") ];
  estado "RTX 4070 KFA2 EX GAMER 12GB in OVP wie Neu" [ ("estado", "usada"); ("caja", "si") ];
  estado "RX 6800 XT" ~descripcion:"Nunca minada, solo juegos. Con factura y garantía hasta 2026. Sin caja." 
    [ ("mineria", "no"); ("factura", "si"); ("garantia", "si"); ("caja", "no"); ("estado", "usada") ];
  estado "RTX 3080 de minería" ~descripcion:"Ha estado en un rig de minado, sin garantía." [ ("mineria", "si"); ("garantia", "no") ];
  estado "RTX 3060 Ti" ~descripcion:"Sin ninguna avería, funciona perfecta" [ ("estado", "usada") ];
  estado "MSI RTX 3080 Gaming X Trio 12GB" [ ("vram", "12"); ("anyo", "2020"); ("rendimiento", "50"); ("fabricante", "nvidia") ];
  estado "AMD Radeon RX 7900 XT 20 GB – Verkauf oder Tausch" [ ("cambio", "si") ]

(* La entrada sin «Título:» es un título (lo que manda un agente por MCP). *)
let () =
  match Grafica_anuncio.aplicar "Zotac RTX 3070 Ti Trinity OC" with
  | Ok s when String.length s > 0 -> ()
  | _ -> falla "sin «Título:» debía leerse como título"

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de grafica-anuncio\n" !fallos;
    exit 1)
