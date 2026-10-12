(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Red cristalina de nvme-noticia: titulares reales de SEMILLA.md (RSS del
   2026-10-12) con su tema, su tipo, su segmento, los modelos del catálogo y
   lo nuevo. *)

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let lista j k = match j with `Assoc l -> (match List.assoc_opt k l with Some (`List xs) -> List.map (function `String s -> s | _ -> "?") xs | _ -> []) | _ -> []
let campo j k = match j with `Assoc l -> (match List.assoc_opt k l with Some (`String s) -> s | _ -> "?") | _ -> "?"

let comprueba ?(resumen = "") ?(segmento = "") ?(modelos = []) ?(nuevos = []) titulo (tema, tipo) =
  match Nvme_noticia.aplicar ("Título: " ^ titulo ^ if resumen = "" then "" else "\nResumen: " ^ resumen) with
  | Error m -> falla "%S: defecto «%s»" titulo m
  | Ok s ->
    let j = Yojson.Safe.from_string s in
    if campo j "tema" <> tema || campo j "tipo" <> tipo || lista j "modelos" <> modelos || lista j "nuevos" <> nuevos
       || (segmento <> "" && campo j "segmento" <> segmento)
    then
      falla "%S: %s %s %s [%s] nuevos [%s]; se esperaba %s %s %s [%s] [%s]" titulo (campo j "tema") (campo j "tipo") (campo j "segmento")
        (String.concat "," (lista j "modelos")) (String.concat "," (lista j "nuevos")) tema tipo segmento (String.concat "," modelos)
        (String.concat "," nuevos)

let () =
  (* TechPowerUp, Tom's Hardware *)
  comprueba "(PR) Kioxia Announces E1.L QLC-Based SSD Designed for Hyperscale Data Centers" ~segmento:"enterprise" ("ssd", "anuncio");
  comprueba "(PR) KIOXIA Introduces Direct Liquid Cooling Support for Enterprise SSDs" ~segmento:"enterprise" ("ssd", "anuncio");
  comprueba "Kioxia LD4 E1.L QLC NVMe SSD Announced" ~nuevos:[ "kioxia ld4" ] ("ssd", "anuncio");
  comprueba "Grab Biwin Black Opal NV7400 M.2 NVMe SSD in Our Exclusive Prime Day Deal: Up to 28% Off!" ~segmento:"consumo" ~nuevos:[ "biwin nv7400" ] ("ssd", "precio");
  comprueba "Sandisk NAS 800 1.92TB SSD Review: Endurance at a premium" ("ssd", "analisis");
  comprueba "(PR) Icy Dock Releases EXLink MB308A5 PCIe 5.0 x16 NVMe Host Adapter Card" ("ssd", "lanzamiento");
  comprueba "Microsoft 365 Cuts Family OneDrive Storage from 6 TB to 2 TB" ("otro", "otro");
  comprueba "Microsoft 365 slashes storage capacity for shared accounts amid industry-wide shortages" ("otro", "otro");
  comprueba "Samsung HBM4E Passes Testing for NVIDIA's \"Rubin Ultra\" GPU" ("otro", "otro");
  comprueba "SK hynix Reportedly Faces Difficulties in HBM Hybrid Bonding, Trailing Samsung" ("otro", "otro");
  comprueba "NVIDIA Releases GeForce 617.42 WHQL Game Ready Drivers" ("otro", "otro");
  comprueba "AMD CEO Visits Samsung for HBM, Samsung Wants Foundry Orders in Return" ("otro", "otro");
  (* StorageReview, ServeTheHome, TweakTown *)
  comprueba "KIOXIA CM9-DLC Brings Direct Liquid Cooling to Dual-Port E3.S SSDs up to 30.72TB" ~segmento:"enterprise" ~nuevos:[ "kioxia cm9" ] ("ssd", "lanzamiento");
  comprueba "KIOXIA LD4 Brings QLC to E1.L for 1U Servers, Sampling at 30.72TB With a Path to 122.88TB" ~nuevos:[ "kioxia ld4" ] ("ssd", "lanzamiento");
  comprueba "Seagate and Toshiba Reportedly Pursue TDK HDD Head Business as Nearline Demand Accelerates" ("almacenamiento", "rumor");
  comprueba "Xinnor xiRAID Classic 4.4.1 Adds NVMe Discard Support and Multipath RAID Members" ("ssd", "anuncio");
  comprueba "Podcast #154: Oregon State’s Chris Sullivan on 122TB SSDs at Sea, Spotted Owls, and AI as a Data Problem" ("ssd", "analisis");
  comprueba "KIOXIA brings Direct Liquid Cooling to enterprise SSDs with new CM9 Series" ("ssd", "lanzamiento");
  comprueba "Best Mini PCs in 2026: Lab-Tested Leaderboard" ("otro", "otro");
  comprueba "NVIDIA DGX Spark 64GB Lands October 23 at $4,999, and Two Units Cluster to 128GB Over ConnectX-7" ("otro", "otro");
  (* Blocks & Files *)
  comprueba "Kioxia doubles super-fast flash drive speed" ("ssd", "otro");
  comprueba "A look at DapuStor’s combined SLC and QLC SSD" ("ssd", "otro");
  comprueba "Distant third HDD maker Toshiba spending $380 million to catch up" ("almacenamiento", "mercado");
  comprueba "US Listing? Me too says Kioxia" ("ssd", "mercado");
  comprueba "SK Hynix considering US Solidigm fab" ("ssd", "rumor");
  comprueba "Memory gold rush bonanza makes billions for Micron" ("otro", "otro");
  comprueba "IDC’s latest enterprise storage tracker shows booming storage market growth" ~segmento:"enterprise" ("almacenamiento", "mercado");
  comprueba "Micron and Netlist settle memory patent dispute" ("otro", "otro");
  (* ComputerBase, PCGH, HardZone, El Chapuzas *)
  comprueba "Seagate Expansion: Externe HDDs im neuen Gewand mit USB-C und 30 TB" ("almacenamiento", "otro");
  comprueba "Microsoft 365 Family & Premium: Beim OneDrive-Speicher gilt jetzt „6 × 1 TB = 2 TB“" ("otro", "otro");
  comprueba "RDNA 5: Neue Radeon-GPUs noch in weiter Ferne und keine Änderung am GDDR7-Speicher [Gerücht]" ("otro", "otro");
  comprueba "¿Tiene sentido seguir comprando discos duros HDD en 2026?" ("almacenamiento", "otro");
  comprueba "La CPU, RAM y SSD ya supone el 68% del coste de un portátil de 900 euros" ("ssd", "precio");
  comprueba "Samsung: One UI 9.0 mit Android 17 für Galaxy S24 und Galaxy A57 gestartet" ("otro", "otro");
  (* con modelos del catálogo *)
  comprueba "Samsung 990 Pro 4TB drops to its lowest price ever" ~modelos:[ "samsung-990-pro" ] ~segmento:"consumo" ("ssd", "precio");
  comprueba "WD Black SN850X review: still the PCIe 4.0 SSD to beat" ~modelos:[ "wd-black-sn850x" ] ("ssd", "analisis");
  comprueba "Micron 7450 MAX U.3 6.4TB tested" ~modelos:[ "micron-7450-max" ] ~segmento:"enterprise" ("ssd", "analisis")

(* Sin «Título:», el titular entero. *)
let () = match Nvme_noticia.aplicar "Crucial T710 2TB review" with Ok _ -> () | Error m -> falla "sin «Título:»: %s" m

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de nvme-noticia\n" !fallos;
    exit 1)
