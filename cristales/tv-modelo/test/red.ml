(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de tv-modelo: los códigos y los nombres de las teles que se
   venden (de los anuncios reales del 2026-10-23 y de las peticiones de alta de
   smarttv.email), con su modelo canónico, serie, año, pulgadas y tecnología;
   lo que no es un tamaño (120 Hz, HDMI 2.1, 4K, «hasta 75 pulgadas») y las
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
  | `Bool b -> string_of_bool b
  | `List l -> String.concat "," (List.map (function `String s -> s | `Int i -> string_of_int i | _ -> "?") l)
  | _ -> "-"

let lee t = match Tv_modelo.aplicar t with Ok s -> Ok (Yojson.Safe.from_string s) | Error m -> Error m

(* «LG OLED77C6 C6 2026 77 oled»: el primer modelo. *)
let resumen m = Printf.sprintf "%s %s %s %s %s" (texto m "modelo") (texto m "serie") (texto m "anio") (texto m "pulgadas") (texto m "tecnologia")

let es t esperado =
  match lee t with
  | Ok j -> (
    match campo j "modelos" with
    | `List (m :: _) -> if resumen m <> esperado then falla "%S: %s, se esperaba %s" t (resumen m) esperado
    | _ -> falla "%S: sin modelos, se esperaba %s" t esperado)
  | Error e -> falla "%S: defecto «%s», se esperaba %s" t e esperado

let modelos t esperados =
  match lee t with
  | Ok j ->
    let ms = match campo j "modelos" with `List l -> List.map (fun m -> texto m "modelo") l | _ -> [] in
    if ms <> esperados then falla "%S: [%s], se esperaba [%s]" t (String.concat "; " ms) (String.concat "; " esperados)
  | Error e -> falla "%S: defecto «%s»" t e

let pide t k esperado =
  match lee t with
  | Ok j -> if texto j k <> esperado then falla "%S: %s = %s, se esperaba %s" t k (texto j k) esperado
  | Error e -> falla "%S: defecto «%s», se esperaba %s = %s" t e k esperado

let defecto t = match lee t with Ok j -> falla "%S: %s, se esperaba defecto" t (Yojson.Safe.to_string j) | Error _ -> ()

let () =
  (* Los del contrato con la app *)
  es "LG OLED77C6ELB" "LG OLED77C6 C6 2026 77 oled";
  es "Hisense 75U7SE" "Hisense 75U7SE U7 2026 75 mini-led";
  es "TCL 75C8L" "TCL 75C8L C8L 2026 75 mini-led";
  es "Samsung TQ77S95HATXXC" "Samsung TQ77S95H S95H 2026 77 qd-oled";
  es "Samsung GQ77S95HFT OLED 195,6 cm (77 Zoll) 4K Ultra HD" "Samsung TQ77S95H S95H 2026 77 qd-oled";
  es "LG OLED77B6ELC" "LG OLED77B6 B6 2026 77 oled";
  es "Hisense 75U7S PRO" "Hisense 75U7S PRO U7 2026 75 mini-led";
  es "TCL 75C7L" "TCL 75C7L C7L 2026 75 mini-led";
  es "TCL 75P8L" "TCL 75P8L P8L 2026 75 led";
  es "Sony BRAVIA 9 II 75\"" "Sony 75XR9M2 BRAVIA 9 II 2026 75 -";
  pide "LG OLED77C6ELB" "modelos" "?";
  (* Los códigos de cada marca: el tamaño va dentro *)
  es "LG OLED55C97LA 55 Zoll OLED TV 4K 120Hz" "LG OLED55C9 C9 2019 55 oled";
  es "LG OLED77CS9LA OLED TV (Flat, 77 Zoll / 195 cm" "LG OLED77CS CS - 77 oled";
  es "Fernseher LG OLED 55 Zoll (OLED55BX9LB) - Top Zustand!" "LG OLED55BX BX 2020 55 oled";
  es "LG OLED evo TV 77C31LA 77 Zoll Fernseher" "LG OLED77C3 C3 2023 77 oled";
  es "LG OLED 66  65cs6la" "LG OLED65CS CS - 65 oled";
  es "TV OLED 83\" - LG OLED83C64LA, OLED 4K, Procesador" "LG OLED83C6 C6 2026 83 oled";
  es "LG Signature OLED77Z29LA 77 Zoll OLED 8K TV!" "LG OLED77Z2 Z2 2022 77 oled";
  es "LG UHD TV 55UP77 55 Zoll 139 cm 4K Fernseher" "LG 55UP77 UP77 2021 55 led";
  es "Smart TV LG QNED 65 4K UHD 65QNED86T6A" "LG 65QNED86 QNED86 2024 65 qled";
  es "Samsung S95B 65 Zoll 4K OLED / QD-OLED Smart TV" "Samsung TQ65S95B S95B 2022 65 qd-oled";
  es "Samsung OLED 55S90C (S93C) QD-OLED TV" "Samsung TQ55S90C S90C 2023 55 qd-oled";
  es "Samsung S94C - 65 Zoll OLED Fernseher - 2nd Gen QD-Display S90C" "Samsung TQ65S90C S90C 2023 65 qd-oled";
  es "Samsung Neo QLED 55” GQ55QN85BAT" "Samsung TQ55QN85B QN85B 2022 55 mini-led";
  es "Samsung 65 Neo QLED 8K TV GQ65QN800CTXZG" "Samsung TQ65QN800C QN800C 2023 65 mini-led";
  es "TV Samsung QLED 55 pulgadas 55Q67DAU" "Samsung TQ55Q60D Q60D 2024 55 qled";
  es "Samsung GQ85Q7FAAU QLED-Fernseher (214 cm/85 Zoll, 4K Ultra HD" "Samsung TQ85Q7F Q7F 2025 85 qled";
  es "Smart TV Samsung 65 4K UE65TU8506UXXC" "Samsung UE65TU8000 TU8000 2020 65 led";
  es "Sony BRAVIA XR-65A95K QD-OLED Fernseher in 65 Zoll (164 cm)." "Sony 65A95K A95K 2022 65 qd-oled";
  es "Sony BRAVIA 8 II [K55XR8M2] 55” QD-OLED | Rechnung + Plusgarantie" "Sony 55XR8M2 BRAVIA 8 II 2025 55 qd-oled";
  es "Sony K-75XR90" "Sony 75XR90 BRAVIA 9 2024 75 mini-led";
  es "Sony KD-75X85L" "Sony 75X85L X85L 2023 75 led";
  es "Sony Bravia 85 Zoll 4k Smart TV (KE-85XH9096) inkl. Wandhalterung" "Sony 85XH90 XH90 2020 85 led";
  es "Sony Bravia KD-65 AF8 OLED 4K" "Sony 65AF8 AF8 2018 65 oled";
  es "TCL 55C7K 55 Zoll QD-Mini-LED Google TV" "TCL 55C7K C7K 2025 55 mini-led";
  es "TCL 98 Zoll QM8B, 4K TV, 144 Hz, Mini LED" "TCL 98QM8B QM8B 2024 98 mini-led";
  es "Hisense 85U7Q PRO – 85 Zoll ULED Mini-LED 4K Smart TV, 165 Hz" "Hisense 85U7Q PRO U7 2025 85 mini-led";
  es "Hisense 55U7KQ 55\" 4K Mini-LED ULED Smart-TV" "Hisense 55U7KQ U7 2023 55 mini-led";
  es "Hisense 65A85N 65 Zoll 4K OLED" "Hisense 65A85N A85 2024 65 oled";
  es "‼️85 ZOLL HISENSE 85UXKQ MINI LED" "Hisense 85UXKQ UX 2023 85 mini-led";
  es "Hisense E77Q 43 Zoll Dolby Vision QLED TV" "Hisense 43E7Q E7 2025 43 qled";
  es "Philips 65” OLED TV | 65OLED856/12 | Top-Zustand" "Philips 65OLED856 OLED856 2021 65 oled";
  es "Philips 75PUS8909/12" "Philips 75PUS8909 PUS8909 2024 75 led";
  es "Philips 55PML9059 55\" Mini-LED | 144Hz, Ambilight, 4K" "Philips 55PML9059 PML9059 2024 55 mini-led";
  es "PANASONIC TX-42MZ800E OLED 4K UHD Smart TV, Google TV" "Panasonic TX-42MZ800 MZ800 2023 42 oled";
  es "Panasonic TX-65Z95A" "Panasonic TX-65Z95A Z95A 2024 65 oled";
  es "Xiaomi TV S Mini 75 2025 75 Pulgadas" "Xiaomi TV S Mini LED 75 2025 S Mini LED 2025 75 mini-led";
  es "Xiaomi L75MA-SME" "Xiaomi TV S Mini LED 75 2025 S Mini LED 2025 75 mini-led";
  es "Xiaomi TV A Pro 65 Zoll QLED 4K Google TV (2026)" "Xiaomi TV A Pro 65 A Pro - 65 qled";
  es "Xiaomi TV F Pro 75 (190 cm), 4K UHD QLED" "Xiaomi TV F Pro 75 F Pro - 75 qled";
  (* Nombradas sin código: el tamaño, el de al lado *)
  es "LG OLED C5 77 Zoll (OLED77C57LA)" "LG OLED77C5 C5 2025 77 oled";
  es "Sony Bravia 8 77 Zoll" "Sony 77XR80 BRAVIA 8 2024 77 oled";
  es "Lg C1 77 Zoll Panel Defekt" "LG OLED77C1 C1 2021 77 oled";
  es "Samsung TV Oled S85F 55 Zoll DEFEKT!" "Samsung TQ55S85F S85F 2025 55 oled";
  (* La familia sin año: «Hisense U7» es la serie, no la U7SE *)
  es "Hisense U7 75" "Hisense 75U7 U7 - 75 mini-led";
  (* Peticiones de alta *)
  modelos "una OLED de 77 o una mini-LED de 75, LG C6 o Hisense U7" [ "LG OLED77C6"; "Hisense 75U7" ];
  pide "una OLED de 77 o una mini-LED de 75, LG C6 o Hisense U7" "pulgadas" "77,75";
  pide "una OLED de 77 o una mini-LED de 75, LG C6 o Hisense U7" "tecnologias" "oled,mini-led";
  pide "una OLED de 77 o una mini-LED de 75, LG C6 o Hisense U7" "marcas" "lg,hisense";
  pide "75 pulgadas o más, 120 Hz" "pulgadas" "75";
  pide "75 pulgadas o más, 120 Hz" "pulgadas_min" "75";
  pide "75 pulgadas o más, 120 Hz" "hz_min" "120";
  pide "75 pulgadas o más, 120 Hz" "modelos" "";
  pide "quiero una QD-OLED de 65" "tecnologias" "qd-oled";
  pide "Neo QLED 85" "tecnologias" "mini-led";
  pide "una samsung o una sony de 65 o 75 pulgadas" "marcas" "samsung,sony";
  pide "una samsung o una sony de 65 o 75 pulgadas" "pulgadas" "65,75";
  (* El catálogo sabe lo que no dice el texto; los precios son los de idealo.es, nueva *)
  pide "LG OLED77C6ELB" "hz_min" "-";
  (match lee "Hisense 75U7SE" with
   | Ok j -> (
     match campo j "modelos" with
     | `List (m :: _) ->
       if texto m "precio_nuevo" <> "999" then falla "75U7SE: precio_nuevo %s" (texto m "precio_nuevo");
       if texto m "precio_lanzamiento" <> "-" then falla "75U7SE: precio_lanzamiento %s" (texto m "precio_lanzamiento");
       if texto m "sistema" <> "vidaa" then falla "75U7SE: sistema %s" (texto m "sistema")
     | _ -> falla "75U7SE: sin modelos")
   | Error e -> falla "75U7SE: %s" e);
  (* Lo que no es un tamaño *)
  pide "Samsung QLED 4K 120Hz HDMI 2.1" "pulgadas" "";
  pide "TV LG 55 pulgadas con soporte hasta 75 pulgadas" "pulgadas" "55";
  pide "Samsung TV 55,65,75,85 Zoll Neo Qled" "pulgadas" "55,65,75,85";
  pide "Xiaomi Mi 4A L32M5-5ASP 31,5 Zoll" "pulgadas" "32";
  pide "75 Zoll (1,89m) Smart TV" "pulgadas" "75";
  pide "Smart TV Hisense 164 cm" "pulgadas" "65";
  (* Un código que el catálogo no tiene: modelo, pero desconocido *)
  pide "Samsung S99H 77" "desconocidos" "Samsung TQ77S99H";
  (* Fuera de dominio *)
  defecto "hola, ¿qué tal?";
  defecto "busco algo bonito para el salón";
  if !fallos > 0 then (Printf.eprintf "%d fallos\n" !fallos; exit 1)
