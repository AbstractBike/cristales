(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de nvme-anuncio: los anuncios reales de SEMILLA.md
   (Wallapop con su categoría, Kleinanzeigen en Festplatten & Laufwerke;
   2026-10-12) y lo que son; la salud y el estado que dicen título y
   descripción; y los defectos. *)

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let entrada ?(categoria = "") ?(descripcion = "") titulo =
  "Título: " ^ titulo
  ^ (if categoria = "" then "" else "\nCategoría: " ^ categoria)
  ^ if descripcion = "" then "" else "\nDescripción: " ^ descripcion

let campo json k =
  match json with
  | `Assoc l -> (
    match List.assoc_opt k l with
    | Some (`String s) -> s
    | Some (`Int i) -> string_of_int i
    | Some (`Bool b) -> string_of_bool b
    | Some `Null | None -> "-"
    | Some _ -> "?")
  | _ -> "?"

(* tipo, modelo («-» si no) y capacidad («-» si no) *)
let comprueba ?categoria ?descripcion titulo (tipo, modelo, capacidad) =
  match Nvme_anuncio.aplicar (entrada ?categoria ?descripcion titulo) with
  | Error m -> falla "%S: defecto «%s», se esperaba %s %s %s" titulo m tipo modelo capacidad
  | Ok s ->
    let j = Yojson.Safe.from_string s in
    if campo j "tipo" <> tipo || campo j "modelo" <> modelo || campo j "capacidad" <> capacidad then
      falla "%S: %s %s %s, se esperaba %s %s %s" titulo (campo j "tipo") (campo j "modelo") (campo j "capacidad") tipo modelo capacidad

let comp = "Computer components & parts"
let ext = "External hard drives"
let laptops = "Laptops"
let gaming_pc = "Gaming desktops"
let desktops = "Desktop Computers"
let ka = "Festplatten & Laufwerke"

let wallapop =
  [ ("SSD Kingston NV3 2TB PCIe 4.0 NVMe M.2", comp, ("ssd", "kingston-nv3", "2000"));
    ("SSD NVMe M.2 SanDisk Extreme 1TB", comp, ("ssd", "-", "1000"));
    ("SSD WD Black SN850P 1TB NVMe para PS5", comp, ("ssd", "wd-black-sn850x", "1000"));
    ("SSD Samsung 1TB NVMe Gen4 OEM - De HP ProDesk 400", comp, ("ssd", "-", "1000"));
    ("WD Blue SN570 NVMe SSD 2TB", comp, ("ssd", "wd-blue-sn570", "2000"));
    ("SSD Samsung 990 PRO 1TB M.2 NVMe PCIe 4.0", comp, ("ssd", "samsung-990-pro", "1000"));
    ("Disco SSD NVMe Lexar NM790 M.2 2280 2TB", comp, ("ssd", "lexar-nm790", "2000"));
    ("SSD Corsair MP600 Core Mini 2TB M.2 2230", comp, ("ssd", "corsair-mp600-core-mini", "2000"));
    ("Lexar NM790 SSD 2TB PCIe Gen4x4 NVMe", ext, ("ssd", "lexar-nm790", "2000"));
    ("SSD Lexar ARES 1TB PCIe Gen4x4 NVMe", ext, ("ssd", "-", "1000"));
    ("Crucial P3 Plus 1TB NVMe SSD", comp, ("ssd", "crucial-p3-plus", "1000"));
    ("SSD NVMe Samsung 970 EVO Plus 2TB", comp, ("ssd", "samsung-970-evo-plus", "2000"));
    ("SSD 1TB NVMe M.2 Gen3x4", comp, ("ssd", "-", "1000"));
    ("Disco NVME SSD MSI Spatium M480 Pro 2TB", comp, ("ssd", "msi-spatium-m480", "2000"));
    ("SSD Samsung 9100 Pro 2TB PCIe 5.0", comp, ("ssd", "samsung-9100-pro", "2000"));
    ("SSD Samsung 990 Pro 4TB con Disipador", comp, ("ssd", "samsung-990-pro", "4000"));
    ("SSD Crucial P310 2TB NVMe PCIe Nuevo 7100Mbs", comp, ("ssd", "crucial-p310", "2000"));
    ("(NUEVO) SSD 2tb PS5", "Accessories & spare parts for consoles", ("sata", "-", "2000"));
    ("SSD NVMe 500 gb gen4 - crucial ps5- Compatible PS5", comp, ("ssd", "-", "500"));
    ("SSD M.2 512GB Western Digital", comp, ("ssd", "-", "512"));
    ("Disco duro SSD Samsung 870 EVO 4TB sólo 71 horas", comp, ("sata", "samsung-870-evo", "4000"));
    ("Crucial BX300 240GB SSD 2.5 SATA", ext, ("sata", "-", "240"));
    ("Disco duro SanDisk SSD X600 SATA M.2 2280 256GB", comp, ("sata", "-", "256"));
    ("SSD Kingston DC600M 480GB SATA III Sin abrir", ext, ("sata", "kingston-dc600m", "480"));
    (* lo que no es un SSD suelto *)
    ("Dell XPS 15 9530 i9 RTX 4070 64GB RAM", laptops, ("portatil", "-", "-"));
    ("ASUS ROG Zephyrus G14 Ryzen 7 32GB 2TB SSD", "Gaming laptops", ("portatil", "-", "-"));
    ("Lenovo ThinkPad L14 Gen 6 Ultra 5 16 Ram 512 SSD", laptops, ("portatil", "-", "-"));
    ("PC Gaming Ryzen 7 + RTX 3060 Ti + 1TB NVMe", gaming_pc, ("pc", "-", "-"));
    ("Torre PC i3-10105 16GB NVME", desktops, ("pc", "-", "-"));
    ("Minisforum UM790 Pro Ryzen 9 96GB RAM 2TB", desktops, ("pc", "-", "-"));
    ("Raspberry Pi 5 8GB con SSD 256GB ya montado", desktops, ("pc", "-", "-"));
    ("Consola Xbox Series X 1TB SSD", "Consoles", ("consola", "-", "-"));
    ("ACASIS 80Gbps M.2 NVMe Enclosure", ext, ("caja", "-", "-"));
    ("Carcasa SSD M.2 NVMe USB C Transparente", ext, ("caja", "-", "-"));
    ("Carcasa M.2 SSD con Hub USB y Lector de Tarjetas", ext, ("caja", "-", "-"));
    ("Placa ASUS Hyper M.2 x16 Gen 4", comp, ("adaptador", "-", "-"));
    ("Heretom 2,5'' SATA SAS SSD Caddy HP Proliant DL380", comp, ("adaptador", "-", "-"));
    ("2x NEW SSD Micron 256GB NVMe Gen4x4 NO NEGOCIABLE", comp, ("lote", "-", "-"));
    ("6x NEW SSD Samsung 256GB NVMe Gen4x4 NO NEGOCIABLE", comp, ("lote", "-", "-"));
    ("Pack 2 SSD Goodram PX500 512GB NVMe M.2", comp, ("lote", "-", "-"));
    ("Combo Placa X79-6M + Xeon E5-2689 + 32GB RAM + SSD", comp, ("componente", "-", "-"));
    ("NVMe 500gb + kit i5 10400", comp, ("lote", "-", "-"));
    ("Gigabyte B650M D3HP placa base AM5 nueva", comp, ("componente", "-", "-"));
    ("Lote PC i5-9600KF +placa B365M +fuente 750W+disip.", comp, ("lote", "-", "-")) ]

let kleinanzeigen =
  [ ("2 TB Kingston KC3000 2048GB M.2 NVMe Interne SSD (SKC3000D/2048G)", ("ssd", "kingston-kc3000", "2000"));
    ("Kingston KC3000 NVME SSD 2TB, PCIe Gen4, Original verpackt", ("ssd", "kingston-kc3000", "2000"));
    ("Samsung 990 PRO 2TB NVMe M.2 SSD – 100% Zustand (kaum genutzt)", ("ssd", "samsung-990-pro", "2000"));
    ("WD_BLACK SN850X 2TB NVMe SSD | PCIe 4.0 | 100% Zustand | TOP", ("ssd", "wd-black-sn850x", "2000"));
    ("WD black sn 850 x 2tb nvme", ("ssd", "wd-black-sn850x", "2000"));
    ("Western Digital SN850P mit Heatsink 2TB NVME SN850X SSD - NEU", ("ssd", "wd-black-sn850x", "2000"));
    ("Crucial P5 Plus 2TB PCIe Gen4 NVMe M.2 SSD mit Kühlkörper", ("ssd", "crucial-p5-plus", "2000"));
    ("Crucial p5 plus ssd Heatsink", ("ssd", "crucial-p5-plus", "-"));
    ("Micron 2 TB M.2 PCIe Gen4 x4 NVMe SSD", ("ssd", "-", "2000"));
    ("1TB M.2 Gen4 x4 NVMe SSD", ("ssd", "-", "1000"));
    ("Hynix 512 GB M.2 NVME PCIe SSD Speicherkarte", ("ssd", "-", "512"));
    ("Kingston KC3000 1TB NVMe SSD + Delock USB-C Gehäuse", ("ssd", "kingston-kc3000", "1000"));
    ("WD BLACK SN850X 4 TB NVMe SSD + ICY BOX Gehäuse - neuwertig!", ("ssd", "wd-black-sn850x", "4000"));
    ("1 TB SSD Festplatte NVME mit Gehäuse Jms583 Chipsatz", ("ssd", "-", "1000"));
    ("Western Digital Red SN700 NVMe SSD 1TB -  2x verfügbar Gebraucht", ("ssd", "wd-red-sn700", "1000"));
    ("Samsung PM9A3 7.68TB U.2 NVMe SSD PCIe 4.0 x4 MZQL27T6HBLA-00A07", ("ssd", "samsung-pm9a3", "7680"));
    ("Samsung PM9A3 1.92TB 2.5 Zoll SSD PCIe Gen4", ("ssd", "samsung-pm9a3", "1920"));
    ("Samsung PM983 3,84TB M.2 22110 PCIe 3.0 x4 NVMe SSD", ("ssd", "samsung-pm983", "3840"));
    ("Samsung PM983 Enterprise SSD 4TB M.2 NVMe inkl. PCIe-Adapter", ("ssd", "samsung-pm983", "3840"));
    ("Micron 7450 PRO 3.84TB Enterprise NVME SSD", ("ssd", "micron-7450-pro", "3840"));
    ("Micron 7400 Pro 3.84TB NVMe Enterprise SSD U.2 (2 Stück)", ("lote", "-", "-"));
    ("Intel DC P4510 4TB U.2 NVMe Enterprise SSD – 100% Health", ("ssd", "intel-p4510", "4000"));
    ("Intel Optane P5800X 400GB 3D Xpoint U.2 Enterprise SSD NVMe", ("ssd", "intel-optane-p5800x", "400"));
    ("!NEU! Intel Optane SSD DC P4801X 375GB M.2 22110 NVMe", ("ssd", "intel-optane-p4801x", "375"));
    ("Dell EMC 960GB U.2 NVMe Enterprise SSD + PCIe x4 Adapter", ("ssd", "-", "960"));
    ("3,84TB Ultrastar® DC SN640 2,5 U.2 NVMe Server Enterprise SSD", ("ssd", "wd-ultrastar-sn640", "3840"));
    ("Kingston DC1500M  NVMe U.2 Datacenter 3.84TB Versiegelt", ("ssd", "kingston-dc1500m", "3840"));
    ("Seagate Nytro 5000 960GB Enterprise NVMe SSD Server (2D6328-038)", ("ssd", "-", "960"));
    (* SATA, SAS y discos duros *)
    ("Crucial MX500 SSD 1 TB – 2,5 Zoll SATA – geprüft", ("sata", "crucial-mx500", "1000"));
    ("Samsung PM1643 7,68 TB SAS 12G Enterprise SSD – 87 %", ("sata", "samsung-pm1643", "7680"));
    ("Kingston 512 GB M.2 2280 SSD SATAIII 6 Gb/s", ("sata", "-", "512"));
    ("Seagate IronWolf 6TB NAS Festplatte 3.5\"", ("hdd", "-", "-"));
    ("Western Digital WD Black 320GB Festplatte 2,5 Zoll", ("hdd", "-", "-"));
    ("WD Red Pro 4TB WD4003FFBX 7.2K 256MB SATA III 3.5''", ("hdd", "-", "-"));
    (* lo que no es un SSD suelto *)
    ("CORSAIR EX400U 2TB Externe USB 4 SSD -Wie neu/Extrem schnell", ("externo", "-", "-"));
    ("ACASIS Thunderbolt 5 SSD Enclosure – 80 Gbit/s – NVMe Gehäuse", ("caja", "-", "-"));
    ("OWC U2 Shuttle – 4x SSD NVMe M.2 Carrier für U.2 / 3,5” Bays", ("lote", "-", "-"));
    ("NVMe M.2 SSD Verlängerung (2230 -> 2242  -> 2260 -> 2280 -> 22110", ("adaptador", "-", "-"));
    ("ASUS Rog Hyper M.2 PCI Express 5.0 Adapter Karte", ("adaptador", "-", "-"));
    ("Ankauf SSD / M.2 / NVMe / Speicher - Preisliste Oktober 2026", ("busca", "-", "-"));
    ("SUCHE: Crucial P5 Plus  SSD", ("busca", "-", "-"));
    ("5TB SSD Paket – 1TB WD Black SN850X + 2x 2TB Crucial P3 Plus", ("lote", "-", "-"));
    ("2x Samsung PM9A3 SSD 2,5“ 1,92 TB - PCIe Gen4  - Neu u. Unbenutzt", ("lote", "-", "-"));
    ("3x Kingston DC600M 7,68TB Enterprise SSD – NEU/OVP", ("lote", "-", "-"));
    ("Supermicro Rackserver mit 4 × Samsung PM983 3,84 TB NVMe SSD", ("pc", "-", "-"));
    ("Synology DiskStation DS923+ NAS-Gehäuse mit 16 TB", ("pc", "-", "-"));
    ("Gaming PC i5-10600KF / RTX 3060 12GB / 32GB RAM / 1,5TB SSD", ("pc", "-", "-"));
    ("HP All in One 1TB HDD + 1 TB SSD 16 GB Ram NP:1049€ PC Laptop", ("pc", "-", "-")) ]

let () =
  List.iter (fun (t, c, e) -> comprueba ~categoria:c t e) wallapop;
  List.iter (fun (t, e) -> comprueba ~categoria:ka t e) kleinanzeigen

(* Lo que no sabe: una marca con un modelo que el catálogo no tiene, o varios modelos. *)
let () =
  let defecto t esperado =
    match Nvme_anuncio.aplicar (entrada ~categoria:ka t) with
    | Error m when m = esperado -> ()
    | Error m -> falla "%S: defecto «%s», se esperaba «%s»" t m esperado
    | Ok s -> falla "%S: %s, se esperaba el defecto «%s»" t s esperado
  in
  defecto "Fikwot FX991 500GB NVMe M.2 SSD" "modelo desconocido: fikwot fx991";
  defecto "Acer Predator GM7 4TB M.2 NVMe SSD PCIe 4.0 I Neu" "modelo desconocido: acer gm7";
  defecto "Samsung PM9A Enterprise SSD 1,92 TB U2 SSD" "modelo desconocido: samsung pm9a";
  defecto "WD BLACK SN850X oder Samsung 990 Pro 2TB" "varios modelos: wd-black-sn850x, samsung-990-pro"

(* La salud y el estado que dicen. *)
let () =
  let mira ?(categoria = ka) ?(descripcion = "") t esperado =
    match Nvme_anuncio.aplicar (entrada ~categoria ~descripcion t) with
    | Ok s ->
      let j = Yojson.Safe.from_string s in
      List.iter (fun (k, v) -> if campo j k <> v then falla "%S: %s=%s, se esperaba %s" t k (campo j k) v) esperado
    | Error m -> falla "%S: defecto %s" t m
  in
  mira "Samsung 990 PRO 2TB NVMe M.2 SSD – 100% Zustand (kaum genutzt)" [ ("vida", "100"); ("estado", "usada") ];
  mira "Kioxia Exceria Plus G3 2TB NVMe ✅ 0% Verschleiß ✅ Protokoll" [ ("vida", "100") ];
  mira "Crucial T700 4TB PCIe 5.0 NVMe SSD | 99% Health | Topzustand" [ ("vida", "99"); ("interfaz", "pcie5"); ("dram", "dram"); ("nand", "tlc") ];
  mira ~categoria:comp "Disco duro SSD Samsung 870 EVO 4TB sólo 71 horas" [ ("horas", "71") ];
  mira "Samsung 990 Pro 2TB" ~descripcion:"Betriebsstunden: 1.234, 12 TB geschrieben, SMART-Werte im Bild (CrystalDiskInfo). Privatverkauf, keine Garantie."
    [ ("horas", "1234"); ("escritos", "12"); ("smart", "si"); ("garantia", "no") ];
  mira "WD BLACK SN850X 2TB NVMe SSD - Neu & OVP" [ ("estado", "nueva"); ("caja", "si"); ("tbw", "1200"); ("formato", "m2-2280") ];
  mira "Samsung 990 PRO 2TB SSD mit Heatsink - Versiegelt" [ ("estado", "nueva"); ("disipador", "si") ];
  mira "Kingston KC3000 2TB NVMe SSD – wie neu" [ ("estado", "usada") ];
  mira "Samsung PM9A3 7.68TB U.2 NVMe SSD PCIe 4.0" [ ("segmento", "enterprise"); ("plp", "true"); ("formato", "u2"); ("tbw", "14016") ];
  mira "Samsung PM983 3,84TB M.2 22110 PCIe 3.0 x4 NVMe SSD" [ ("formato", "m2-22110"); ("interfaz", "pcie3"); ("plp", "true") ];
  mira "Dell EMC 960GB U.2 NVMe Enterprise SSD + PCIe x4 Adapter" [ ("segmento", "enterprise"); ("formato", "u2"); ("marca", "dell") ];
  mira "Kingston NV3 2TB" [ ("dram", "hmb"); ("nand", "qlc") ];
  mira "Samsung 980 Pro 1TB" ~descripcion:"Leider defekt, wird nicht erkannt." [ ("estado", "averiada") ];
  mira "SSD 1TB NVMe M.2 Gen3x4" ~descripcion:"TLC, con DRAM" [ ("nand", "tlc"); ("dram", "dram"); ("interfaz", "pcie3") ];
  mira "Lexar NM790 2TB" ~descripcion:"Con factura de PcComponentes y garantía hasta 2029." [ ("factura", "si"); ("garantia", "si") ];
  (* Sin modelo en el título, el de la descripción (con la capacidad del título). *)
  mira "SSD NVMe 2TB" ~descripcion:"Vendo mi Samsung 990 Pro, casi sin uso." [ ("modelo", "samsung-990-pro"); ("capacidad", "2000"); ("tbw", "1200") ]

(* La entrada sin «Título:» es un título (lo que manda un agente por MCP). *)
let () = match Nvme_anuncio.aplicar "Samsung 990 Pro 2TB" with Ok _ -> () | Error m -> falla "sin «Título:»: %s" m

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de nvme-anuncio\n" !fallos;
    exit 1)
