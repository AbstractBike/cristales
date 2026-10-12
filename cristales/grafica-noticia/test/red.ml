(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de grafica-noticia: titulares reales de SEMILLA.md (RSS del
   2026-10-12) con su tema, su tipo, los modelos del catálogo y lo nuevo. *)

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let lista j k = match j with `Assoc l -> (match List.assoc_opt k l with Some (`List xs) -> List.map (function `String s -> s | _ -> "?") xs | _ -> []) | _ -> []
let campo j k = match j with `Assoc l -> (match List.assoc_opt k l with Some (`String s) -> s | _ -> "?") | _ -> "?"

let comprueba ?(resumen = "") titulo ?(modelos = []) ?(nuevos = []) (tema, tipo) =
  match Grafica_noticia.aplicar ("Título: " ^ titulo ^ if resumen = "" then "" else "\nResumen: " ^ resumen) with
  | Error m -> falla "%S: defecto «%s»" titulo m
  | Ok s ->
    let j = Yojson.Safe.from_string s in
    if campo j "tema" <> tema || campo j "tipo" <> tipo || lista j "modelos" <> modelos || lista j "nuevos" <> nuevos then
      falla "%S: %s %s [%s] nuevos [%s]; se esperaba %s %s [%s] [%s]" titulo (campo j "tema") (campo j "tipo")
        (String.concat "," (lista j "modelos")) (String.concat "," (lista j "nuevos")) tema tipo (String.concat "," modelos) (String.concat "," nuevos)

let () =
  comprueba "AMD RDNA 5 Likely Scheduled for Second Half of 2027" ("graficas", "rumor");
  comprueba "(PR) INNO3D Announces AGS-4UMGX-R1 4U GPU Server With NVIDIA MGX" ("otro", "otro");
  comprueba "AMD Reportedly Raises GDDR6 Prices for Board Partners" ("graficas", "rumor");
  comprueba "NVIDIA Reportedly Ending the RTX 5090, Reserves GB202 Silicon for Workstation GPUs" ~modelos:[ "rtx-5090" ] ("graficas", "rumor");
  comprueba "NVIDIA Throws RTX Spark Launch Party in Berlin on October 16. You Can Be There, it's Public" ("otro", "otro");
  comprueba "AMD GPUs Get Price Hike in China with International Increases To Follow" ("graficas", "precio");
  comprueba "(PR) Alphacool Launches ES 1-Slot GPU Cooler for Blackwell and Radeon AI PRO GPUs" ("otro", "otro");
  comprueba "NVIDIA Releases GeForce 617.42 WHQL Game Ready Drivers" ("graficas", "drivers");
  comprueba "La GeForce RTX 5080 24 GB, el reemplazo de la RTX 5090, llegaría a principios de 2027"
    ~modelos:[ "rtx-5080"; "rtx-5090" ] ~nuevos:[ "rtx-5080 24gb" ] ("graficas", "rumor");
  comprueba "NVIDIA habría dejado de fabricar su GeForce RTX 5090; se reemplazaría por una RTX 5080 24 GB"
    ~modelos:[ "rtx-5090"; "rtx-5080" ] ~nuevos:[ "rtx-5080 24gb" ] ("graficas", "rumor");
  comprueba "AMD lanzaría una única GPU RDNA 5 en todo 2027, y eso, en el mejor de los casos" ("graficas", "rumor");
  comprueba "Kaum noch Lagerware: Die Nvidia GeForce RTX 5090 soll „EOL“ sein (Update)" ~modelos:[ "rtx-5090" ] ("graficas", "rumor");
  comprueba "RTX Spark: Nvidia lädt Interessenten am 16. Oktober zur „Launch Celebration“" ("otro", "otro");
  comprueba "Nvidia reportedly halts GeForce RTX 5090 production in favor of AI data center and professional GPUs" ~modelos:[ "rtx-5090" ] ("graficas", "rumor");
  comprueba "Walmart has slashed $750 off this RTX 5060 gaming laptop, now 40% cheaper" ("otro", "otro");
  comprueba "NVIDIA RTX 5080 24 GB GPU Expected To Arrive In Q1 2027 As The New Flagship Blackwell GeForce GPU"
    ~modelos:[ "rtx-5080" ] ~nuevos:[ "rtx-5080 24gb" ] ("graficas", "rumor");
  comprueba "AMD Rumored To Launch RDNA 5 In Second Half Of 2027; Also Quashes Rumors Of Next-Gen Using 4 GB GDDR7 Memory" ("graficas", "rumor");
  comprueba "Multiple Intel CPU Families Witness 15-20% Price Hike While AMD Is Also Expected To Raise CPU Prices Soon" ("otro", "otro");
  comprueba "RDNA 5: Neue Radeon-GPUs noch in weiter Ferne und keine Änderung am GDDR7-Speicher [Gerücht]" ("graficas", "rumor");
  comprueba "Lokale KI auf der RTX 3060: Kostenloses Tool verspricht schnellere Verarbeitung" ~modelos:[ "rtx-3060" ] ("graficas", "otro");
  comprueba "[PLUS] Leistungsaufnahme von 500 Grafikkarten seit 2009: Von unter 200 bis über 600 Watt" ("graficas", "otro");
  comprueba "¿Qué ocurre cuando tu gráfica se queda sin VRAM libre?" ("graficas", "otro");
  comprueba "Microsoft Surface Laptop mit Nvidia RTX Spark: High-End-Modell mit 128 GiB RAM bereits ausverkauft" ("otro", "otro");
  comprueba "Arc Raiders Jumps to Six-Month High Player Count With 2.0 Update and Free Weekend" ("otro", "otro");
  comprueba "Samsung HBM4E Passes Testing for NVIDIA's \"Rubin Ultra\" GPU" ("otro", "otro");
  comprueba "AMD B650 Chipset Arrives on a $58 PCIe Expansion Card From JGINYUE" ("otro", "otro");
  comprueba "Coder creates NvidiaWatch tracker site that monitors hundreds of GPU driver bugs" ("graficas", "drivers");
  comprueba "The RTX 5060-Powered Acer Nitro V16 Gaming Laptop Comes With Double The Standard RAM At 32GB" ("otro", "otro");
  (* Los tipos que no salen en la muestra del día. *)
  comprueba "NVIDIA GeForce RTX 5070 Ti Founders Edition Review" ~modelos:[ "rtx-5070-ti" ] ("graficas", "analisis");
  comprueba "AMD Radeon RX 9070 XT now available at $599" ~modelos:[ "rx-9070-xt" ] ("graficas", "lanzamiento");
  comprueba "(PR) Intel Announces Arc B580 Limited Edition" ~modelos:[ "arc-b580" ] ("graficas", "anuncio");
  comprueba "La RTX 4070 Super cae a 549 euros en PcComponentes" ~modelos:[ "rtx-4070-super" ] ("graficas", "precio");
  comprueba "Intel Arc B770 spotted in shipping manifests" ~nuevos:[ "arc b770" ] ("graficas", "rumor");
  (* El resumen suma modelos cuando el título ya va de gráficas. *)
  comprueba "New GeForce driver fixes stutter" ~resumen:"The 617.50 hotfix addresses issues on RTX 4090 and RTX 5090." ~modelos:[ "rtx-4090"; "rtx-5090" ] ("graficas", "drivers")

(* Lo dudoso: defecto. *)
let () =
  match Grafica_noticia.aplicar "AMD Confirms FSR 4 Is Coming to APUs by the End of 2026" with
  | Error _ -> ()
  | Ok s -> falla "APUs con FSR: debía ser defecto y dio %s" s

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de grafica-noticia\n" !fallos;
    exit 1)
