(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Los SSD que se venden de segunda mano: los NVMe de consumo (de la 960 EVO
   de 2016 a la 9100 Pro y la T710 de 2025), los enterprise que salen de los
   servidores (PM983, PM9A3, Micron 7300/7400/7450, Intel P4510, Optane…) y,
   aparte, los SATA y SAS más vendidos, para saber que no son NVMe.

   Los datos son de las fichas de cada fabricante, de memoria del modelo que
   nucleó el cristal: [tbw] es la resistencia garantizada en TB escritos por
   capacidad (en los enterprise, de sus DWPD y años de garantía), [lectura]
   la secuencial en MB/s. Sirven para el euro por TB y por TBW, no para
   decimales. Un modelo nuevo es otra versión del cristal: sus defectos
   («modelo desconocido») son la semilla. *)

type segmento = Consumo | Enterprise
type interfaz = Pcie3 | Pcie4 | Pcie5 | Sata | Sas
type dram = Dram | Hmb | No_aplica  (** No_aplica: Optane (3D XPoint), sin caché que la necesite. *)
type nand = Tlc | Qlc | Mlc | Slc | Xpoint

type modelo = {
  clave : string;  (** «samsung-990-pro»: la del archivo y la de las búsquedas. *)
  nombre : string;  (** «Samsung 990 Pro». *)
  marca : string;  (** «samsung», «wd», «crucial»… *)
  segmento : segmento;
  interfaz : interfaz;
  formatos : string list;  (** «m2-2280», «m2-22110», «u2», «u3», «e1s», «sata-25»…; el primero, el más común. *)
  dram : dram;
  nand : nand;
  controladora : string;
  plp : bool;  (** Protección ante cortes de luz (condensadores): la de los enterprise. *)
  capacidades : (int * int option) list;  (** GB nominales y su TBW; vacía = la que diga el texto. *)
  anyo : int;
  lectura : int option;
  alias : string list;  (** Secuencias de piezas plegadas («sn 850 x», «pm 9 a 3»). *)
  requiere : string list;  (** Si no está vacía, el texto tiene que nombrar una de estas marcas. *)
}

(* TBW de un enterprise por sus DWPD y sus años de garantía. *)
let dwpd d anyos caps = List.map (fun c -> (c, Some (c * d * 365 * anyos / 1000))) caps
let dwpd_f d anyos caps = List.map (fun c -> (c, Some (int_of_float (float_of_int c *. d *. 365. *. float_of_int anyos /. 1000.)))) caps
let tbw xs = List.map (fun (c, t) -> (c, Some t)) xs
let sin_tbw caps = List.map (fun c -> (c, None)) caps

let m ?(segmento = Consumo) ?(plp = false) ?(requiere = []) ?lectura ?(controladora = "") clave nombre marca interfaz formatos dram nand
    capacidades anyo alias =
  { clave; nombre; marca; segmento; interfaz; formatos; dram; nand; controladora; plp; capacidades; anyo; lectura; alias; requiere }

(* Un enterprise: con PLP y DRAM, como todos. *)
let e ?(dram = Dram) ?(nand = Tlc) ?(plp = true) ?requiere ?lectura ?controladora clave nombre marca interfaz formatos capacidades anyo alias =
  m ~segmento:Enterprise ~plp ?requiere ?lectura ?controladora clave nombre marca interfaz formatos dram nand capacidades anyo alias

let m2 = [ "m2-2280" ]
let sata25 = [ "sata-25" ]

let samsung = [ "samsung" ]
let crucial = [ "crucial" ]
let kingston = [ "kingston" ]
let micron = [ "micron" ]
let intel = [ "intel"; "optane"; "solidigm" ]
let hynix = [ "hynix"; "skhynix" ]
let kioxia = [ "kioxia"; "toshiba" ]
let wd = [ "wd"; "western"; "sandisk"; "hgst"; "ultrastar" ]

