(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de memoria-anuncio: anuncios reales de la semilla (Wallapop
   y Kleinanzeigen, 2026-10-13) con lo que son y cuánta memoria venden, lo
   que dicen de sí mismos (estado, precio por módulo, unidades sueltas) y las
   invariantes de la salida. *)

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let campo j k = match j with `Assoc l -> (match List.assoc_opt k l with Some v -> v | None -> `Null) | _ -> `Null

let texto j k =
  match campo j k with
  | `String s -> s
  | `Int i -> string_of_int i
  | `Float f -> Printf.sprintf "%g" f
  | `Intlit s -> s
  | `Bool b -> string_of_bool b
  | _ -> "-"

let lee entrada = match Memoria_anuncio.aplicar entrada with Ok s -> Ok (Yojson.Safe.from_string s) | Error m -> Error m

(* «modulo 1x32 ddr4 udimm 3200»: lo que se compara. *)
let resumen j =
  Printf.sprintf "%s %sx%s %s %s %s" (texto j "tipo") (texto j "modulos") (texto j "capacidad") (texto j "generacion") (texto j "formato")
    (texto j "velocidad")

let entrada ?(cat = "") titulo = "Título: " ^ titulo ^ if cat = "" then "" else "\nCategoría: " ^ cat

let es ?cat titulo esperado =
  match lee (entrada ?cat titulo) with
  | Ok j -> if resumen j <> esperado then falla "%S: %s, se esperaba %s" titulo (resumen j) esperado
  | Error m -> falla "%S: defecto «%s», se esperaba %s" titulo m esperado

let tipo ?cat titulo esperado =
  match lee (entrada ?cat titulo) with
  | Ok j -> if texto j "tipo" <> esperado then falla "%S: %s, se esperaba %s" titulo (texto j "tipo") esperado
  | Error m -> falla "%S: defecto «%s», se esperaba %s" titulo m esperado

