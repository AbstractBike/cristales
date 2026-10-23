(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de tv-anuncio: anuncios reales de la semilla (Wallapop ES,
   IT, PT y Kleinanzeigen Fernseher, 2026-10-23) con lo que son, la tele que
   venden, su estado y lo que dicen de sí mismos; las invariantes de la salida
   sobre los 1.181 anuncios de anuncios.jsonl, y el mínimo que tiene que leer
   sin LLM. *)

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
  | _ -> "-"

let lee e = match Tv_anuncio.aplicar e with Ok s -> Ok (Yojson.Safe.from_string s) | Error m -> Error m

let entrada ?(cat = "") ?(desc = "") ?(precio = "") ?(estado = "") titulo =
  String.concat "\n"
    (List.filter (( <> ) "")
       [ "Título: " ^ titulo;
         (if cat = "" then "" else "Categoría: " ^ cat);
         (if precio = "" then "" else "Precio: " ^ precio);
         (if estado = "" then "" else "Estado: " ^ estado);
         (if desc = "" then "" else "Descripción: " ^ desc) ])

(* «tv LG OLED77C6 77 oled usado»: lo que se compara. *)
let resumen j = Printf.sprintf "%s %s %s %s %s" (texto j "tipo") (texto j "modelo") (texto j "pulgadas") (texto j "tecnologia") (texto j "estado")

let es ?cat ?desc ?precio ?estado titulo esperado =
  match lee (entrada ?cat ?desc ?precio ?estado titulo) with
  | Ok j -> if resumen j <> esperado then falla "%S: %s, se esperaba %s" titulo (resumen j) esperado
  | Error m -> falla "%S: defecto «%s», se esperaba %s" titulo m esperado

let tipo ?cat ?desc titulo esperado =
  match lee (entrada ?cat ?desc titulo) with
  | Ok j -> if texto j "tipo" <> esperado then falla "%S: %s, se esperaba %s" titulo (texto j "tipo") esperado
  | Error m -> falla "%S: defecto «%s», se esperaba %s" titulo m esperado

let dice ?cat ?desc ?precio ?estado titulo k esperado =
  match lee (entrada ?cat ?desc ?precio ?estado titulo) with
  | Ok j -> if texto j k <> esperado then falla "%S: %s = %s, se esperaba %s" titulo k (texto j k) esperado
  | Error m -> falla "%S: defecto «%s», se esperaba %s = %s" titulo m k esperado

let defecto ?cat ?desc titulo motivo =
  match lee (entrada ?cat ?desc titulo) with
  | Ok j -> falla "%S: %s, se esperaba defecto" titulo (resumen j)
  | Error m -> if not (String.length m >= String.length motivo && String.sub m 0 (String.length motivo) = motivo) then falla "%S: defecto «%s», se esperaba «%s»" titulo m motivo

