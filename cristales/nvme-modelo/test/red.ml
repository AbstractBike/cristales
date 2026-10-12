(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de nvme-modelo: los títulos reales de SEMILLA.md (Wallapop y
   Kleinanzeigen, 2026-10-12) con lo que nombran y su capacidad, lo que no debe
   leerse como modelo (velocidades, memoria de PC, resistencia) y las
   invariantes del catálogo. *)

open Nvme_modelo

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let cap = function Some c -> string_of_int c | None -> "-"
let claves texto = List.map (fun s -> s.modelo.Catalogo.clave ^ "/" ^ cap s.capacidad) (leer texto).modelos

(* Título -> clave/capacidad (GB) de lo que nombra, en orden. *)
let ejemplos =
  [ (* Wallapop *)
    ("SSD Kingston NV3 2TB PCIe 4.0 NVMe M.2", [ "kingston-nv3/2000" ]);
    ("SSD WD Black SN850P 1TB NVMe para PS5", [ "wd-black-sn850x/1000" ]);
    ("WD Blue SN570 NVMe SSD 2TB", [ "wd-blue-sn570/2000" ]);
    ("SSD Samsung 990 PRO 1TB M.2 NVMe PCIe 4.0", [ "samsung-990-pro/1000" ]);
    ("Disco SSD NVMe Lexar NM790 M.2 2280 2TB", [ "lexar-nm790/2000" ]);
    ("Lexar NM790 SSD 2TB PCIe Gen4x4 NVMe", [ "lexar-nm790/2000" ]);
    ("Crucial P3 Plus 1TB NVMe SSD", [ "crucial-p3-plus/1000" ]);
    ("SSD NVMe Samsung 970 EVO Plus 2TB", [ "samsung-970-evo-plus/2000" ]);
    ("Disco NVME SSD MSI Spatium M480 Pro 2TB", [ "msi-spatium-m480/2000" ]);
    ("SSD Corsair MP600 Core Mini 2TB M.2 2230", [ "corsair-mp600-core-mini/2000" ]);
    ("SSD Crucial P310 2TB NVMe PCIe Nuevo 7100Mbs", [ "crucial-p310/2000" ]);
    ("SSD Samsung 9100 Pro 2TB PCIe 5.0", [ "samsung-9100-pro/2000" ]);
    ("SSD Samsung 990 Pro 4TB con Disipador", [ "samsung-990-pro/4000" ]);
    ("SSD NVMe WD_BLACK SN850X 1TB", [ "wd-black-sn850x/1000" ]);
    ("SSD NVMe WD Black SN770 1TB", [ "wd-black-sn770/1000" ]);
    ("SSD WD_Black SN770M 2TB M.2 2230 Nuevo", [ "wd-black-sn770m/2000" ]);
    ("Disco duro SSD Samsung 870 EVO 4TB sólo 71 horas", [ "samsung-870-evo/4000" ]);
    ("Crucial BX300 240GB SSD 2.5 SATA", []);
    (* Kleinanzeigen *)
    ("2 TB Kingston KC3000 2048GB M.2 NVMe Interne SSD (SKC3000D/2048G)", [ "kingston-kc3000/2000" ]);
    ("Festplatte Kingston KC3000 1 TB NVMe SSD PCIe 4.0", [ "kingston-kc3000/1000" ]);
    ("Kingston KC3000 4TB NVMe 2280  versiegelt Festpreis", [ "kingston-kc3000/4000" ]);
    ("Kingston NV2 / 4TB / NVMe / SSD / PCIe 4.0 x4 / TLC-Speicher", [ "kingston-nv2/4000" ]);
    ("Gaming  ssd m.2  nvme Samsung pro 990 2TB", [ "samsung-990-pro/2000" ]);
    ("2TB WD_Black SN850X NVMe M.2 SSD 7300 MB/s & 6600 MB/s inkl OVP", [ "wd-black-sn850x/2000" ]);
    ("WD black sn 850 x 2tb nvme", [ "wd-black-sn850x/2000" ]);
    ("Western Digital WD Black SN850X 2 TB 2000 GB M2 NVMe PCIe 4.0 SSD", [ "wd-black-sn850x/2000" ]);
    ("WD_BLACK SN7100 2TB NVMe SSD PCIe 4.0 M.2 2280 bis 7250 MB/s", [ "wd-black-sn7100/2000" ]);
    ("Crucial P5 Plus 1000GB M.2 2280 NVMe SSD", [ "crucial-p5-plus/1000" ]);
    ("Crucial P5 Plus 2TB PCIe Gen4 NVMe M.2 SSD mit Kühlkörper", [ "crucial-p5-plus/2000" ]);
    ("Crucial P3 Plus 4TB NVMe M.2 SSD (CT4000P3PSSD8) – PCIe 4.0", [ "crucial-p3-plus/4000" ]);
    ("Crucial T700 4TB PCIe 5.0 NVMe SSD | 99% Health | Topzustand", [ "crucial-t700/4000" ]);
    ("Crucial T705 Pro Series 4 TB, NVMe M.2 SSD, PCIe 5.0.", [ "crucial-t705/4000" ]);
    ("Corsair MP600 2TB M.2 PCle Gen4 NVMe SSD", [ "corsair-mp600/2000" ]);
    ("Corsair MP700 Elite PCIe 5.0 NVME SSD 2TB", [ "corsair-mp700-elite/2000" ]);
    ("Corsair MP700 PRO SE 4TB PCIe 5.0 NVMe M.2 SSD", [ "corsair-mp700-pro/4000" ]);
    ("Samsung 980 PRO 2TB NVMe SSD mit Heatsink neuwertig", [ "samsung-980-pro/2000" ]);
    ("2 Tb Samsung 980 Pro NVMe SSD  PS5 geeignet", [ "samsung-980-pro/2000" ]);
    ("Samsung 970 EVO Plus M.2 SSD 1 TB", [ "samsung-970-evo-plus/1000" ]);
    ("Samsung 960EVO SSD NVMe SSD", [ "samsung-960-evo/-" ]);
    ("Samsung PM9C1 512GB M.2 NVMe Gen4x4 Internal SSMZVL8512HFLU-00BH1", [ "samsung-pm9c1/512" ]);
    ("Western Digital Red SN700 NVMe SSD 1TB -  2x verfügbar Gebraucht", [ "wd-red-sn700/1000" ]);
    ("Western Digital WD PC SN810 2TB NVMe SSD M.2 PCIe Gen4x4 int. SSD", [ "wd-sn810/2000" ]);
    ("Wd Blue SN580 NvMe 4.0pcie 2tb neu", [ "wd-blue-sn580/2000" ]);
    ("Kioxia Exceria Plus G3 2TB NVMe ✅ 0% Verschleiß ✅ Protokoll", [ "kioxia-exceria-plus-g3/2000" ]);
    (* enterprise *)
    ("Samsung PM9A3 7.68TB U.2 NVMe SSD PCIe 4.0 x4 MZQL27T6HBLA-00A07", [ "samsung-pm9a3/7680" ]);
    ("2x Samsung PM9A3 SSD 2,5“ 1,92 TB - PCIe Gen4  - Neu u. Unbenutzt", [ "samsung-pm9a3/1920" ]);
    ("Samsung PM983 3,84TB M.2 22110 PCIe 3.0 x4 NVMe SSD", [ "samsung-pm983/3840" ]);
    ("Samsung PM983 Enterprise SSD 4TB M.2 NVMe inkl. PCIe-Adapter", [ "samsung-pm983/3840" ]);
    ("Samsung PM1733 7.68TB U.2 NVMe SSD PCIe 4.0 x4 MZWLJ7T6HALA-00007", [ "samsung-pm1733/7680" ]);
    ("2x Micron/HP 7450 MAX U.3 6,4TB SSD, neuwertig", [ "micron-7450-max/6400" ]);
    ("Micron 7450 PRO 3.84TB Enterprise NVME SSD", [ "micron-7450-pro/3840" ]);
    ("Micron 7450 Enterprise NVMe SSD 3.84 TB", [ "micron-7450-pro/3840" ]);
    ("Micron 7400 Pro 3.84TB NVMe Enterprise SSD U.2 (2 Stück)", [ "micron-7400-pro/3840" ]);
    ("Intel DC P4510 4TB U.2 NVMe Enterprise SSD – 100% Health", [ "intel-p4510/4000" ]);
    ("Intel 1TB SSD DC P4510 Series NVME U.2 2.5\"", [ "intel-p4510/1000" ]);
    ("Intel Optane P5800X 400GB 3D Xpoint U.2 Enterprise SSD NVMe", [ "intel-optane-p5800x/400" ]);
    ("Intel Optane 900P 280GB U.2, 2x neu versiegelt + 2x gebraucht", [ "intel-optane-900p/280" ]);
    ("!NEU! Intel Optane SSD DC P4801X 375GB M.2 22110 NVMe", [ "intel-optane-p4801x/375" ]);
    ("Intel Optane SSD DC D4800X 750GB U.2 NVMe – Neu im Blister", [ "intel-optane-p4800x/750" ]);
    ("3,84TB Ultrastar® DC SN640 2,5 U.2 NVMe Server Enterprise SSD", [ "wd-ultrastar-sn640/3840" ]);
    ("Kingston DC1500M  NVMe U.2 Datacenter 3.84TB Versiegelt", [ "kingston-dc1500m/3840" ]);
    (* SATA y SAS *)
    ("Samsung PM1643 7,68 TB SAS 12G Enterprise SSD – 87 %", [ "samsung-pm1643/7680" ]);
    ("Micron 5400 PRO 3,84 TB Enterprise SSD SATA 2,5 Zoll", [ "micron-5400/3840" ]);
    ("3x Kingston DC600M 7,68TB Enterprise SSD – NEU/OVP", [ "kingston-dc600m/7680" ]);
    ("Crucial MX500 SSD 1 TB – 2,5 Zoll SATA – geprüft", [ "crucial-mx500/1000" ]);
    (* lo que no es un modelo del catálogo *)
    ("SSD 1TB NVMe M.2 Gen3x4", []);
    ("Micron 2 TB M.2 PCIe Gen4 x4 NVMe SSD", []);
    ("PC Gaming Ryzen 7 + RTX 3060 Ti + 1TB NVMe", []);
    ("Placa Base ASUS P5G41T-M LX3 PLUS", []);
    ("Crucial T500 bis 7400 MB/s 2TB", [ "crucial-t500/2000" ]) ]

