(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de memoria-modelo: los part numbers de la semilla (los de a1
   y a2, sus equivalentes y los que salen en los anuncios del 2026-10-13) con
   lo que dicen, lo que se lee del texto (cuántos, de cuánto, la velocidad
   de una etiqueta), las placas, lo que no es memoria, y las invariantes del
   catálogo. *)

open Memoria_modelo
module C = Catalogo

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let o f = function Some x -> f x | None -> "-"
let gb mb = if mb mod 1024 = 0 then string_of_int (mb / 1024) else Printf.sprintf "%.2f" (float_of_int mb /. 1024.)

(* «ddr4 rdimm 64x1 3200 2Rx4»: lo que se compara de un módulo. *)
let resumen (m : C.modulo) =
  Printf.sprintf "%s %s %sx%d %s %sRx%s" (o C.generacion_texto m.generacion) (o C.formato_texto m.formato) (o gb m.capacidad) m.modulos
    (o string_of_int m.velocidad) (o string_of_int m.rangos) (o string_of_int m.anchura)

let pn texto esperado =
  match (leer texto).modulos with
  | [ (m, _) ] -> if resumen m <> esperado then falla "%S: %s, se esperaba %s" texto (resumen m) esperado
  | ms -> falla "%S: %d módulos" texto (List.length ms)

(* Part number -> generación, formato, capacidad x módulos, velocidad, rangos x anchura. *)
let () =
  (* a2: el que lleva y sus equivalentes exactos *)
  pn "M393A8G40AB2-CWE" "ddr4 rdimm 64x1 3200 2Rx4";
  pn "Samsung M393A8G40AB2-CWECO 64GB" "ddr4 rdimm 64x1 3200 2Rx4";
  (* La cuenta pegada al part number, como la escribe quien se da de alta. *)
  pn "quiero completar mi ROME2D16-2T, ya lleva 8×M393A8G40AB2-CWE" "ddr4 rdimm 64x1 3200 2Rx4";
  pn "M393A8G40BB4-CWE" "ddr4 rdimm 64x1 3200 2Rx4";
  pn "HMAA8GR7AJR4N-XN" "ddr4 rdimm 64x1 3200 2Rx4";
  pn "HMAA8GR7CJR4N-XN" "ddr4 rdimm 64x1 3200 2Rx4";
  pn "MTA36ASF8G72PZ-3G2E1" "ddr4 rdimm 64x1 3200 2Rx4";
  pn "KSM32RD4/64HAR" "ddr4 rdimm 64x1 3200 2Rx4";
  pn "CT64G4RFD432A" "ddr4 rdimm 64x1 3200 2Rx4";
  pn "HPE P03053-0A1" "ddr4 rdimm 64x1 3200 2Rx4";
  (* a1: los que lleva y el que le falta *)
  pn "CT32G4DFD832A.M16FF" "ddr4 udimm 32x1 3200 2Rx8";
  pn "MTA8ATF2G64AZ-3G2F1" "ddr4 udimm 16x1 3200 1Rx8";
  pn "CT16G4DFRA32A.C8FE" "ddr4 udimm 16x1 3200 1Rx8";
  (* lo que no vale para ninguno: más lentos, LRDIMM, 3DS, SO-DIMM, DDR3, DDR5 *)
  pn "M393A8G40MB2-CVF" "ddr4 rdimm 64x1 2933 2Rx4";
  pn "M386A8K40BM1-CRC" "ddr4 lrdimm 64x1 2400 4Rx4";
  pn "HMAA8GR7A2R4N-VN" "ddr4 3ds-rdimm 64x1 2666 -Rx4";
  pn "HMA84GR7AFR4N-UH" "ddr4 rdimm 32x1 2400 2Rx4";
  pn "MTA18ASF2G72PZ-2G9E1" "ddr4 rdimm 16x1 2933 1Rx4";
  pn "MTA9ASF51272PZ" "ddr4 rdimm 4x1 - 1Rx8";
  pn "CT64G4LFQ4266" "ddr4 lrdimm 64x1 2666 4Rx4";
  pn "M471A2K43DB1-CWE" "ddr4 sodimm 16x1 3200 -Rx8";
  pn "HMA81GS6DJR8N-XN" "ddr4 sodimm 8x1 3200 1Rx8";
  pn "CT32G4SFD832A" "ddr4 sodimm 32x1 3200 2Rx8";
  pn "M393B1K70DH0-CK0" "ddr3 rdimm 8x1 1600 2Rx4";
  pn "MT36KSF2G72PZ-1G4" "ddr3 rdimm 16x1 1333 2Rx4";
  pn "HMT31GR7CFR4C-PB" "ddr3 rdimm 8x1 1600 2Rx4";
  pn "MTC40F2046S1RC48BA1" "ddr5 rdimm 64x1 4800 2Rx4";
  pn "M321R8GA0BB0-CQK" "ddr5 rdimm 64x1 4800 -Rx4";
  pn "CT32G56C46S5" "ddr5 sodimm 32x1 5600 -Rx-";
  pn "CT32G64C52CU5" "ddr5 cudimm 32x1 6400 -Rx-";
  (* Kingston, Corsair, G.Skill: los kits dicen el total y cuántos *)
  pn "KVR32N22D8/32" "ddr4 udimm 32x1 3200 2Rx8";
  pn "KVR21R15D4/16" "ddr4 rdimm 16x1 2133 2Rx4";
  pn "KSM26ED8/16HD" "ddr4 ecc-udimm 16x1 2666 2Rx8";
  pn "KTD-PE432/64G" "ddr4 rdimm 64x1 3200 -Rx-";
  pn "KF432C16BBK2/32" "ddr4 udimm 16x2 3200 -Rx-";
  pn "CMK32GX4M2E3200C16" "ddr4 udimm 16x2 3200 -Rx-";
  pn "F4-3200C16D-32GVK" "ddr4 udimm 16x2 3200 -Rx-";
  pn "F5-6000J3038F16GX2-TZ5RK" "ddr5 udimm 16x2 6000 -Rx-";
  pn "BL2K32G32C16U4B" "ddr4 udimm 32x2 3200 -Rx-";
  pn "Synology D4ES02-8G" "ddr4 ecc-sodimm 8x1 - -Rx-"