let modelos =
  [ (* --- Samsung, consumo ---------------------------------------------- *)
    m "samsung-960-evo" "Samsung 960 EVO" "samsung" Pcie3 m2 Dram Tlc (tbw [ (250, 100); (500, 200); (1000, 400) ]) 2016
      [ "960 evo" ] ~lectura:3200 ~controladora:"Polaris";
    m "samsung-960-pro" "Samsung 960 Pro" "samsung" Pcie3 m2 Dram Mlc (tbw [ (512, 400); (1000, 800); (2000, 1200) ]) 2016
      [ "960 pro" ] ~lectura:3500 ~controladora:"Polaris";
    m "samsung-970-evo" "Samsung 970 EVO" "samsung" Pcie3 m2 Dram Tlc (tbw [ (250, 150); (500, 300); (1000, 600); (2000, 1200) ]) 2018
      [ "970 evo" ] ~lectura:3500 ~controladora:"Phoenix";
    m "samsung-970-evo-plus" "Samsung 970 EVO Plus" "samsung" Pcie3 m2 Dram Tlc (tbw [ (250, 150); (500, 300); (1000, 600); (2000, 1200) ])
      2019 [ "970 evo plus"; "970 evoplus"; "970 plus" ] ~lectura:3500 ~controladora:"Phoenix";
    m "samsung-970-pro" "Samsung 970 Pro" "samsung" Pcie3 m2 Dram Mlc (tbw [ (512, 600); (1000, 1200) ]) 2018 [ "970 pro" ] ~lectura:3500
      ~controladora:"Phoenix";
    m "samsung-980" "Samsung 980" "samsung" Pcie3 m2 Hmb Tlc (tbw [ (250, 150); (500, 300); (1000, 600) ]) 2021 [ "980" ] ~requiere:samsung
      ~lectura:3500 ~controladora:"Pablo";
    m "samsung-980-pro" "Samsung 980 Pro" "samsung" Pcie4 m2 Dram Tlc (tbw [ (250, 150); (500, 300); (1000, 600); (2000, 1200) ]) 2020
      [ "980 pro" ] ~lectura:7000 ~controladora:"Elpis";
    m "samsung-990-evo" "Samsung 990 EVO" "samsung" Pcie4 m2 Hmb Tlc (tbw [ (1000, 600); (2000, 1200) ]) 2024 [ "990 evo" ] ~lectura:5000
      ~controladora:"Piccolo";
    m "samsung-990-evo-plus" "Samsung 990 EVO Plus" "samsung" Pcie4 m2 Hmb Tlc (tbw [ (1000, 600); (2000, 1200); (4000, 2400) ]) 2024
      [ "990 evo plus" ] ~lectura:7250 ~controladora:"Piccolo";
    m "samsung-990-pro" "Samsung 990 Pro" "samsung" Pcie4 m2 Dram Tlc (tbw [ (1000, 600); (2000, 1200); (4000, 2400) ]) 2022
      [ "990 pro"; "pro 990"; "990pro" ] ~lectura:7450 ~controladora:"Pascal";
    m "samsung-9100-pro" "Samsung 9100 Pro" "samsung" Pcie5 m2 Dram Tlc (tbw [ (1000, 600); (2000, 1200); (4000, 2400); (8000, 4800) ]) 2025
      [ "9100 pro" ] ~lectura:14700 ~controladora:"Presto";
    (* Los OEM de los portátiles y los PCs de marca. *)
    m "samsung-pm981" "Samsung PM981" "samsung" Pcie3 m2 Dram Tlc (sin_tbw [ 256; 512; 1000; 2000 ]) 2018 [ "pm 981"; "pm 981 a" ]
      ~lectura:3500 ~controladora:"Phoenix";
    m "samsung-pm9a1" "Samsung PM9A1" "samsung" Pcie4 m2 Dram Tlc (sin_tbw [ 256; 512; 1000; 2000 ]) 2020 [ "pm 9 a 1"; "pm 9 a 1 a" ]
      ~lectura:7000 ~controladora:"Elpis";
    m "samsung-pm9c1" "Samsung PM9C1" "samsung" Pcie4 m2 Hmb Tlc (sin_tbw [ 256; 512; 1000 ]) 2022 [ "pm 9 c 1"; "pm 9 c 1 a" ] ~lectura:5000;
    m "samsung-pm991" "Samsung PM991" "samsung" Pcie3 [ "m2-2230"; "m2-2242"; "m2-2280" ] Hmb Tlc (sin_tbw [ 128; 256; 512 ]) 2019
      [ "pm 991"; "pm 991 a" ] ~lectura:2000;
    (* --- WD y SanDisk, consumo ------------------------------------------- *)
    m "wd-black-sn750" "WD Black SN750" "wd" Pcie3 m2 Dram Tlc (tbw [ (250, 200); (500, 300); (1000, 600); (2000, 1200) ]) 2019
      [ "sn 750"; "sn 750 se" ] ~lectura:3470;
    m "wd-black-sn770" "WD Black SN770" "wd" Pcie4 m2 Hmb Tlc (tbw [ (250, 200); (500, 300); (1000, 600); (2000, 1200) ]) 2022
      [ "sn 770" ] ~lectura:5150;
    m "wd-black-sn770m" "WD Black SN770M" "wd" Pcie4 [ "m2-2230" ] Hmb Tlc (tbw [ (500, 300); (1000, 600); (2000, 1200) ]) 2023
      [ "sn 770 m" ] ~lectura:5150;
    m "wd-black-sn850" "WD Black SN850" "wd" Pcie4 m2 Dram Tlc (tbw [ (500, 300); (1000, 600); (2000, 1200) ]) 2020 [ "sn 850" ]
      ~lectura:7000;
    (* La SN850P es la SN850X con licencia de PlayStation: la misma unidad. *)
    m "wd-black-sn850x" "WD Black SN850X" "wd" Pcie4 m2 Dram Tlc (tbw [ (1000, 600); (2000, 1200); (4000, 2400); (8000, 2400) ]) 2022
      [ "sn 850 x"; "sn 850 p"; "sn 850x" ] ~lectura:7300;
    m "wd-black-sn7100" "WD Black SN7100" "wd" Pcie4 m2 Hmb Tlc (tbw [ (500, 300); (1000, 600); (2000, 1200); (4000, 2400) ]) 2024
      [ "sn 7100" ] ~lectura:7250;
    m "wd-blue-sn570" "WD Blue SN570" "wd" Pcie3 m2 Hmb Tlc (tbw [ (250, 150); (500, 300); (1000, 600); (2000, 900) ]) 2021 [ "sn 570" ]
      ~lectura:3500;
    m "wd-blue-sn580" "WD Blue SN580" "wd" Pcie4 m2 Hmb Tlc (tbw [ (250, 150); (500, 300); (1000, 600); (2000, 900) ]) 2023 [ "sn 580" ]
      ~lectura:4150;
    m "wd-red-sn700" "WD Red SN700" "wd" Pcie3 m2 Dram Tlc (tbw [ (250, 500); (500, 1000); (1000, 2000); (2000, 2500); (4000, 5100) ]) 2021
      [ "sn 700" ] ~lectura:3430;
    m "wd-sn810" "WD PC SN810" "wd" Pcie4 m2 Dram Tlc (sin_tbw [ 256; 512; 1000; 2000 ]) 2021 [ "sn 810" ] ~lectura:6500;
    m "wd-sn740" "WD PC SN740" "wd" Pcie4 [ "m2-2230"; "m2-2242"; "m2-2280" ] Hmb Tlc (sin_tbw [ 256; 512; 1000; 2000 ]) 2021 [ "sn 740" ]
      ~lectura:5150;
    (* --- Crucial, consumo ---------------------------------------------- *)
    m "crucial-p3" "Crucial P3" "crucial" Pcie3 m2 Hmb Qlc (tbw [ (500, 110); (1000, 220); (2000, 440); (4000, 800) ]) 2022 [ "p 3" ]
      ~requiere:crucial ~lectura:3500;
    m "crucial-p3-plus" "Crucial P3 Plus" "crucial" Pcie4 m2 Hmb Qlc (tbw [ (500, 110); (1000, 220); (2000, 440); (4000, 800) ]) 2022
      [ "p 3 plus" ] ~requiere:crucial ~lectura:5000;
    m "crucial-p5" "Crucial P5" "crucial" Pcie3 m2 Dram Tlc (tbw [ (250, 150); (500, 300); (1000, 600); (2000, 1200) ]) 2020 [ "p 5" ]
      ~requiere:crucial ~lectura:3400;
    m "crucial-p5-plus" "Crucial P5 Plus" "crucial" Pcie4 m2 Dram Tlc (tbw [ (500, 300); (1000, 600); (2000, 1200) ]) 2021 [ "p 5 plus" ]
      ~requiere:crucial ~lectura:6600 ~controladora:"Micron";
    m "crucial-p310" "Crucial P310" "crucial" Pcie4 [ "m2-2280"; "m2-2230" ] Hmb Qlc (tbw [ (500, 110); (1000, 220); (2000, 440); (4000, 1000) ])
      2024 [ "p 310" ] ~requiere:crucial ~lectura:7100;
    m "crucial-t500" "Crucial T500" "crucial" Pcie4 m2 Dram Tlc (tbw [ (500, 300); (1000, 600); (2000, 1200); (4000, 2400) ]) 2023 [ "t 500" ]
      ~requiere:crucial ~lectura:7400;
    m "crucial-t700" "Crucial T700" "crucial" Pcie5 m2 Dram Tlc (tbw [ (1000, 600); (2000, 1200); (4000, 2400) ]) 2023 [ "t 700" ]
      ~requiere:crucial ~lectura:12400 ~controladora:"Phison E26";
    m "crucial-t705" "Crucial T705" "crucial" Pcie5 m2 Dram Tlc (tbw [ (1000, 600); (2000, 1200); (4000, 2400) ]) 2024 [ "t 705" ]
      ~requiere:crucial ~lectura:14500 ~controladora:"Phison E26";
    m "crucial-t710" "Crucial T710" "crucial" Pcie5 m2 Dram Tlc (tbw [ (1000, 600); (2000, 1200); (4000, 2400) ]) 2025 [ "t 710" ]
      ~requiere:crucial ~lectura:14900;
    (* --- Kingston ------------------------------------------------------ *)
    m "kingston-a2000" "Kingston A2000" "kingston" Pcie3 m2 Dram Tlc (tbw [ (250, 150); (500, 350); (1000, 600) ]) 2019 [ "a 2000" ]
      ~requiere:kingston ~lectura:2200;
    m "kingston-kc2500" "Kingston KC2500" "kingston" Pcie3 m2 Dram Tlc (tbw [ (250, 150); (500, 300); (1000, 600); (2000, 1200) ]) 2020
      [ "kc 2500" ] ~lectura:3500;
    m "kingston-kc3000" "Kingston KC3000" "kingston" Pcie4 m2 Dram Tlc (tbw [ (512, 400); (1000, 800); (2000, 1600); (4000, 3200) ]) 2021
      [ "kc 3000" ] ~lectura:7000 ~controladora:"Phison E18";
    m "kingston-fury-renegade" "Kingston Fury Renegade" "kingston" Pcie4 m2 Dram Tlc (tbw [ (500, 500); (1000, 1000); (2000, 2000); (4000, 4000) ])
      2021 [ "fury renegade" ] ~lectura:7300 ~controladora:"Phison E18";
    m "kingston-nv2" "Kingston NV2" "kingston" Pcie4 m2 Hmb Qlc (tbw [ (250, 80); (500, 160); (1000, 320); (2000, 640); (4000, 1280) ]) 2022
      [ "nv 2" ] ~requiere:kingston ~lectura:3500;
    m "kingston-nv3" "Kingston NV3" "kingston" Pcie4 m2 Hmb Qlc (tbw [ (500, 160); (1000, 320); (2000, 640); (4000, 1280) ]) 2024 [ "nv 3" ]
      ~requiere:kingston ~lectura:6000;
    (* --- SK hynix y Solidigm ------------------------------------------------- *)
    m "skhynix-p31" "SK hynix Gold P31" "skhynix" Pcie3 m2 Dram Tlc (tbw [ (500, 500); (1000, 750); (2000, 1200) ]) 2020 [ "p 31"; "gold p 31" ]
      ~requiere:hynix ~lectura:3500;
    m "skhynix-p41" "SK hynix Platinum P41" "skhynix" Pcie4 m2 Dram Tlc (tbw [ (500, 500); (1000, 750); (2000, 1200) ]) 2022
      [ "p 41"; "platinum p 41" ] ~requiere:hynix ~lectura:7000 ~controladora:"Aries";
    m "solidigm-p44-pro" "Solidigm P44 Pro" "solidigm" Pcie4 m2 Dram Tlc (tbw [ (512, 400); (1000, 750); (2000, 1200) ]) 2022 [ "p 44 pro" ]
      ~lectura:7000 ~controladora:"Aries";
    m "solidigm-p41-plus" "Solidigm P41 Plus" "solidigm" Pcie4 m2 Hmb Qlc (tbw [ (512, 200); (1000, 400); (2000, 800) ]) 2022 [ "p 41 plus" ]
      ~requiere:[ "solidigm" ] ~lectura:4125;
    (* --- Lexar, Corsair, Seagate, Sabrent, MSI, Kioxia ------------------------- *)
    m "lexar-nm710" "Lexar NM710" "lexar" Pcie4 m2 Hmb Tlc (tbw [ (500, 300); (1000, 600); (2000, 1200) ]) 2022 [ "nm 710" ] ~lectura:5000;
    m "lexar-nm790" "Lexar NM790" "lexar" Pcie4 m2 Hmb Tlc (tbw [ (512, 500); (1000, 1000); (2000, 1500); (4000, 3000) ]) 2023 [ "nm 790" ]
      ~lectura:7400 ~controladora:"Maxio MAP1602";
    m "corsair-mp600" "Corsair MP600" "corsair" Pcie4 m2 Dram Tlc (tbw [ (500, 850); (1000, 1800); (2000, 3600) ]) 2019 [ "mp 600" ]
      ~lectura:4950 ~controladora:"Phison E16";
    m "corsair-mp600-pro" "Corsair MP600 Pro" "corsair" Pcie4 m2 Dram Tlc (tbw [ (500, 350); (1000, 700); (2000, 1400); (4000, 3000) ]) 2021
      [ "mp 600 pro"; "mp 600 pro lpx"; "mp 600 pro xt"; "mp 600 pro nh" ] ~lectura:7100 ~controladora:"Phison E18";
    m "corsair-mp600-core" "Corsair MP600 Core" "corsair" Pcie4 m2 Dram Qlc (tbw [ (1000, 225); (2000, 450); (4000, 900) ]) 2020
      [ "mp 600 core" ] ~lectura:4950 ~controladora:"Phison E16";
    m "corsair-mp600-core-xt" "Corsair MP600 Core XT" "corsair" Pcie4 m2 Hmb Qlc (tbw [ (1000, 225); (2000, 450); (4000, 900) ]) 2022
      [ "mp 600 core xt" ] ~lectura:5000;
    m "corsair-mp600-core-mini" "Corsair MP600 Core Mini" "corsair" Pcie4 [ "m2-2230" ] Hmb Qlc (tbw [ (1000, 225); (2000, 450) ]) 2023
      [ "mp 600 core mini"; "mp 600 mini" ] ~lectura:5000;
    m "corsair-mp600-elite" "Corsair MP600 Elite" "corsair" Pcie4 m2 Hmb Tlc (tbw [ (1000, 600); (2000, 1200) ]) 2023 [ "mp 600 elite" ]
      ~lectura:7000;
    m "corsair-mp700" "Corsair MP700" "corsair" Pcie5 m2 Dram Tlc (tbw [ (1000, 700); (2000, 1400) ]) 2023 [ "mp 700" ] ~lectura:10000
      ~controladora:"Phison E26";
    m "corsair-mp700-pro" "Corsair MP700 Pro" "corsair" Pcie5 m2 Dram Tlc (tbw [ (1000, 700); (2000, 1400); (4000, 3000) ]) 2023
      [ "mp 700 pro"; "mp 700 pro se" ] ~lectura:12400 ~controladora:"Phison E26";
    m "corsair-mp700-elite" "Corsair MP700 Elite" "corsair" Pcie5 m2 Hmb Tlc (tbw [ (1000, 600); (2000, 1200); (4000, 2400) ]) 2024
      [ "mp 700 elite" ] ~lectura:10000;
    m "seagate-firecuda-520" "Seagate FireCuda 520" "seagate" Pcie4 m2 Dram Tlc (tbw [ (500, 850); (1000, 1800); (2000, 3600) ]) 2019
      [ "firecuda 520" ] ~lectura:5000 ~controladora:"Phison E16";
    m "seagate-firecuda-530" "Seagate FireCuda 530" "seagate" Pcie4 m2 Dram Tlc (tbw [ (500, 640); (1000, 1275); (2000, 2550); (4000, 5100) ])
      2021 [ "firecuda 530"; "firecuda 530 r" ] ~lectura:7300 ~controladora:"Phison E18";
    m "seagate-firecuda-540" "Seagate FireCuda 540" "seagate" Pcie5 m2 Dram Tlc (tbw [ (1000, 1000); (2000, 2000) ]) 2023 [ "firecuda 540" ]
      ~lectura:10000 ~controladora:"Phison E26";
    m "sabrent-rocket-4-plus" "Sabrent Rocket 4 Plus" "sabrent" Pcie4 m2 Dram Tlc (tbw [ (1000, 700); (2000, 1400); (4000, 2800) ]) 2021
      [ "rocket 4 plus" ] ~lectura:7100 ~controladora:"Phison E18";
    m "msi-spatium-m480" "MSI Spatium M480 Pro" "msi" Pcie4 m2 Dram Tlc (tbw [ (1000, 700); (2000, 1400); (4000, 3000) ]) 2022
      [ "spatium m 480"; "spatium m 480 pro"; "m 480 pro" ] ~lectura:7400 ~controladora:"Phison E18";
    m "kioxia-exceria-plus-g3" "Kioxia Exceria Plus G3" "kioxia" Pcie4 m2 Hmb Tlc (tbw [ (1000, 600); (2000, 1200) ]) 2022
      [ "exceria plus g 3" ] ~lectura:5000;
    (* --- Intel, consumo (y las Optane de escritorio) ---------------------------- *)
    m "intel-660p" "Intel 660p" "intel" Pcie3 m2 Dram Qlc (tbw [ (512, 100); (1000, 200); (2000, 400) ]) 2018 [ "660 p" ] ~requiere:intel
      ~lectura:1800;
    m "intel-670p" "Intel 670p" "intel" Pcie3 m2 Dram Qlc (tbw [ (512, 185); (1000, 370); (2000, 740) ]) 2021 [ "670 p" ] ~requiere:intel
      ~lectura:3500;
    m "intel-optane-900p" "Intel Optane 900P" "intel" Pcie3 [ "u2"; "aic" ] No_aplica Xpoint (tbw [ (280, 5110); (480, 8760) ]) 2017
      [ "900 p" ] ~requiere:intel ~lectura:2500;
    m "intel-optane-905p" "Intel Optane 905P" "intel" Pcie3 [ "u2"; "aic"; "m2-22110" ] No_aplica Xpoint
      (tbw [ (380, 6935); (480, 8760); (960, 17520); (1500, 27370) ]) 2018 [ "905 p" ] ~requiere:intel ~lectura:2600;
    (* --- Enterprise: Samsung --------------------------------------------- *)
    e "samsung-pm963" "Samsung PM963" "samsung" Pcie3 [ "u2"; "m2-22110" ] (dwpd_f 1.3 3 [ 960; 1920; 3840; 7680 ]) 2016 [ "pm 963" ]
      ~lectura:2000;
    e "samsung-pm983" "Samsung PM983" "samsung" Pcie3 [ "u2"; "m2-22110" ] (dwpd_f 1.3 3 [ 960; 1920; 3840; 7680 ]) 2018 [ "pm 983" ]
      ~lectura:3200 ~controladora:"Phoenix";
    e "samsung-pm9a3" "Samsung PM9A3" "samsung" Pcie4 [ "u2"; "m2-22110"; "e1s" ] (dwpd 1 5 [ 960; 1920; 3840; 7680; 15360 ]) 2021
      [ "pm 9 a 3" ] ~lectura:6900 ~controladora:"Elpis";
    e "samsung-pm1725" "Samsung PM1725" "samsung" Pcie3 [ "u2"; "aic" ] (dwpd 5 5 [ 800; 1600; 3200; 6400 ]) 2016
      [ "pm 1725"; "pm 1725 a"; "pm 1725 b" ] ~lectura:3500;
    e "samsung-pm1733" "Samsung PM1733" "samsung" Pcie4 [ "u2" ] (dwpd 1 5 [ 1920; 3840; 7680; 15360; 30720 ]) 2020 [ "pm 1733" ]
      ~lectura:7000;
    e "samsung-pm1735" "Samsung PM1735" "samsung" Pcie4 [ "u2"; "aic" ] (dwpd 3 5 [ 1600; 3200; 6400; 12800 ]) 2020 [ "pm 1735" ]
      ~lectura:8000;
    e "samsung-pm1743" "Samsung PM1743" "samsung" Pcie5 [ "u2"; "e3s" ] (dwpd 1 5 [ 1920; 3840; 7680; 15360 ]) 2022 [ "pm 1743" ]
      ~lectura:13000;
    (* --- Enterprise: Micron: PRO (1 DWPD) y MAX (3 DWPD), que se distinguen por la capacidad --- *)
    e "micron-7300-pro" "Micron 7300 PRO" "micron" Pcie3 [ "u2"; "m2-22110" ] (dwpd 1 5 [ 960; 1920; 3840; 7680 ]) 2019
      [ "7300 pro"; "7300" ] ~requiere:micron ~lectura:3000;
    e "micron-7300-max" "Micron 7300 MAX" "micron" Pcie3 [ "u2" ] (dwpd 3 5 [ 800; 1600; 3200; 6400 ]) 2019 [ "7300 max"; "7300" ]
      ~requiere:micron ~lectura:3000;
    e "micron-7400-pro" "Micron 7400 PRO" "micron" Pcie4 [ "u3"; "m2-22110"; "m2-2280"; "e1s" ] (dwpd 1 5 [ 480; 960; 1920; 3840; 7680 ])
      2021 [ "7400 pro"; "7400" ] ~requiere:micron ~lectura:6600;
    e "micron-7400-max" "Micron 7400 MAX" "micron" Pcie4 [ "u3"; "m2-22110" ] (dwpd 3 5 [ 400; 800; 1600; 3200; 6400 ]) 2021
      [ "7400 max"; "7400" ] ~requiere:micron ~lectura:6600;
    e "micron-7450-pro" "Micron 7450 PRO" "micron" Pcie4 [ "u3"; "m2-22110"; "m2-2280"; "e1s" ] (dwpd 1 5 [ 480; 960; 1920; 3840; 7680; 15360 ])
      2022 [ "7450 pro"; "7450" ] ~requiere:micron ~lectura:6800;
    e "micron-7450-max" "Micron 7450 MAX" "micron" Pcie4 [ "u3"; "m2-22110" ] (dwpd 3 5 [ 400; 800; 1600; 3200; 6400; 12800 ]) 2022
      [ "7450 max"; "7450" ] ~requiere:micron ~lectura:6800;
    e "micron-7500-pro" "Micron 7500 PRO" "micron" Pcie4 [ "u3" ] (dwpd 1 5 [ 960; 1920; 3840; 7680; 15360 ]) 2023 [ "7500 pro"; "7500" ]
      ~requiere:micron ~lectura:7000;
    e "micron-9300-pro" "Micron 9300 PRO" "micron" Pcie3 [ "u2" ] (dwpd 1 5 [ 3840; 7680; 15360 ]) 2018 [ "9300 pro"; "9300" ]
      ~requiere:micron ~lectura:3500;
    e "micron-9300-max" "Micron 9300 MAX" "micron" Pcie3 [ "u2" ] (dwpd 3 5 [ 3200; 6400; 12800 ]) 2018 [ "9300 max"; "9300" ]
      ~requiere:micron ~lectura:3500;
    e "micron-9400-pro" "Micron 9400 PRO" "micron" Pcie4 [ "u3" ] (dwpd 1 5 [ 7680; 15360; 30720 ]) 2022 [ "9400 pro"; "9400" ]
      ~requiere:micron ~lectura:7000;
    (* --- Enterprise: Intel y Solidigm ---------------------------------------- *)
    e "intel-p4500" "Intel DC P4500" "intel" Pcie3 [ "u2"; "aic" ] (sin_tbw [ 1000; 2000; 4000; 8000 ]) 2017 [ "p 4500" ] ~lectura:3290;
    e "intel-p4510" "Intel DC P4510" "intel" Pcie3 [ "u2" ] (tbw [ (1000, 1920); (2000, 2610); (4000, 6300); (8000, 13880) ]) 2018
      [ "p 4510" ] ~lectura:3200;
    e "intel-p4600" "Intel DC P4600" "intel" Pcie3 [ "u2"; "aic" ] (dwpd 3 5 [ 1600; 2000; 3200; 4000; 6400 ]) 2017 [ "p 4600" ]
      ~lectura:3290;
    e "intel-p4610" "Intel DC P4610" "intel" Pcie3 [ "u2" ] (dwpd 3 5 [ 1600; 3200; 6400; 7680 ]) 2018 [ "p 4610" ] ~lectura:3200;
    e "solidigm-p5510" "Solidigm D7-P5510" "solidigm" Pcie4 [ "u2" ] (dwpd 1 5 [ 3840; 7680 ]) 2021 [ "p 5510" ] ~lectura:7000;
    e "solidigm-p5520" "Solidigm D7-P5520" "solidigm" Pcie4 [ "u2"; "e1s" ] (dwpd 1 5 [ 1920; 3840; 7680; 15360 ]) 2022 [ "p 5520" ]
      ~lectura:7100;
    e "solidigm-p5620" "Solidigm D7-P5620" "solidigm" Pcie4 [ "u2" ] (dwpd 3 5 [ 1600; 3200; 6400; 12800 ]) 2022 [ "p 5620" ]
      ~lectura:7100;
    e "intel-optane-p4800x" "Intel Optane DC P4800X" "intel" Pcie3 [ "u2"; "aic" ] ~dram:No_aplica ~nand:Xpoint (dwpd 30 5 [ 375; 750; 1500 ])
      2017 [ "p 4800 x"; "d 4800 x" ] ~lectura:2500;
    e "intel-optane-p4801x" "Intel Optane DC P4801X" "intel" Pcie3 [ "m2-22110"; "u2" ] ~dram:No_aplica ~nand:Xpoint (dwpd 60 5 [ 100; 200; 375 ])
      2018 [ "p 4801 x" ] ~lectura:2400;
    e "intel-optane-p5800x" "Intel Optane P5800X" "intel" Pcie4 [ "u2" ] ~dram:No_aplica ~nand:Xpoint (dwpd 100 5 [ 400; 800; 1600; 3200 ])
      2021 [ "p 5800 x" ] ~lectura:7200;
    (* --- Enterprise: WD, Kioxia, Kingston --------------------------------------- *)
    e "wd-ultrastar-sn640" "WD Ultrastar DC SN640" "wd" Pcie3 [ "u2"; "m2-22110"; "e1l" ] (dwpd_f 0.8 5 [ 960; 1920; 3840; 7680 ]) 2019
      [ "sn 640" ] ~lectura:3330;
    e "wd-ultrastar-sn840" "WD Ultrastar DC SN840" "wd" Pcie3 [ "u2" ] (dwpd 1 5 [ 1920; 3840; 7680; 15360 ]) 2020 [ "sn 840" ]
      ~lectura:3330;
    e "wd-ultrastar-sn650" "WD Ultrastar DC SN650" "wd" Pcie4 [ "u3" ] (dwpd 1 5 [ 7680; 15360 ]) 2022 [ "sn 650"; "sn 655" ] ~lectura:6600;
    e "kioxia-cd6" "Kioxia CD6-R" "kioxia" Pcie4 [ "u3" ] (dwpd 1 5 [ 960; 1920; 3840; 7680; 15360 ]) 2020 [ "cd 6"; "cd 6 r" ] ~requiere:kioxia
      ~lectura:6200;
    e "kioxia-cm6" "Kioxia CM6" "kioxia" Pcie4 [ "u3" ] (dwpd 1 5 [ 960; 1920; 3840; 7680; 15360; 30720 ]) 2020 [ "cm 6"; "cm 6 r"; "cm 6 v" ]
      ~requiere:kioxia ~lectura:6900;
    e "kioxia-cd8" "Kioxia CD8-R" "kioxia" Pcie5 [ "u2"; "e3s" ] (dwpd 1 5 [ 1920; 3840; 7680; 15360; 30720 ]) 2022 [ "cd 8"; "cd 8 r" ]
      ~requiere:kioxia ~lectura:12000;
    e "kingston-dc1500m" "Kingston DC1500M" "kingston" Pcie3 [ "u2" ] (dwpd 1 5 [ 960; 1920; 3840; 7680 ]) 2020 [ "dc 1500 m" ] ~lectura:3100;
    e "kingston-dc2000b" "Kingston DC2000B" "kingston" Pcie4 m2 (dwpd_f 0.4 5 [ 240; 480; 960 ]) 2024 [ "dc 2000 b" ] ~lectura:7000;
    e "kingston-dc3000me" "Kingston DC3000ME" "kingston" Pcie5 [ "u2" ] (dwpd 1 5 [ 3840; 7680; 15360 ]) 2024 [ "dc 3000 me" ] ~lectura:14000;
    (* --- SATA y SAS: no son NVMe ---------------------------------------------------- *)
    m "samsung-850-evo" "Samsung 850 EVO" "samsung" Sata sata25 Dram Tlc [] 2014 [ "850 evo" ];
    m "samsung-860-evo" "Samsung 860 EVO" "samsung" Sata sata25 Dram Tlc [] 2018 [ "860 evo" ];
    m "samsung-860-pro" "Samsung 860 Pro" "samsung" Sata sata25 Dram Mlc [] 2018 [ "860 pro" ];
    m "samsung-870-evo" "Samsung 870 EVO" "samsung" Sata sata25 Dram Tlc [] 2021 [ "870 evo" ];
    m "samsung-870-qvo" "Samsung 870 QVO" "samsung" Sata sata25 Dram Qlc [] 2020 [ "870 qvo" ];
    m "crucial-mx500" "Crucial MX500" "crucial" Sata sata25 Dram Tlc [] 2018 [ "mx 500" ];
    m "crucial-bx500" "Crucial BX500" "crucial" Sata sata25 Hmb Tlc [] 2018 [ "bx 500" ];
    m "kingston-a400" "Kingston A400" "kingston" Sata sata25 Hmb Tlc [] 2017 [ "a 400"; "sa 400" ] ~requiere:kingston;
    m "kingston-kc600" "Kingston KC600" "kingston" Sata sata25 Dram Tlc [] 2019 [ "kc 600" ];
    m "wd-red-sa500" "WD Red SA500" "wd" Sata sata25 Dram Tlc [] 2019 [ "sa 500" ];
    m "wd-blue-sa510" "WD Blue SA510" "wd" Sata sata25 Hmb Tlc [] 2021 [ "sa 510" ];
    e "samsung-sm863" "Samsung SM863" "samsung" Sata sata25 ~nand:Mlc [] 2015 [ "sm 863"; "sm 863 a" ];
    e "samsung-sm883" "Samsung SM883" "samsung" Sata sata25 ~nand:Mlc [] 2018 [ "sm 883" ];
    e "samsung-pm883" "Samsung PM883" "samsung" Sata sata25 [] 2018 [ "pm 883" ];
    e "samsung-pm893" "Samsung PM893" "samsung" Sata sata25 [] 2021 [ "pm 893"; "pm 897" ];
    e "samsung-pm1643" "Samsung PM1643" "samsung" Sas [ "sas-25" ] [] 2018 [ "pm 1643"; "pm 1643 a" ];
    e "intel-s4510" "Intel D3-S4510" "intel" Sata sata25 [] 2018 [ "s 4510"; "s 4500" ];
    e "intel-s4610" "Intel D3-S4610" "intel" Sata sata25 [] 2018 [ "s 4610"; "s 4600"; "s 3610"; "s 3520" ];
    e "micron-5300" "Micron 5300" "micron" Sata sata25 [] 2019 [ "5300 pro"; "5300 max"; "5300 boot"; "5300" ] ~requiere:micron;
    e "micron-5400" "Micron 5400" "micron" Sata sata25 [] 2022 [ "5400 pro"; "5400 max"; "5400 boot"; "5400" ] ~requiere:micron;
    e "micron-5200" "Micron 5200" "micron" Sata sata25 [] 2017 [ "5200 eco"; "5200 pro"; "5200 max"; "5200" ] ~requiere:micron;
    e "kingston-dc500m" "Kingston DC500M" "kingston" Sata sata25 [] 2019 [ "dc 500 m"; "dc 500 r" ];
    e "kingston-dc600m" "Kingston DC600M" "kingston" Sata sata25 [] 2023 [ "dc 600 m" ];
    e "wd-ultrastar-ss530" "WD Ultrastar DC SS530" "wd" Sas [ "sas-25" ] [] 2018 [ "ss 530" ] ]