let () =
  List.iter
    (fun (t, esperado) ->
      let got = claves t in
      if got <> esperado then falla "%S: [%s], se esperaba [%s]" t (String.concat "; " got) (String.concat "; " esperado))
    ejemplos

(* Capacidades: TB con decimales, GB con miles, sin RAM ni TBW. *)
let () =
  let c t esperado =
    let got = List.map Texto.nominal (Texto.capacidades t) in
    if got <> esperado then falla "capacidades %S: [%s], se esperaba [%s]" t (String.concat ";" (List.map string_of_int got)) (String.concat ";" (List.map string_of_int esperado))
  in
  c "Samsung PM9A3 7,68TB" [ 7680 ];
  c "1,92 TB" [ 1920 ];
  c "2.000 GB" [ 2000 ];
  c "2048GB" [ 2000 ];
  c "6,4TB" [ 6400 ];
  c "PC 16GB RAM 1TB SSD" [ 1000 ];
  c "1200 TBW" [];
  c "WD 2T nvme" [ 2000 ];
  c "256MB cache 512 GB" [ 512 ]

(* Interfaz y formato que dice el texto. *)
let () =
  let i t esperado =
    let got = interfaz_texto (Texto.interfaz t) in
    if got <> esperado then falla "interfaz %S: %s" t (Option.value ~default:"-" got)
  in
  i "SSD 1TB NVMe M.2 Gen3x4" (Some "pcie3");
  i "PCIe 4.0 x4" (Some "pcie4");
  i "Wd Blue SN580 NvMe 4.0pcie 2tb" None;
  i "Disco duro SanDisk SSD X600 SATA M.2 2280 256GB" (Some "sata");
  i "PCIe 5.0" (Some "pcie5");
  let f t esperado =
    let got = Texto.formato t in
    if got <> esperado then falla "formato %S: %s" t (Option.value ~default:"-" got)
  in
  f "M.2 2280" (Some "m2-2280");
  f "Samsung PM9A3 7,68TB U.2 NVMe" (Some "u2");
  f "Micron 7450 MAX U.3 6,4TB" (Some "u3");
  f "SSD M.2 512GB" (Some "m2");
  f "Externes IDE-Festplattengehäuse HDD-300U2P" None

