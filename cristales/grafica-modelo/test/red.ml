(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de grafica-modelo: los títulos reales de SEMILLA.md (Wallapop
   y Kleinanzeigen, 2026-10-12) con lo que nombran, lo que no debe leerse como
   gráfica (procesadores, resoluciones, fuentes, discos, placas) y las
   invariantes del catálogo. *)

open Grafica_modelo

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let claves texto = List.map (fun g -> g.modelo.Catalogo.clave ^ "/" ^ string_of_int g.vram) (leer texto).modelos

(* Título -> claves/memoria que nombra, en orden. *)
let ejemplos =
  [ ("ASUS Dual GeForce RTX 3060 ti V2 OC Edition", [ "rtx-3060-ti/8" ]);
    ("ASUS GTX 1660 Super Strix", [ "gtx-1660-super/6" ]);
    ("ASUS ROG Strix GTX 1080 Ti 11GB VRAM", [ "gtx-1080-ti/11" ]);
    ("Asus ROG Strix LC RTX 4090 OC 24GB", [ "rtx-4090/24" ]);
    ("ASUS TUF RTX 3080 OC 10GB GDDR6X", [ "rtx-3080/10" ]);
    ("Gigabyte Radeon RX 6800 XT 16GB GDDR6 Gaming OC", [ "rx-6800-xt/16" ]);
    ("Gigabyte RTX 2060 Super Windforce OC 8G", [ "rtx-2060-super/8" ]);
    ("Nvidia RTX 3060 12GB KFA2", [ "rtx-3060/12" ]);
    ("Placa Gráfica PowerColor RX 5700 XT 8GB", [ "rx-5700-xt/8" ]);
    ("RTX 3060TI Gigabyte Eagle 8GB Tarjeta Grafica", [ "rtx-3060-ti/8" ]);
    ("RTX 5060 Ti 16GB Gigabyte Gaming OC", [ "rtx-5060-ti/16" ]);
    ("Sparkle Intel Arc A770 16GB GDDR6 OC", [ "arc-a770/16" ]);
    ("Tarjeta Gráfica ASUS Dual Radeon RX 580 8GB", [ "rx-580/8" ]);
    ("Tarjeta Gráfica Asus R9 270X 4GB DDR5", [ "r9-270x/4" ]);
    ("Tarjeta Gráfica ELSA Rx580 2048sp averiada", [ "rx-580/8" ]);
    ("Tarjeta Gráfica Gigabyte GTX 1660 Super 6gb gdrr6", [ "gtx-1660-super/6" ]);
    ("Tarjeta Gráfica Sapphire AMD RX590 Nitro", [ "rx-590/8" ]);
    ("Tarjeta Gráfica Zotac Gaming GeForce gtx 1660Ti", [ "gtx-1660-ti/6" ]);
    ("Zotac RTX 3070 Ti Trinity OC", [ "rtx-3070-ti/8" ]);
    ("MSI GeForce RTX 2060 Super Armor OC 8GB", [ "rtx-2060-super/8" ]);
    ("Gigabyte RTX 2070 Super 8GB", [ "rtx-2070-super/8" ]);
    ("RTX 4070 Ti", [ "rtx-4070-ti/12" ]);
    ("Tarjeta Gráfica MSI GTX 1080 Gaming x 8GB", [ "gtx-1080/8" ]);
    ("Tarjeta Gráfica Nvidia GTX 1050", [ "gtx-1050/2" ]);
    ("Tarjeta Gráfica MSI NVIDIA GeForce GT 710 1GB", [ "gt-710/1" ]);
    (* Kleinanzeigen *)
    ("GeForce RTX3080 SUPRIM X 10G", [ "rtx-3080/10" ]);
    ("INNO3D GeForce RTX 3080 X3 12GB Grafikkarte in OVP", [ "rtx-3080/12" ]);
    ("Gigabyte RTX 4070 Ti SUPER Gaming OC 16GB", [ "rtx-4070-ti-super/16" ]);
    ("MSI RTX4070 Ti SUPER VENTUS 2X OC 16Gb", [ "rtx-4070-ti-super/16" ]);
    ("Gigabyte GeForce RTX 4070 SUPER WINDFORCE OC 12G „Angebot“", [ "rtx-4070-super/12" ]);
    ("AMD Radeon RX 7900XTX PowerColor Hellhound  Grafikkarte + OVP", [ "rx-7900-xtx/24" ]);
    ("AMD Radeon™ RX 7900 GRE Neu!", [ "rx-7900-gre/16" ]);
    ("MERC 310 xfx Speedster Radeon RX7900XTX 24 GB GDDR6", [ "rx-7900-xtx/24" ]);
    ("AMD Radeon XFX 319 RX 6800xt defekt", [ "rx-6800-xt/16" ]);
    ("RX-580P8D V8.0 GTS XXX ED 8GB OC+ 1386M D5 BP 3xDP HDMI DVI", [ "rx-580/8" ]);
    ("Pal it GTX 1080 Ti 11 GB - Top Zustand -", [ "gtx-1080-ti/11" ]);
    ("ASUS RX580 4GB Dual-Fan", [ "rx-580/4" ]);
    ("Acer Intel Arc A770 Predator BiFrost OC 16GB GDDR6 Grafikkarte", [ "arc-a770/16" ]);
    ("ASRock Intel Arc A770 Phantom Gaming D 8GB OC Grafikkarte", [ "arc-a770/8" ]);
    ("Rx 6800 bzw 6800xt", [ "rx-6800/16"; "rx-6800-xt/16" ]);
    ("EK Waterblocks Backplate für RTX 3080/3090", [ "rtx-3080/10"; "rtx-3090/24" ]);
    (* Sistemas: la gráfica se lee igual; el procesador, no. *)
    ("PC Gaming Ryzen 7 5800X3D + RTX 3080 10GB", [ "rtx-3080/10" ]);
    ("PC Gaming I5 10400F + 1660 SUPER + 16GB + 500GB", [ "gtx-1660-super/6" ]);
    ("PC Gaming 9900k RTX2070 32GB RAM", [ "rtx-2070/8" ]);
    ("PC 5060TI 16GB+5800X/32GB RAM+1TB M.2", [ "rtx-5060-ti/16" ]);
    ("PC Gamer RTX 1660 + i5 7500", [ "gtx-1660/6" ]);
    ("HYPERX OMEN 45L - Ultra 7 270K plus + 3080 MSI", [ "rtx-3080/10" ]);
    ("PC Gaming Ryzen 5 5600G | GTX 1080Ti | 32GB RAM", [ "gtx-1080-ti/11" ]);
    ("Ryzen 5 5500 AMD", []);
    ("Procesador i7 970 (1366)", []);
    ("PC Gamer 1080p", []);
    ("Fuente de Alimentación NOX AT-500P12P 500W", []);
    ("Samsung 970 EVO Plus 1TB", []);
    ("Placa ASUS PRIME B460M-A (1151)", []);
    ("MSI MAG X570 Tomahawk", []);
    ("Monitor ACER KA272 27\" 16:9", []);
    ("Lote 7 cpu: i3 7100T, i5 3450, i7 4790 ...", []);
    ("Radeon VII 16GB", [ "radeon-vii/16" ]);
    ("Sapphire RX Vega 64 Nitro+", [ "rx-vega-64/8" ]);
    ("Intel Arc B580 Limited Edition", [ "arc-b580/12" ]) ]