(* Las etiquetas de OEM, con el módulo que llevan. *)
let () =
  match (leer "HPE P03053-0A1").modulos with
  | [ (m, _) ] when m.oem = Some "hpe" && m.equivalentes = [ "HMAA8GR7AJR4N-XN" ] -> ()
  | _ -> falla "P03053-0A1: sin su OEM o sin su equivalente"

(* Lo que dice el texto: cuántos, de cuánto, la velocidad de la etiqueta, el formato. *)
let esp texto esperado =
  let e = (leer texto).especificacion in
  let got =
    Printf.sprintf "%s %s %sx%s=%s %s cl%s %sRx%s" (o C.generacion_texto e.generacion) (o C.formato_texto e.formato) (o gb e.capacidad)
      (o string_of_int e.modulos) (o gb e.total) (o string_of_int e.velocidad) (o string_of_int e.cas) (o string_of_int e.rangos)
      (o string_of_int e.anchura)
  in
  if got <> esperado then falla "especificación %S: %s, se esperaba %s" texto got esperado

let () =
  esp "Busco 8 módulos RDIMM de 64GB DDR4-3200 2Rx4 ECC" "ddr4 rdimm 64x8=512 3200 cl- 2Rx4";
  esp "2x 16GB DDR4-3200 CL16" "ddr4 - 16x2=32 3200 cl16 -Rx-";
  (* «2x32GB» son dos de 32; «64GB Kit», un kit sin desglose; «(16x4)», cuatro de 16 *)
  esp "Corsair Vengeance LPX 64GB (2x32GB) DDR4-3200 CL16" "ddr4 udimm 32x2=64 3200 cl16 -Rx-";
  esp "Corsair Vengeance RGB Pro 64GB DDR4 3600MHz RAM Kit" "ddr4 udimm -x-=64 3600 cl- -Rx-";
  esp "Kingston FURY Beast DDR4 16GB 3600MHz (16x4) 64gb" "ddr4 udimm 16x4=64 3600 cl- -Rx-";
  esp "64GB (4x16GB) Samsung DDR3 ECC RDIMM Server RAM PC3L-12800R 2Rx4" "ddr3 rdimm 16x4=64 1600 cl- 2Rx4";
  esp "4x 16GB = 64GB DDR4 RDIMM Micron 2Rx8 PC4 2666V RE2 12" "ddr4 rdimm 16x4=64 2666 cl- 2Rx8";
  esp "1GB (2x512) HP DDR2 Memoria RAM Servidor" "ddr2 - 0.50x2=1 - cl- -Rx-";
  esp "128GB 8x 16GB 14900R 1866 DDR3 PC3 ECC REG Ram" "ddr3 rdimm 16x8=128 1866 cl- -Rx-";
  esp "Pack 4 Memorias RAM DDR3 ECC 8GB. 32 GB total." "ddr3 - 8x4=32 - cl- -Rx-";
  esp "4x HyperX Fury DDR4 64 gb (16 cada una) 3200MHz" "ddr4 udimm 16x4=64 3200 cl- -Rx-";
  esp "2× 8 GB DDR4 ECC Registered Server-RAM" "ddr4 rdimm 8x2=16 - cl- -Rx-";
  esp "Lote 6x RAM DDR1 DIMM 2.5GB" "ddr udimm -x6=2.50 - cl- -Rx-";
  (* lo que no es una velocidad ni una cuenta *)
  esp "SK Hynix 8GB 1Rx8 PC4-3200AA-SA2-11 RAM Arbeitsspeicher" "ddr4 sodimm 8x-=- 3200 cl- 1Rx8";
  esp "DDR 4 ram 32 GB 2133 MHz Corsair" "ddr4 - 32x-=- 2133 cl- -Rx-";
  esp "Módulo RAM Samsung 512MB PC2-3200U" "ddr2 udimm 0.50x-=- 400 cl- -Rx-";
  esp "Samsung 16GB DDR4 RAM Laptop / Notebook (3200 MHz, PC4-3200AA)" "ddr4 sodimm 16x-=- 3200 cl- -Rx-";
  esp "64GB Server-RAM \"Mushkin Proline\" DDR4 (PC4-17000) ECC/REG 2Rx4" "ddr4 rdimm 64x-=- 2133 cl- 2Rx4";
  esp "16GB-DDR3L / 1600 MHz {2 x 8 GB}" "ddr3 - 8x2=16 1600 cl- -Rx-";
  (* el «on-die ECC» de DDR5 no es ECC; las etiquetas de una tienda («ECC, non-ECC»), tampoco *)
  (match (leer "DDR5 32GB on-die ECC").especificacion.ecc with None -> () | Some b -> falla "on-die ECC: %b" b);
  match (leer "Tags: DDR4, ECC, non-ECC, RGB").especificacion.ecc with None -> () | Some b -> falla "ECC y non-ECC: %b" b