let () =
  (* a1: el UDIMM de 32 que le falta *)
  es "Crucial 32GB DDR4 UDIMM CT32G4DFD832A" "modulo 1x32 ddr4 udimm 3200";
  es "Crucial 32GB DDR4 3200MHz CT32G4DFD832A CL22" "modulo 1x32 ddr4 udimm 3200";
  es "Crucial 32GB DDR4-3200 UDIMM RAM Riegel" "modulo 1x32 ddr4 udimm 3200";
  es "Crucial 16GB DDR4-3200 CL22 UDIMM Desktop RAM CT16G4DFRA32A" "modulo 1x16 ddr4 udimm 3200";
  (* a2: RDIMM de 64 a 3200, sueltos y en lote *)
  es "4× Samsung 64GB DDR4-3200 ECC REG RDIMM RAM M393A8G40AB2-CWECO" "lote 4x64 ddr4 rdimm 3200";
  (* La cuenta delante del part number y la capacidad detrás: los 64 GB son de cada uno (el part number lo dice). *)
  es "8x M393A8G40AB2-CWE 64GB" "lote 8x64 ddr4 rdimm 3200";
  es "8xM393A8G40AB2-CWE 64GB" "lote 8x64 ddr4 rdimm 3200";
  es "HPE P03053-0A1 64GB DDR4 3200 Hynix HMAA8GR7AJR4N-XN REG ECC RAM" "modulo 1x64 ddr4 rdimm 3200";
  es "MICRON 64 GB PC4 DDR4 3200 MHz ECC 2Rx4 Server-Speicher" "modulo 1x64 ddr4 rdimm 3200";
  es "50x SK Hynix DDR4 3200AA 64GB 2Rx4 Módulos RAM" "lote 50x64 ddr4 rdimm 3200";
  es "256GB Kingston KSM32RD4 4x64GB DDR4 3200 ECC RDIMM Dell HP Lenovo" "lote 4x64 ddr4 rdimm 3200";
  es "Samsung DDR4 M393A8G40MB2-CVF 64GB PC4-2933Y Arbeitsspeicher ECC" "modulo 1x64 ddr4 rdimm 2933";
  es "Samsung 64GB Server RAM ECC DDR4 4DRx4 PC4-2666V" "modulo 1x64 ddr4 rdimm 2666";
  es "SK hynix 64GB DDR4-2933Y PC4-2933Y-L ECC LRDIMM HMAA8GL7CPR4N-WM" "modulo 1x64 ddr4 lrdimm 2933";
  es "Skhynix 2* 64GB 128gb DDR4 2S2rx4 2666V ECC RAM HMAA8GR7A2R4N-VN" "lote 2x64 ddr4 3ds-rdimm 2666";
  (* kits: «2x32GB» son dos de 32; «(16x4)», cuatro de 16 *)
  es "Corsair Vengeance LPX 64GB (2x32GB) DDR4-3200 CL16" "kit 2x32 ddr4 udimm 3200";
  es "Kingston FURY Beast DDR4 16GB 3600MHz (16x4) 64gb" "kit 4x16 ddr4 udimm 3600";
  es "Kingston Fury Beast DDR5 64GB Kit (2x32GB) 6000 MHz CL36" "kit 2x32 ddr5 udimm 6000";
  es "Crucial CT2K16G4SFRA32A DDR4 Kit 32 GB (2x16 GB) 3200 MHz SO-DIMM" "kit 2x16 ddr4 sodimm 3200";
  es "4x HyperX Fury DDR4 64 gb (16 cada una) 3200MHz RA" "kit 4x16 ddr4 udimm 3200";
  es "Crucial 32GB DDR5-6400 CUDIMM RAM (CT32G64C52CU5) – Nahezu Neu!!" "modulo 1x32 ddr5 cudimm 6400";
  (* lotes de servidor y de DDR3 *)
  es "64GB (4x16GB) Samsung DDR3 ECC RDIMM Server RAM PC3L-12800R 2Rx4" "lote 4x16 ddr3 rdimm 1600";
  es "Samsung 64GB (2x32GB) DDR4 2400MHz PC4-2400T-LA0-11-MC0" "lote 2x32 ddr4 lrdimm 2400";
  es "128GB 8x 16GB 14900R 1866 DDR3 PC3 ECC REG Ram Mac Pro 6,1 MacPro" "lote 8x16 ddr3 rdimm 1866";
  es "Memoria RAM Servidor HP 4GB DDR3 PC3-10600R" "modulo 1x4 ddr3 rdimm 1333";
  es "2x 32GB SK Hynix DDR4-2400 ECC Registered RAM (64GB) +Xeon gratis" "lote 2x32 ddr4 rdimm 2400";
  (* lo que no es una cuenta: «DDR 4», el «-11» de la etiqueta *)
  es "SK Hynix 8GB 1Rx8 PC4-3200AA-SA2-11 RAM Arbeitsspeicher" "modulo 1x8 ddr4 sodimm 3200";
  es "DDR 4 ram 32 GB 2133 MHz Corsair" "modulo 1x32 ddr4 - 2133";
  (* lo que se ofrece en un cambio es lo de antes de «gegen», «vs» *)
  es "Tausch 2x 64GB DDR4 ECC 2666 vs 8x 16GB 3200 o. 4x 32GB 3200," "lote 2x64 ddr4 - 2666";
  es "*Tausch* 32GB(2x16) DDR5 6000 CL36 gegen 64GB DDR5 (2x32)" "kit 2x16 ddr5 - 6000"

(* Lo que no es memoria suelta. *)
let () =
  tipo "HP Z440 Workstation Xeon E2699 v4 22C 44T 128GB ECC RAM RTX 3060" "pc";
  tipo ~cat:"PCs" "HP Z420 128GB RAM Xeon 1650 512GB Quadro K4200 WLAN Workstation" "pc";
  tipo ~cat:"Laptops" "Portátil HP 840 G5 i7 8th 16Gb RAM 512Gb SSD 14\"" "portatil";
  tipo ~cat:"Desktop Computers" "Servidor Dell PowerEdge R630, Dual Xeon E5-2699 v3, RAM 32GB, A+" "servidor";
  tipo "IBM 96 Core, 512 GB RAM 19\" HP Serverschrank B60cm H200cm T100cm" "servidor";
  tipo "Home Server: Lenovo M70q, i5, 64GB RAM, 512GB + 1TB SSDs" "pc";
  tipo "Combo Ryzen 9 5900X + B550M + 64GB RAM + NZXT280MM" "placa";
  tipo "G.SKILL 32GB DDR5 6000MHz + I7 14700k + Z790 AORUS PRO X WIFI7" "placa";
  tipo "Kit Servidor Huananzhi X99 + Xeon E5-2670 V3" "placa";
  tipo "Supermicro X10DRi-T Dual Xeon 10GbE" "placa";
  tipo "AMD Ryzen 7 5800X + 32 GB Corsair DDR4 3200 MHz RAM" "cpu";
  tipo "Lenovo M93p i5 8GB RAM 256GB SSD GTX 1650" "pc";
  tipo "Tarjeta Gráfica AMD FirePro V5900 2GB" "componente";
  tipo "Msi 1080 Ti - MAL FUNCIONAMIENTO" "componente";
  tipo "M654T Dell PowerEdge RAM Memory Riser Board" "componente";
  tipo "Alimentatore PC iTek ITPS500 ATX 500W" "componente";
  tipo "Suche Ankauf DDR4 DDR5 Server RAM ECC L/RDIMM Samsung Hynix Micro" "busca";
  tipo "「Precio Más Alto」DDR4 Interesado RDIMM ECC RAM" "busca";
  tipo "32GB DDR4 3200Mhz oder 2666 suche" "busca";
  tipo ~cat:"Smartphones" "Redmagic 11 Pro 32gb RAM Pantalla Rota" "otro";
  (* «Server RAM», «für Notebook»: la memoria es lo que se vende *)
  tipo "Server RAM Kingston 16GB - DDR4 - KVR21R15D4/16 ECC" "modulo";
  tipo "Samsung 64GB Server DDR4 RAM" "modulo";
  tipo "16 GB Ram für Notebook PC4-3200AA-SA-11" "modulo";
  (* los lotes mezclados *)
  tipo "Lote 11 Memorias RAM DDR2 DDR3 DDR3L DDR4" "lote";
  tipo "Konvolut DDR3 RAM Arbeitsspeicher, verschiedene 4GB Riegel" "lote"