let () =
  (* El que busca el usuario: la Xiaomi TV S Mini LED de 75 de 2025 (Wallapop, Marbella) *)
  let desc = "Televisión Xiaomi TV S Mini 75 modelo 2025, con un diseño estilizado y compacto. - Pantalla de 75 pulgadas. - Acabado en color negro. Incluye anclaje pared y las patas de la television" in
  es ~cat:"TVs" ~desc ~precio:"550" "Xiaomi TV S Mini 75 2025 75 Pulgadas" "tv Xiaomi TV S Mini LED 75 2025 75 mini-led usado";
  es ~cat:"TVs" ~desc ~precio:"550" ~estado:"Como nuevo" "Xiaomi TV S Mini 75 2025 75 Pulgadas" "tv Xiaomi TV S Mini LED 75 2025 75 mini-led como-nuevo";
  dice ~desc "Xiaomi TV S Mini 75 2025 75 Pulgadas" "anio" "2025";
  dice ~desc "Xiaomi TV S Mini 75 2025 75 Pulgadas" "hz" "144";
  dice ~desc "Xiaomi TV S Mini 75 2025 75 Pulgadas" "marca" "xiaomi";
  dice ~desc ~precio:"550" "Xiaomi TV S Mini 75 2025 75 Pulgadas" "precio" "550";
  es "Xiaomi TV S Mini 55 2025 Pantalla Rota" "tv Xiaomi TV S Mini LED 55 2025 55 mini-led averiado";
  dice "Xiaomi TV S Mini 55 2025 Pantalla Rota" "averia" "pantalla rota";
  es "Xiaomi TV A Pro 65 Zoll QLED 4K Google TV (2026) – Neuwertig" "tv Xiaomi TV A Pro 65 65 qled como-nuevo";
  (* Teles, con su modelo *)
  es ~cat:"Fernseher" "LG OLED77B42LA  77 Zoll (195 cm),OLED 4K UHD, HDR, Smart TV" "tv LG OLED77B4 77 oled usado";
  es ~cat:"Fernseher" "LG OLED C5 77 Zoll (OLED77C57LA) – Wie neu, kalibriert, 07/2026" "tv LG OLED77C5 77 oled como-nuevo";
  es ~cat:"Fernseher" "Samsung GQ77S95HFT OLED 195,6 cm (77 Zoll) 4K Ultra HD" "tv Samsung TQ77S95H 77 qd-oled usado";
  es ~cat:"Fernseher" "Sony BRAVIA 9 – 75 Zoll Mini-LED 4K Smart TV | Premium-Bildqualit" "tv Sony 75XR90 75 mini-led usado";
  es ~cat:"Fernseher" "Hisense 85U7Q PRO – 85 Zoll ULED Mini-LED 4K Smart TV, 165 Hz" "tv Hisense 85U7Q PRO 85 mini-led usado";
  es ~cat:"Fernseher" "TCL 75Q6C, 75 Zoll, QD-Mini LED 4K Fernseher" "tv TCL 75Q6C 75 mini-led usado";
  es ~cat:"TVs" "Samsung TV NeoQLED QN85C 55 pulgadas" "tv Samsung TQ55QN85C 55 mini-led usado";
  es ~cat:"TVs" "TV Hisense 85E7NQ Pro Gaming  4K  144Hz/244" "tv Hisense 85E7NQ PRO 85 qled usado";
  es ~cat:"TVs" "TV OLED 83\" - LG OLED83C64LA, OLED 4K, Procesador" "tv LG OLED83C6 83 oled usado";
  es ~cat:"Fernseher" "Philips 65” OLED TV | 65OLED856/12 | Top-Zustand" "tv Philips 65OLED856 65 oled usado";
  (* Teles sin modelo: las pulgadas del título, sueltas o con unidad *)
  es ~cat:"TVs" "TV Samsung 75 pulgadas Smart TV" "tv - 75 - usado";
  es ~cat:"TVs" "Televisión Samsung 32 Full HD" "tv - 32 - usado";
  es ~cat:"TVs" "TV Philips 37 Full HD" "tv - 37 - usado";
  es ~cat:"Fernseher" "75 Zoll (1,89m) Smart TV mit Google TV, Sony Bravia 4k UHD" "tv - 75 - usado";
  es ~cat:"Fernseher" "Smart tv Hisense 138 cm 65 Zoll" "tv - 65 - usado";
  es ~cat:"TVs" "TV LG 65 pulgadas Smart TV" "tv - 65 - usado";
  es ~cat:"TVs" ~desc:"Televisor LG smart, funciona perfectamente, de 47 pulgadas. Wifi con cable. incluye mando." "TV LG Smart" "tv - 47 - usado";
  es ~cat:"Fernseher" ~desc:"Bildschirmdiagonale: 164 cm, voll funktionsfähig" "Philips Fernseher" "tv - 65 - usado";
  (* Estados y averías *)
  es "TV Samsung 75 pulgadas para piezas" "tv - 75 - para-piezas";
  es "Samsung 85 Zoll TV Fernseher DEFEKT – Bastler/Ersatzteile“" "tv - 85 - para-piezas";
  es "TV Sony Bravia 75 Mini LED (Panel Roto)" "tv - 75 mini-led averiado";
  dice "TV Sony Bravia 75 Mini LED (Panel Roto)" "averia" "pantalla rota";
  dice "Lg C1 77 Zoll Panel Defekt" "averia" "pantalla rota";
  dice ~desc:"Der Fernseher hat nur einen dünnen grünen Streifen links siehe Bilder." "Samsung 65 Zoll 8k Neo QLED TV" "averia" "rayas";
  dice ~desc:"Der Fernseher hat Einbrennungen (Burn-in). Auf einfarbigen Flächen sichtbar." "Sony Bravia OLED A1 65 Zoll (KD-65A1) 4K HDR – mit Burn-in" "averia" "quemado";
  dice ~desc:"Er hat keine Pixelfehler oder Burnin. Pixel Refresh wurde gemacht." "LG OLED 4k 48 ZOLL" "estado" "usado";
  dice ~desc:"Der Bildschirm und das Gehäuse haben keinerlei Kratzer, Pixelfehler oder sonstiges." "Samsung 75 Zoll QLED 4K Smart TV" "estado" "usado";
  dice ~desc:"en una esquina de las patas tiene una pequeña rotura, lo cual no afecta" "Smart TV Samsung 65 4K UE65TU8506UXXC" "estado" "usado";
  dice "Smart TV LG 55UJ620V 4k - Para REPARAR Backlight" "averia" "retroiluminacion";
  dice ~desc:"Beim Einschalten bleibt der Bildschirm schwarz. Verkauf als defekt für Bastler" "Hisense 58A6FG" "estado" "para-piezas";
  es "Xiaomi TV F 43 Zoll – NEU & OVP – Ungeöffnet und versiegelt" "tv Xiaomi TV F 43 43 - precintado";
  es "SMART TV 55\"LG 55MRGB87B6B RGB MINI LED UHD 4K A ESTRENAR" "tv - 55 rgb-mini-led nuevo";
  es "Samsung 55 Zoll Neo QLED – B-Ware" "tv - 55 mini-led como-nuevo";
  (* Rota manda sobre nueva (run-local de la app, 2026-10-23: https://es.wallapop.com/item/tv-tcl-75p8l-1298363631, 225 €) *)
  es ~cat:"TVs" ~precio:"225" "TV TCL 75P8L Nueva Rota." "tv TCL 75P8L 75 led averiado";
  dice "TV TCL 75P8L Nueva Rota." "averia" "pantalla rota";
  dice "Samsung 55 pulgadas nueva, pantalla rota" "estado" "averiado";
  dice "Televisor Hisense 55 pulgadas nuevo defectuoso" "estado" "averiado";
  dice "Televisor LG 55 pulgadas a estrenar, no funciona" "estado" "averiado";
  dice "Televisore Samsung 55 pollici rotto" "averia" "pantalla rota";
  dice "Televisor LG 50 polegadas ecrã partido" "averia" "pantalla rota";
  dice "Samsung Fernseher 55 Zoll kaputt" "estado" "averiado";
  dice "Téléviseur LG 55 pouces écran cassé" "averia" "pantalla rota";
  dice "TV Xiaomi 55 pulgadas golpe en la esquina" "estado" "averiado";
  dice "TV Sony 65 pulgadas neu, defekt" "estado" "averiado";
  dice ~desc:"Televisor Xiaomi TV F Pro con pantalla de 75 pulgadas. 5 unidades rotas 100€" "4 Xiaomi TV y 1 sony v" "averia" "pantalla rota";
  dice ~desc:"Tiene el botón roto y renicia sola la vendo así." "TV Samsung 55 crystal UHD" "estado" "averiado";
  dice ~desc:"El televisor enciende y se puede ver. Muy de vez en cuando se reinicia sola." "Xiaomi Mi TV 4S 55 4K UHD" "estado" "averiado";
  (* Lo roto que no es la tele, en la descripción, no es una avería *)
  dice ~desc:"Incluye mando original aunque tiene la tapa de las pilas rota. Funcionando perfectamente." "Televisor Sony Bravia 19 pulgadas" "estado" "usado";
  dice ~desc:"Funciona perfecta y no tiene golpes, rasguños o nada parecido." "TV LG 65 Pulgadas 4K" "estado" "usado";
  dice ~desc:"Keine Mängel / Defekte bekannt." "Samsung 50 Zoll 4K Smart TV" "estado" "usado";
  (* Lo que dice de sí mismo *)
  dice ~desc:"Privatverkauf, keine Garantie und Rücknahme." "Samsung 55 Zoll TV" "garantia" "false";
  dice "Sony BRAVIA XR-98X90L 98 Zoll 4K TV – Rechnung + Garantie" "garantia" "true";
  dice "Sony BRAVIA XR-98X90L 98 Zoll 4K TV – Rechnung + Garantie" "factura" "true";
  dice "Samsung QD-OLED S95C 55 Zoll 4K TV mit Rest Garantie und OVP" "caja" "true";
  dice ~desc:"Nur Abholung in Köln." "LG 65 Zoll 4K Fernseher" "solo_recogida" "true";
  dice ~desc:"Nur Abholung in Köln." "LG 65 Zoll 4K Fernseher" "envio" "false";
  dice ~desc:"Hago envíos a toda España." "TV LG 65 pulgadas" "envio" "true";
  dice ~desc:"No acepto cambios." "TV LG 65 pulgadas" "cambio" "false";
  dice ~precio:"1.499 € VB" "LG OLED77C5" "precio" "1499";
  dice "LG OLED77C6ELB" "precio" "-";
  dice "LG OLED77C6ELB" "precio_nuevo" "2249";
  (* Lo que no es una tele *)
  tipo ~cat:"Other TV & projector accessories" "Main Board TV LG EAX69830902" "pieza";
  tipo "Placa Base Hisense 65U8NQ - RSAG7-820-13493" "pieza";
  tipo "Placa T-CON Philips 42PFL6007H/12" "pieza";
  tipo "Despiece TV Samsung UE50BU8000K" "pieza";
  tipo "Panel TV Samsung UE65AU9005K" "pieza";
  tipo "Juego de Leds TCL 65Q6C - 40-GFKCL2-DLC1AG" "pieza";
  tipo "Mando a distancia Samsung Smart TV" "accesorio";
  tipo "Amazon Fire TV Stick 4K Select" "accesorio";
  tipo "Xiaomi TV Stick 4K" "accesorio";
  tipo "TV Box H20 PRO 4K Ultra HD, NUEVO" "accesorio";
  tipo "Soporte de Pared para TV hasta 75 pulgadas" "accesorio";
  tipo "Universal TV Standfuß Tischständer Halterung Fernseher bis85 Zoll" "accesorio";
  tipo "Original LG Wandhalterung für z.B. 77 Zoll TVs" "accesorio";
  tipo "Philips Hue Play Gradient Lightstrip für 75-85 Zoll TV" "accesorio";
  tipo ~cat:"Remote controls" "Medidor remoto MT75" "otro";
  tipo ~cat:"Remote controls" "Telecomando universale" "accesorio";
  tipo "Proyector Hisense PT1 Tiro Corto + Pantalla 100”" "proyector";
  tipo "Xiaomi Mi Smart Compact Projector" "proyector";
  tipo "Monitor Gaming Philips Evnia 49 QD-OLED" "monitor";
  tipo "Samsung Smart Monitor M7 - 4K - 43 Zoll | Monitor & Smart-TV" "monitor";
  tipo "Reproductor Blu-ray 4K Panasonic DMP-UB300EGK" "otro";
  tipo "Laserdisc Demolition Man" "otro";
  tipo "Lote de 3 Televisores (2 Sony, 1 LG)" "lote";
  tipo "2 Televisores 32\" Samsung y LG para despiece" "lote";
  tipo "TCL Fernseher und Toshiba Fernseher" "lote";
  tipo "SUCHE Röhrenfernseher klein !" "busca";
  tipo "TV-Bildschirm Bang & Olufsen BeoVision 4 -37" "tv";
  tipo "Sony Bravia 47 Zoll (119 cm) Full HD (Ohne Fernbedienung)" "tv";
  (* Una tele sin tamaño, no un mando: defecto por las pulgadas. *)
  defecto "Samsung Fernseher mit Fernbedienung und HDMI Kabel voll funk" "no dice las pulgadas";
  tipo "SEG 28\"Röhrenfernseher RGB" "tv";
  (* Defectos *)
  defecto ~cat:"TVs" "Televisión Philips" "no dice las pulgadas";
  defecto "Samsung TV 55,65,75,85 Zoll Neo Qled,Oled,4K,8K,TV-Lagerverkauf✅" "varias pulgadas";
  defecto "Loewe inspire 65 dr+ TV inklusive Klangbar i (Auch in der Größe 55 und 48 Zoll verfügbar Neu)" "varias pulgadas";
  defecto ~cat:"Fernseher" "CHAMPIONS LEAGUE / SKY DAZN NETFLIX co UNBEGRENZTER ZUGANG" "no sé si es una tele";
  defecto "" "sin título";
  (* La semilla entera: las invariantes y lo que lee sin LLM *)
  let tipos = [ "tv"; "monitor"; "proyector"; "accesorio"; "pieza"; "lote"; "busca"; "otro" ] in
  let tecs = [ "oled"; "qd-oled"; "mini-led"; "rgb-mini-led"; "qled"; "led"; "-" ] in
  let estados = [ "precintado"; "nuevo"; "como-nuevo"; "usado"; "averiado"; "para-piezas" ] in
  let ic = open_in "anuncios.jsonl" in
  let total = ref 0 and leidos = ref 0 in
  (try
     while true do
       let j = Yojson.Safe.from_string (input_line ic) in
       let s k = match Yojson.Safe.Util.member k j with `String s -> s | `Float f -> Printf.sprintf "%g" f | `Int i -> string_of_int i | _ -> "" in
       incr total;
       let e = entrada ~cat:(s "categoria") ~desc:(s "descripcion") ~precio:(s "precio") (s "titulo") in
       match lee e with
       | Ok o ->
         incr leidos;
         let t = texto o "tipo" in
         if not (List.mem t tipos) then falla "%S: tipo %s" (s "titulo") t;
         if not (List.mem (texto o "tecnologia") tecs) then falla "%S: tecnologia %s" (s "titulo") (texto o "tecnologia");
         if not (List.mem (texto o "estado") estados) then falla "%S: estado %s" (s "titulo") (texto o "estado");
         (match campo o "pulgadas" with
          | `Int p -> if p < 13 || p > 120 then falla "%S: pulgadas %d" (s "titulo") p
          | `Null -> if t = "tv" then falla "%S: tele sin pulgadas" (s "titulo")
          | _ -> falla "%S: pulgadas no es un entero" (s "titulo"));
         (match campo o "modelo" with
          | `String m -> if texto o "marca" = "-" then falla "%S: modelo %s sin marca" (s "titulo") m
          | _ -> ());
         List.iter
           (fun k -> if not (List.mem_assoc k (match o with `Assoc l -> l | _ -> [])) then falla "%S: falta %s" (s "titulo") k)
           [ "tipo"; "marca"; "modelo"; "serie"; "anio"; "pulgadas"; "tecnologia"; "resolucion"; "hz"; "hdmi21"; "sistema"; "gama";
             "precio_lanzamiento"; "estado"; "averia"; "garantia"; "factura"; "caja"; "envio"; "solo_recogida"; "cambio"; "precio" ]
       | Error _ -> ()
     done
   with End_of_file -> ());
  (* 1.084 de 1.181 el 2026-10-23: la red no deja que baje. *)
  if !leidos < 1080 then falla "la semilla: %d de %d sin defecto (eran 1.084)" !leidos !total;
  if !fallos > 0 then (Printf.eprintf "%d fallos\n" !fallos; exit 1)