(* Lo desconocido, aparte. *)
let () =
  let d t esperado = let got = (leer t).desconocidos in if got <> esperado then falla "desconocidos %S: [%s]" t (String.concat ";" got) in
  d "Fikwot Jupiter 4TB NVMe M.2 SSD" [];
  d "FIKWOT FX991 500GB NVMe" [ "fikwot fx991" ];
  d "Acer Predator GM7 4TB M.2 NVMe SSD PCIe 4.0 I Neu" [ "acer gm7" ];
  match aplicar "FIKWOT FX991 500GB NVMe" with Error m when m = "modelo desconocido: fikwot fx991" -> () | _ -> falla "defecto de lo desconocido"

(* Invariantes: cada modelo se lee por su nombre; claves únicas; capacidades crecientes. *)
let () =
  let vistas = Hashtbl.create 160 in
  List.iter
    (fun (x : Catalogo.modelo) ->
      if Hashtbl.mem vistas x.clave then falla "clave repetida %s" x.clave;
      Hashtbl.replace vistas x.clave ();
      let caps = List.map fst x.capacidades in
      if caps <> List.sort_uniq compare caps then falla "%s: capacidades no crecientes" x.clave;
      if x.formatos = [] then falla "%s: sin formato" x.clave;
      let texto = x.nombre ^ (match x.capacidades with (c, _) :: _ -> " " ^ string_of_int c ^ "GB" | [] -> "") in
      match (leer texto).modelos with
      | [ s ] when s.modelo.clave = x.clave -> ()
      | ms -> falla "%S se lee como [%s]" texto (String.concat ";" (List.map (fun s -> s.modelo.Catalogo.clave) ms)))
    Catalogo.modelos

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de nvme-modelo\n" !fallos;
    exit 1)