(* Unidades sueltas, precio por módulo, estado y lo demás. *)
let () =
  let mira entrada k esperado =
    match lee entrada with
    | Ok j -> if texto j k <> esperado then falla "%s de %S: %s, se esperaba %s" k entrada (texto j k) esperado
    | Error m -> falla "%S: defecto %s" entrada m
  in
  let hpe =
    "Título: HPE P03053-0A1 64GB DDR4 3200 Hynix HMAA8GR7AJR4N-XN REG ECC RAM\nPrecio: 800\nDescripción: price for 1 memory module\n\n32 units in stock, i can also sell this as a lot"
  in
  let lote50 =
    "Título: 50x SK Hynix DDR4 3200AA 64GB 2Rx4 Módulos RAM\nDescripción: Todos pasan el test mentest1-13 en dos ciclos. Se puede emitir una factura a su nombre"
  in
  let cisco =
    "Título: Lotto 6x 8GB RAM Server Cisco 48GB DDR3\nDescripción: smontati da server aziendali Cisco UCS dismessi. ATTENZIONE: NON funziona sui normali PC"
  in
  mira "Título: Hynix 16GB DDR4 2400T RDIMM Server RAM bis zu 4 Stück" "disponibles" "4";
  mira "Título: 16GB DDR3 ECC REG Server-RAM – 4 Stück verfügbar" "disponibles" "4";
  mira "Título: 16GB DDR3 ECC REG Server-RAM – 4 Stück verfügbar" "tipo" "modulo";
  mira hpe "precioModulo" "800";
  mira hpe "disponibles" "32";
  mira hpe "oem" "hpe";
  mira "Título: 4× Samsung 64GB DDR4-3200 ECC REG RDIMM RAM M393A8G40AB2-CWECO\nPrecio: 600\nDescripción: Preis\n600 € VB pro Riegel\n2.000 € für alle vier zusammen"
    "precioModulo" "600";
  mira "Título: Samsung M393A8G40AB2-CWECO 64GB DDR4 3200 ECC REG Speichermodul\nDescripción: Speichermodul, gebraucht, getestet , technisch ok.\nFestpreis / Stk. 400,- ( max. 4 Stk. ) , Abholung/Bar"
    "precioModulo" "400";
  mira "Título: 10x 4GB DDR3 SO-DIMM RAM Konvolut Arbeitsspeicher Laptop\nPrecio: 55\nDescripción: Die 55€ (5,50€ pro Stück) sind ein Top Preis"
    "precioModulo" "5.5";
  mira "Título: 8x 16GB HPE ECC RAM 2933MHz RDIMM Micron\nPrecio: 280" "precioModulo" "35";
  mira "Título: Memoria RAM Transcend 4GB DDR3L 1600 ECC\nPrecio: 9.95" "precio" "9.95";
  mira lote50 "probado" "memtest";
  mira lote50 "factura" "si";
  mira cisco "estado" "usada";
  mira cisco "procedencia" "servidor";
  mira "Título: Samsung 64GB DDR4 ECC Server RAM 2666 M393A8K40B22-CWD6Y\nDescripción: Die Riegel stammen aus laufenden Serversystemen und wurden im Zuge eines Hardware-Upgrades ausgebaut."
    "procedencia" "servidor";
  mira "Título: 4x16 GB RAM IBM 2Rx4 PC3L-8500R, ECC 64GB FRU 49Y1418\nDescripción: Verkauf nur komplett." "divisible" "no";
  mira "Título: 2x 32GB 64GB Kingston SO-DIMM DDR4 3200\nDescripción: Nur Abholung!" "envio" "no";
  mira "Título: Crucial 32GB DDR4 UDIMM CT32G4DFD832A" "oem" "-";
  mira "Título: HPE SK hynix 16GB DDR4-2400 ECC RDIMM HMA82GR7AFR4N-UH" "oem" "hpe";
  mira "Título: HPE SK hynix 16GB DDR4-2400 ECC RDIMM HMA82GR7AFR4N-UH" "fabricante" "skhynix";
  mira "Título: Corsair Vengeance RGB PRO 32GB (2x16GB) DDR4 3200MHz" "disipador" "si";
  mira "Título: Corsair Vengeance RGB PRO 32GB (2x16GB) DDR4 3200MHz" "rgb" "si";
  mira "Título: *Tausch* 32GB(2x16) DDR5 6000 CL36 gegen 64GB DDR5 (2x32)" "cambio" "si";
  (* la descripción da lo que el título calla *)
  mira "Título: Samsung 64GB DDR4 RAM Speicherriegel\nDescripción: - Kapazität: 64 GB\n- Typ: DDR4 RAM\n- Modellbezeichnung: M393A8G40AB2-CWEBY"
    "formato" "rdimm";
  mira "Título: Kingston Fury DDR 4 3200mhz 64GB\nDescripción: Es handelt sich um zwei Module mit einer Gesamtkapazität von 64 GB.\n• Kapazität: 64 GB (2 x 32 GB)"
    "capacidad" "32";
  (* las palabras clave de una tienda no dicen nada del anuncio *)
  mira "Título: ‼️ MEMORIA RAM DDR5 32GB 2X16 ACER RGB CL30 ‼️️\nDescripción: Abiertas y sin usar.\n Tags: DDR4, DDR5, ECC, non-ECC, 1.35V" "ecc" "-"