(* La revisión del 2026-10-13: part numbers de OEM con ECC UDIMM, MB tras la
   barra, la cuenta no es la capacidad, «Dual Rank» no es un kit, «ECC: Nein»,
   el voltaje que el part number no dice y la lista de velocidades de una tienda. *)
let () =
  pn "KTH-PL424E/16G" "ddr4 ecc-udimm 16x1 2400 -Rx-";
  pn "KTD-PE426E/16G" "ddr4 ecc-udimm 16x1 2666 -Rx-";
  pn "KTD-PE432E/32G" "ddr4 ecc-udimm 32x1 3200 -Rx-";
  pn "KTD-PE432/64G" "ddr4 rdimm 64x1 3200 -Rx-";
  pn "Synology D4ECSO-2666-16G" "ddr4 ecc-sodimm 16x1 2666 -Rx-";
  pn "KVR400X64C3A/512" "ddr udimm 0.50x1 400 -Rx-";
  pn "IBM 00D5038" "ddr3 rdimm 8x1 1600 -Rx-";
  (match (leer "256GB Kingston KSM32RD4 4x64GB DDR4 3200 ECC RDIMM").modulos with
   | [ (m, _) ] when m.pn = "KSM32RD4" && m.capacidad = None -> ()
   | _ -> falla "KSM32RD4 4x64GB: la cuenta no es la capacidad de detrás de la barra");
  esp "Necesito un UDIMM de 32 GB DDR4-3200 dual rank para mi B565D4-V1L" "ddr4 udimm 32x-=- 3200 cl- 2Rx-";
  esp "Busco RDIMM de 64GB DDR4-3200 dual rank para ROME2D16-2T" "ddr4 rdimm 64x-=- 3200 cl- 2Rx-";
  (match (leer "Raspberry Pi 4 8GB").especificacion.modulos with Some 4 -> falla "Raspberry Pi 4: cuatro módulos" | _ -> ());
  (match (leer "ECC: Nein").especificacion.ecc with Some false -> () | e -> falla "«ECC: Nein»: %s" (o string_of_bool e));
  (match (leer "DDR3 ECC no registrada").especificacion.ecc with Some true -> () | e -> falla "«ECC no registrada»: %s" (o string_of_bool e));
  esp "Samsung DDR4 REG ECC 32G 1Rx4 Velocidades: 2133P/2400T/2666V/2933Y/3200AA/4800/5600/6000" "ddr4 rdimm 32x-=- - cl- 1Rx4";
  let v t esperado = match (leer t).modulos with [ (m, _) ] when m.voltaje = esperado -> () | _ -> falla "voltaje del part number %S" t in
  v "M393B2G70BH0" None;
  v "M393B2G70BH0-YH9" (Some 1.35);
  v "M393B2G70DB0-YK0Q" (Some 1.35);
  v "M393B2G70BH0-CK0" (Some 1.5)