let por_clave = Hashtbl.create 160
let () = List.iter (fun x -> Hashtbl.replace por_clave x.clave x) modelos
let buscar clave = Hashtbl.find_opt por_clave clave

let es_nvme x = match x.interfaz with Pcie3 | Pcie4 | Pcie5 -> true | Sata | Sas -> false

let interfaz_texto = function Pcie3 -> "pcie3" | Pcie4 -> "pcie4" | Pcie5 -> "pcie5" | Sata -> "sata" | Sas -> "sas"
let segmento_texto = function Consumo -> "consumo" | Enterprise -> "enterprise"
let dram_texto = function Dram -> "dram" | Hmb -> "hmb" | No_aplica -> "no-aplica"
let nand_texto = function Tlc -> "tlc" | Qlc -> "qlc" | Mlc -> "mlc" | Slc -> "slc" | Xpoint -> "xpoint"

(* Las marcas que se reconocen en un texto (plegadas), con su nombre de clave. *)
let marcas =
  [ ("samsung", "samsung"); ("wd", "wd"); ("western digital", "wd"); ("wdc", "wd"); ("sandisk", "wd"); ("hgst", "wd");
    ("crucial", "crucial"); ("micron", "micron"); ("kingston", "kingston"); ("sk hynix", "skhynix"); ("hynix", "skhynix");
    ("skhynix", "skhynix"); ("solidigm", "solidigm"); ("intel", "intel"); ("optane", "intel"); ("lexar", "lexar");
    ("corsair", "corsair"); ("seagate", "seagate"); ("sabrent", "sabrent"); ("msi", "msi"); ("kioxia", "kioxia");
    ("toshiba", "kioxia"); ("adata", "adata"); ("xpg", "adata"); ("teamgroup", "teamgroup"); ("team group", "teamgroup");
    ("patriot", "patriot"); ("gigabyte", "gigabyte"); ("aorus", "gigabyte"); ("pny", "pny"); ("transcend", "transcend");
    ("fikwot", "fikwot"); ("fanxiang", "fanxiang"); ("netac", "netac"); ("kingspec", "kingspec"); ("hikvision", "hikvision");
    ("hiksemi", "hikvision"); ("acer", "acer"); ("predator", "acer"); ("biwin", "biwin"); ("goodram", "goodram");
    ("silicon power", "siliconpower"); ("verbatim", "verbatim"); ("emtec", "emtec"); ("apacer", "apacer"); ("phison", "phison");
    ("dell", "dell"); ("hpe", "hpe"); ("hp", "hp"); ("lenovo", "lenovo"); ("netapp", "netapp"); ("kioxia", "kioxia");
    ("ymtc", "ymtc"); ("zhitai", "ymtc"); ("baititon", "baititon"); ("owc", "owc"); ("asus", "asus"); ("nextorage", "nextorage") ]