(* Lo que no sabe: defecto. *)
let () =
  let defecto entrada = match Memoria_anuncio.aplicar entrada with Error _ -> () | Ok s -> falla "%S debía ser defecto: %s" entrada s in
  defecto "Título: Ddr4 64gb 3200mhz";
  defecto "Título: Corsair Vengeance RGB Pro 64GB DDR4 3600MHz RAM Kit";
  defecto "Título: Corsair Vengeance LPX DDR4 RAM";
  defecto "Título: 32GB 64GB 128GB 256 GB 2666 Mhz SK Hynix Micron DDR4 ECC Ram";
  defecto ""

(* Invariantes: el tipo es uno de los once; fuera de la memoria, sus campos van a null; capacidad × módulos = total. *)
let () =
  let tipos = [ "modulo"; "kit"; "lote"; "pc"; "portatil"; "servidor"; "placa"; "cpu"; "componente"; "busca"; "otro" ] in
  let formatos = [ "udimm"; "sodimm"; "rdimm"; "lrdimm"; "3ds-rdimm"; "ecc-udimm"; "ecc-sodimm"; "cudimm"; "csodimm"; "camm2"; "mrdimm"; "fbdimm" ] in
  List.iter
    (fun t ->
      match lee ("Título: " ^ t) with
      | Error _ -> ()
      | Ok j -> (
        let tp = texto j "tipo" in
        if not (List.mem tp tipos) then falla "%S: tipo %s" t tp;
        (match campo j "formato" with `String f when not (List.mem f formatos) -> falla "%S: formato %s" t f | _ -> ());
        if (not (List.mem tp [ "modulo"; "kit"; "lote" ])) && campo j "capacidad" <> `Null then falla "%S: %s con capacidad" t tp;
        match (campo j "capacidad", campo j "modulos", campo j "total") with
        | `Int c, `Int k, `Int total when c * k <> total -> falla "%S: %d x %d no es %d" t k c total
        | _ -> ()))
    [ "Corsair Vengeance LPX 64GB (2x32GB) DDR4-3200 CL16"; "HP Z440 Workstation 128GB RAM"; "4× Samsung 64GB DDR4-3200 ECC REG RDIMM";
      "Lote 11 Memorias RAM DDR2 DDR3 DDR3L DDR4"; "Suche DDR4 RAM"; "16GB DDR3 ECC REG Server-RAM – 4 Stück verfügbar" ]

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de memoria-anuncio\n" !fallos;
    exit 1)
