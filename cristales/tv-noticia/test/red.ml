(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de tv-noticia: titulares reales de los feeds de imagen y
   sonido del 2026-10-23 (FlatpanelsHD, HDTVTest, AVForums, What Hi-Fi,
   TechRadar, Digital Trends, Xataka, AVPasión, 4kfilme, areaDVD, HDblog, Les
   Numériques, Display Daily), con su tema, tipo y modelos; las invariantes
   sobre los 623 de titulares.jsonl y lo que lee sin LLM. *)

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let campo j k = match j with `Assoc l -> (match List.assoc_opt k l with Some v -> v | None -> `Null) | _ -> `Null
let texto j k = match campo j k with `String s -> s | `List l -> String.concat "," (List.map (function `String s -> s | _ -> "?") l) | _ -> "-"
let lee e = match Tv_noticia.aplicar e with Ok s -> Ok (Yojson.Safe.from_string s) | Error m -> Error m

let es ?(resumen = "") titulo tema tipo =
  match lee ("Título: " ^ titulo ^ if resumen = "" then "" else "\nResumen: " ^ resumen) with
  | Ok j -> if texto j "tema" <> tema || texto j "tipo" <> tipo then falla "%S: %s %s, se esperaba %s %s" titulo (texto j "tema") (texto j "tipo") tema tipo
  | Error m -> falla "%S: defecto «%s», se esperaba %s %s" titulo m tema tipo

let dice titulo k esperado =
  match lee titulo with
  | Ok j -> if texto j k <> esperado then falla "%S: %s = %s, se esperaba %s" titulo k (texto j k) esperado
  | Error m -> falla "%S: defecto «%s»" titulo m

let defecto titulo = match lee titulo with Ok j -> falla "%S: %s, se esperaba defecto" titulo (Yojson.Safe.to_string j) | Error _ -> ()

let () =
  es "TCL QM7L review: the best mid-range TV of 2026" "tv" "analisis";
  dice "TCL QM7L review: the best mid-range TV of 2026" "modelos" "TCL QM7L";
  es "Review: TCL C8L / QM8L" "tv" "analisis";
  dice "Review: TCL C8L / QM8L" "modelos" "TCL C8L,TCL QM8L";
  dice "Review: Sony Bravia 9 II (True RGB)" "modelos" "Sony BRAVIA 9 II";
  dice "Review: Philips OLED811" "modelos" "Philips OLED811";
  dice "Review: Hisense U8Q (miniLED LCD)" "modelos" "Hisense U8Q";
  dice "LG C4 vs Sony BRAVIA 8 OLED TV in HDR" "modelos" "LG OLED C4,Sony BRAVIA 8";
  (* La marca de una serie es la nombrada antes: «Sony A1» no es la LG A1. *)
  dice "Review: Sony A1 OLED" "modelos" "";
  (* Lo que el catálogo aún no tiene *)
  dice "Review: Samsung S99H / S95H (QD-OLED)" "nuevos" "Samsung S99H";
  dice "Review: Samsung S99H / S95H (QD-OLED)" "modelos" "Samsung S95H";
  es "Actualité : Bon plan – Le téléviseur LG 65G6 \"5 étoiles\" à 2 456,07 €" "tv" "oferta";
  dice "Actualité : Bon plan – Le téléviseur LG 65G6 \"5 étoiles\" à 2 456,07 €" "modelos" "LG OLED G6";
  es "Roku launches Pro LX OLED TVs with higher brightness" "tv" "lanzamiento";
  es "Many TVs are about to become more expensive, warns Omdia" "tv" "precio";
  es "Panasonic returns to Canada with 2026 OLED and miniLED LCD TVs" "tv" "mercado";
  es "SkyShowtime app comes to Philips TVs with Titan OS" "tv" "software";
  es "LG Smart TVs caught listening even with the screen off" "tv" "otro";
  es "Report: Samsung to cut 'QLED' TV production by 80% – may abandon it" "tv" "mercado";
  es "Samsung QD-OLED vs Neo QLED Mini LED TV HDR Comparison" "tv" "analisis";
  dice "Samsung QD-OLED vs Neo QLED Mini LED TV HDR Comparison" "tecnologias" "qd-oled,mini-led";
  es "Sonos Beam Ultra review: one of the best compact Dolby Atmos soundbars around" "imagen-sonido" "analisis";
  es "New Apple TV 4K (4th Gen) unveiled with A19 chip, Siri AI" "imagen-sonido" "lanzamiento";
  es "La mejor barra de sonido de Samsung en 2026 se pone a precio de locos: la HW-Q990H por 479 euros" "imagen-sonido" "analisis";
  es "\"Nosferatu - Der Untote\" erscheint als 4K Ultra HD Blu-ray-Steelbook" "imagen-sonido" "lanzamiento";
  es "OLED monitor prices set to fall further" "imagen-sonido" "precio";
  es "Afectados por la Dana Adam, el Consejo de Ministros aprueba por decreto ley la incapacidad temporal por catástrofe" "otro" "otro";
  es "Adiós al juego ilimitado: Xbox Cloud Gaming empezará a cobrar por horas" "otro" "otro";
  dice "Best Android Smartphones for 2026" "tema" "otro";
  dice "Afectados por la Dana Adam" "marcas" "";
  defecto "Review: Samsung Gear VR";
  defecto "";
  let temas = [ "tv"; "imagen-sonido"; "otro" ] in
  let tipos = [ "lanzamiento"; "precio"; "oferta"; "analisis"; "software"; "mercado"; "rumor"; "otro" ] in
  let ic = open_in "titulares.jsonl" in
  let total = ref 0 and leidos = ref 0 in
  (try
     while true do
       let j = Yojson.Safe.from_string (input_line ic) in
       let s k = match Yojson.Safe.Util.member k j with `String s -> s | _ -> "" in
       incr total;
       match lee ("Título: " ^ s "titulo" ^ "\nResumen: " ^ s "resumen" ^ "\nFuente: " ^ s "feed") with
       | Ok o ->
         incr leidos;
         if not (List.mem (texto o "tema") temas) then falla "%S: tema %s" (s "titulo") (texto o "tema");
         if not (List.mem (texto o "tipo") tipos) then falla "%S: tipo %s" (s "titulo") (texto o "tipo");
         if texto o "tema" = "otro" && (texto o "tipo" <> "otro" || texto o "modelos" <> "" || texto o "marcas" <> "") then
           falla "%S: fuera de tema con tipo, modelos o marcas" (s "titulo")
       | Error _ -> ()
     done
   with End_of_file -> ());
  (* 578 de 623 el 2026-10-23. *)
  if !leidos < 575 then falla "la semilla: %d de %d sin defecto (eran 578)" !leidos !total;
  if !fallos > 0 then (Printf.eprintf "%d fallos\n" !fallos; exit 1)