(* El voltaje. *)
let () =
  let v t esperado = let got = (leer t).especificacion.voltaje in if got <> esperado then falla "voltaje %S: %s" t (o string_of_float got) in
  v "Micron 32 GB DDR4 3200Mhz 1,2Volt (2x16GB)" (Some 1.2);
  v "16GB DDR3L 1600" (Some 1.35);
  v "Kit 16GB DDR3 1,5 V" (Some 1.5);
  v "Corsair 32GB DDR4" None

(* Las placas y los servidores, con la memoria que admiten. *)
let () =
  let p t clave ranuras =
    match (leer t).placas with
    | [ x ] when x.C.clave = clave && x.ranuras = Some ranuras -> ()
    | xs -> falla "placas %S: [%s]" t (String.concat ";" (List.map (fun (x : C.placa) -> x.clave) xs))
  in
  p "ASRockRack ROME2D16-2T" "asrockrack-rome2d16-2t" 16;
  p "ASRock Rack B565D4-V1L" "asrockrack-b565d4-v1l" 4;
  p "Supermicro H12SSL-i" "supermicro-h12ssl" 8;
  p "Dell PowerEdge R740xd" "dell-poweredge-r740" 24;
  (match (leer "placa B550").placas with [ x ] when x.clave = "am4" && x.formatos = [ C.Udimm; C.Ecc_udimm ] -> () | _ -> falla "B550: no es AM4")

(* El JSON y los defectos. *)
let () =
  (match aplicar "M393A8G40AB2-CWE" with
   | Ok s ->
     let j = Yojson.Safe.from_string s in
     let open Yojson.Safe.Util in
     let m = List.hd (j |> member "modulos" |> to_list) in
     if m |> member "capacidad" |> to_int <> 64 || m |> member "formato" |> to_string <> "rdimm" || j |> member "marcas" |> to_list = [] then
       falla "JSON de M393A8G40AB2-CWE: %s" s
   | Error m -> falla "M393A8G40AB2-CWE: defecto %s" m);
  List.iter
    (fun t -> match aplicar t with Error _ -> () | Ok s -> falla "%S debía ser defecto: %s" t s)
    [ "algo de RAM para mi PC"; "SSD 512GB NVMe"; "Ryzen 5 3600"; "Memoria RAM Servidor HP Samsung" ];
  match aplicar "M393Z9Q99XY9-ABC" with Error m when String.length m > 0 -> () | _ -> falla "un part number que no se lee debía ser defecto"

(* Invariantes: cada etiqueta de OEM se lee como ella misma; cada alias de placa, como su placa; claves únicas. *)
let () =
  List.iter
    (fun (clave, (m : C.modulo)) ->
      match (leer m.pn).modulos with
      | [ (x, _) ] when x.pn = m.pn && x.capacidad = m.capacidad -> ()
      | _ -> falla "la etiqueta %s (%s) no se lee como ella" m.pn clave)
    C.oem;
  let vistas = Hashtbl.create 64 in
  List.iter
    (fun (p : C.placa) ->
      if Hashtbl.mem vistas p.clave then falla "placa repetida %s" p.clave;
      Hashtbl.replace vistas p.clave ();
      if p.generaciones = [] || p.formatos = [] then falla "%s: sin generación o sin formato" p.clave;
      List.iter
        (fun a ->
          match List.find_opt (fun (x : C.placa) -> x.clave = p.clave) (leer a).placas with
          | Some _ -> ()
          | None -> falla "el alias %S no lee %s" a p.clave)
        p.alias)
    C.placas

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de memoria-modelo\n" !fallos;
    exit 1)