let otros =
  [ ("Tarjeta Gráfica Gigabyte GTX 260 OC", `Antigua "gtx 260");
    ("Gráfica AMD HD 6750M 512MB iMac 21,5 2011", `Antigua "hd 6750");
    ("Tarjeta Gráfica GeForce FX 5200 128MB DDR", `Antigua "fx 5200");
    ("Soporte Low Profile para Nvidia Quadro P1000", `Profesional "quadro p1000");
    ("RTX 4060 Super 8GB", `Desconocida "rtx 4060 super") ]

let () =
  List.iter
    (fun (t, esperado) ->
      let leido = claves t in
      if leido <> esperado then
        falla "%S: %s, se esperaba %s" t (String.concat "," leido) (String.concat "," esperado))
    ejemplos;
  List.iter
    (fun (t, esperado) ->
      let l = leer t in
      let ok =
        match esperado with
        | `Antigua s -> l.antiguas = [ s ]
        | `Profesional s -> l.profesionales = [ s ]
        | `Desconocida s -> l.desconocidos = [ s ]
      in
      if not ok then
        falla "%S: antiguas [%s] profesionales [%s] desconocidas [%s]" t (String.concat "," l.antiguas)
          (String.concat "," l.profesionales) (String.concat "," l.desconocidos))
    otros

(* El cristal: JSON o defecto. *)
let () =
  (match aplicar "MSI RTX 3080 Gaming Z Trio 12GB" with
   | Ok s when s = {|{"modelos":[{"modelo":"rtx-3080","nombre":"GeForce RTX 3080","fabricante":"nvidia","vram":12,"anyo":2020,"pvp":699,"rendimiento":50}],"desconocidos":[],"antiguas":[],"profesionales":[]}|} -> ()
   | Ok s -> falla "aplicar: %s" s
   | Error m -> falla "aplicar: defecto %s" m);
  (match aplicar "silla gaming roja" with Error "no nombra ninguna gráfica" -> () | _ -> falla "silla: debía ser defecto");
  match aplicar "RTX 6090 32GB" with Error m when String.starts_with ~prefix:"modelo desconocido" m -> () | _ -> falla "6090: debía ser desconocida"

(* Invariantes del catálogo: claves únicas, cada modelo se lee por su nombre
   y por su clave, memoria y rendimiento con sentido. *)
let () =
  let claves = List.map (fun m -> m.Catalogo.clave) Catalogo.modelos in
  if List.length (List.sort_uniq compare claves) <> List.length claves then falla "claves repetidas en el catálogo";
  List.iter
    (fun (m : Catalogo.modelo) ->
      let por_nombre = List.map (fun g -> g.modelo.Catalogo.clave) (leer m.nombre).modelos in
      if por_nombre <> [ m.clave ] then falla "%S no se lee como %s (%s)" m.nombre m.clave (String.concat "," por_nombre);
      let por_clave = List.map (fun g -> g.modelo.Catalogo.clave) (leer (String.map (function '-' -> ' ' | c -> c) m.clave)).modelos in
      if por_clave <> [ m.clave ] then falla "la clave %s no se lee como ella (%s)" m.clave (String.concat "," por_clave);
      if m.vram = [] || List.exists (fun g -> g < 1 || g > 48) m.vram then falla "%s: memoria rara" m.clave;
      if m.rendimiento < 1 || m.rendimiento > 200 then falla "%s: rendimiento raro" m.clave;
      if m.anyo < 2012 || m.anyo > 2026 then falla "%s: año raro" m.clave)
    Catalogo.modelos

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de grafica-modelo\n" !fallos;
    exit 1)
