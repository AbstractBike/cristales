(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: qué se vende en un anuncio de segunda mano de discos y
   componentes. Ver SEMILLA.md.

   La entrada es la de grafica-anuncio («Título: …», «Categoría: …»,
   «Descripción: …»; sin «Título:», todo es el título), y se lee con su
   [partes]. Lo que es (un SSD NVMe suelto, un SATA, un disco duro, un PC,
   una caja sin disco, un adaptador, un lote, alguien que busca) se decide por
   el título y la categoría, mirando qué va antes: «PC Gaming + 1TB NVMe» es un
   PC; «Samsung 990 Pro + caja USB-C», un SSD. La descripción da el estado y la
   salud (horas, TB escritos, % de vida, SMART), y el modelo si el título no lo
   dice. *)

open Nvme_modelo
module G = Grafica_modelo.Texto

type tipo = Ssd | Sata | Hdd | Externo | Caja | Adaptador | Pc | Portatil | Consola | Componente | Lote | Busca | Otro

let tipo_texto = function
  | Ssd -> "ssd" | Sata -> "sata" | Hdd -> "hdd" | Externo -> "externo" | Caja -> "caja" | Adaptador -> "adaptador" | Pc -> "pc"
  | Portatil -> "portatil" | Consola -> "consola" | Componente -> "componente" | Lote -> "lote" | Busca -> "busca" | Otro -> "otro"

(* --- palabras de cada cosa (plegadas) ------------------------------------ *)

let busca = [ "busco"; "compro"; "buscando"; "suche"; "ich suche"; "wtb"; "looking for"; "cerco"; "procuro"; "kaufe"; "ankauf"; "compramos"; "wir kaufen"; "we buy" ]

let lote = [ "lote"; "lotes"; "pack"; "paket"; "konvolut"; "bundle"; "set aus"; "sammlung"; "posten" ]

(* «2x verfügbar», «3 disponibles»: varias unidades sueltas, no un lote. *)
let sueltas = [ "verfugbar"; "vorhanden"; "disponibles"; "disponible"; "available"; "einzeln"; "por separado"; "separately" ]

let disco =
  [ "ssd"; "ssds"; "nvme"; "nvm"; "mvme"; "nmve"; "m 2"; "u 2"; "u 3"; "festplatte"; "disco"; "disco duro"; "solid state"; "hdd";
    "e1 s"; "e1 l"; "e3 s"; "laufwerk" ]

let pc =
  [ "pc"; "ordenador"; "ordenadores"; "torre"; "sobremesa"; "setup"; "computer"; "computadora"; "rechner"; "komplettsystem";
    "komplett pc"; "gaming pc"; "pc gaming"; "pc gamer"; "desktop"; "workstation"; "mini pc"; "imac"; "mac mini"; "mac studio";
    "mac pro"; "nuc"; "barebone"; "all in one"; "server"; "rackserver"; "servidor"; "diskstation"; "synology"; "qnap"; "raspberry";
    "tablet"; "ipad"; "equipo"; "thin client"; "thinclient"; "prodesk"; "elitedesk"; "optiplex"; "thinkcentre" ]

let portatil =
  [ "portatil"; "portatiles"; "laptop"; "notebook"; "netbook"; "macbook"; "chromebook"; "ultrabook"; "thinkpad"; "elitebook";
    "probook"; "latitude"; "ideapad"; "yoga"; "vivobook"; "zenbook"; "legion"; "victus"; "pavilion"; "envy"; "xps"; "zephyrus";
    "aspire"; "inspiron"; "galaxy book"; "dragonfly"; "surface"; "nitro v15"; "nitro 5"; "predator helios"; "rog strix g"; "tuf a15";
    "msi thin"; "omen 16"; "omen 17"; "gaming laptop" ]

let consola = [ "consola"; "konsole"; "console"; "xbox"; "playstation"; "ps5"; "ps4"; "nintendo"; "switch"; "steam deck"; "rog ally" ]

let componente =
  [ "placa base"; "placa madre"; "placa"; "mainboard"; "motherboard"; "cpu"; "procesador"; "prozessor"; "ram"; "ddr4"; "ddr5";
    "netzteil"; "fuente"; "grafikkarte"; "tarjeta grafica"; "grafica"; "gpu"; "rtx"; "gtx"; "radeon"; "monitor"; "am4"; "am5";
    "lga1700"; "atx"; "matx"; "kit"; "combo"; "lufter"; "ventilador"; "teclado"; "raton"; "router" ]

let adaptador =
  [ "adapter"; "adaptador"; "adaptor"; "adattatore"; "hyper m 2"; "riser"; "caddy"; "rahmen"; "einbaurahmen"; "carrier"; "shuttle";
    "verlangerung"; "extension"; "pcie karte"; "pcie card"; "host adapter"; "tarjeta pcie"; "expansion card"; "slimsas"; "oculink";
    "kabel"; "cable"; "heatsink"; "disipador"; "kuhlkorper"; "kuehlkoerper"; "soporte"; "bracket"; "schrauben"; "tornillos";
    "standoff"; "thermal pad"; "warmeleitpad"; "backplate" ]

let caja = [ "carcasa"; "gehause"; "enclosure"; "case"; "caja externa"; "dock"; "docking"; "dockingstation"; "box usb"; "ssd box" ]

let externo =
  [ "extern"; "externe"; "externes"; "externa"; "externo"; "external"; "portable"; "portatil ssd"; "ssd portatil"; "usb"; "usb c";
    "usb 3"; "usb4"; "thunderbolt"; "expansion"; "my passport"; "t7"; "t9"; "t5"; "x9"; "x10"; "ex400u"; "extreme portable" ]

let hdd =
  [ "hdd"; "rpm"; "7200"; "7200rpm"; "5400rpm"; "7 2k"; "ironwolf"; "barracuda"; "exos"; "skyhawk"; "wd purple"; "wd gold";
    "wd red pro"; "wd red plus"; "toshiba n300"; "mg08"; "mg09"; "3 5 zoll"; "disco duro externo"; "hgst" ]

let para = [ "para"; "for"; "fur"; "per"; "pour"; "compatible"; "kompatibel"; "fits"; "passend"; "de"; "aus"; "from"; "von" ]

let averiada_disco =
  [ "no detecta"; "no reconoce"; "nicht erkannt"; "wird nicht erkannt"; "not detected"; "solo lectura"; "read only"; "readonly";
    "schreibgeschutzt"; "sectores defectuosos"; "bad sectors"; "fehlerhafte sektoren"; "firmware bug"; "smart fehler"; "smart error" ]

let garantia = [ "garantia"; "garantie"; "warranty"; "garanzia"; "gewahrleistung"; "herstellergarantie" ]
let factura = [ "factura"; "rechnung"; "invoice"; "fattura"; "ticket de compra"; "kaufbeleg"; "receipt"; "kassenbon" ]
let caja_original = [ "ovp"; "caja original"; "con caja"; "con su caja"; "en su caja"; "original box"; "originalverpackung"; "verpackung"; "blister"; "embalaje original"; "precintado"; "versiegelt" ]
let disipador = [ "heatsink"; "disipador"; "kuhlkorper"; "kuehlkoerper"; "kuhler" ]
let cambio = [ "cambio"; "cambiaria"; "intercambio"; "tausch"; "tausche"; "swap"; "trade"; "scambio"; "troca" ]
let negaciones = [ "sin"; "no"; "nunca"; "ningun"; "ninguna"; "nada"; "never"; "not"; "nie"; "kein"; "keine"; "keinen"; "ohne"; "without"; "nicht"; "senza"; "sem"; "nao" ]

let categoria_portatil = [ "laptops"; "gaming laptops"; "portatiles" ]
let categoria_pc = [ "desktop computers"; "gaming desktops"; "ordenadores de sobremesa"; "tablets" ]
let categoria_consola = [ "consoles" ] (* exacta: «Accessories & spare parts for consoles» son accesorios *)

(* --- salud ----------------------------------------------------------------- *)

let palabras_de texto = Array.of_list (Texto.palabras_plegadas (G.reemplaza_todo "%" " pct " texto))
let es_numero w = w <> "" && String.for_all G.es_cifra w

let salud_vida = [ "health"; "salud"; "gesundheit"; "zustand"; "vida"; "life"; "restlebensdauer"; "lebensdauer"; "estado"; "condition"; "smart"; "ok"; "gut"; "good"; "remaining"; "restante"; "zustandswert" ]
let salud_desgaste = [ "verschleiss"; "wear"; "desgaste"; "abnutzung"; "used"; "usado"; "genutzt"; "abgenutzt"; "verbraucht"; "wearout"; "wearlevel" ]

(** El % de vida que dice: «100% Health», «0% Verschleiß» (100), «Restlebensdauer 98 %». *)
let vida texto =
  let ws = palabras_de texto in
  let n = Array.length ws in
  let rango a b = List.filter_map (fun k -> if k >= 0 && k < n then Some ws.(k) else None) (List.init (b - a + 1) (fun d -> a + d)) in
  let r = ref None in
  for i = 0 to n - 2 do
    if !r = None && es_numero ws.(i) && String.length ws.(i) <= 3 && ws.(i + 1) = "pct" then begin
      let v = int_of_string ws.(i) in
      (* La palabra más cercana decide: «100% Zustand (kaum genutzt)» es vida, no desgaste. *)
      let cerca = List.concat_map (fun d -> rango (i + 1 + d) (i + 1 + d) @ rango (i - d) (i - d)) [ 1; 2; 3 ] in
      if v <= 100 then
        match List.find_opt (fun w -> List.mem w salud_desgaste || List.mem w salud_vida) cerca with
        | Some w when List.mem w salud_desgaste -> r := Some (100 - v)
        | Some _ -> r := Some (if v = 0 then 100 else v)
        | None -> ()
    end
  done;
  !r

let horas_palabras = [ "h"; "horas"; "hora"; "stunden"; "std"; "betriebsstunden"; "hours"; "hrs"; "poh"; "laufzeit" ]

(** Las horas encendido: «sólo 71 horas», «1.234 Betriebsstunden», «POH: 812». *)
let horas texto =
  let ws = palabras_de texto in
  let n = Array.length ws in
  let r = ref None in
  for i = 0 to n - 1 do
    if !r = None && es_numero ws.(i) && String.length ws.(i) <= 6 then begin
      let miles = i + 1 < n && es_numero ws.(i + 1) && String.length ws.(i + 1) = 3 && String.length ws.(i) <= 3 in
      let v = if miles then (int_of_string ws.(i) * 1000) + int_of_string ws.(i + 1) else int_of_string ws.(i) in
      let sig_ = if miles then i + 2 else i + 1 in
      if (sig_ < n && List.mem ws.(sig_) horas_palabras && not (sig_ + 1 < n && ws.(sig_ + 1) = "pct"))
         || (i > 0 && List.mem ws.(i - 1) [ "betriebsstunden"; "poh"; "laufzeit" ])
      then r := Some v
    end
  done;
  !r

let escritos_palabras = [ "geschrieben"; "written"; "escritos"; "escrito"; "writes"; "write"; "beschrieben" ]

(** Los TB escritos: «12 TB geschrieben», «Host writes: 3 TB», «escritos 800 GB». *)
let escritos texto =
  let ws = palabras_de texto in
  let n = Array.length ws in
  let cantidad i =
    (* «12 tb», «12tb», «800 gb»: (TB, palabras que ocupa). *)
    let w = ws.(i) in
    let k = ref 0 in
    while !k < String.length w && G.es_cifra w.[!k] do incr k done;
    if !k = 0 then None
    else
      let num = int_of_string (String.sub w 0 (min !k 6)) in
      let suf = String.sub w !k (String.length w - !k) in
      let unidad, ocupa = if suf <> "" then (suf, 1) else if i + 1 < n then (ws.(i + 1), 2) else ("", 1) in
      match unidad with
      | "tb" | "tbw" -> Some (num, ocupa)
      | "gb" -> Some (max 1 (num / 1000), ocupa)
      | _ -> None
  in
  let r = ref None in
  for i = 0 to n - 1 do
    if !r = None then
      match cantidad i with
      | Some (v, ocupa) ->
        let despues = List.filter_map (fun k -> if k < n then Some ws.(k) else None) [ i + ocupa; i + ocupa + 1 ] in
        let antes = List.filter_map (fun k -> if k >= 0 then Some ws.(k) else None) [ i - 1; i - 2; i - 3 ] in
        if List.exists (fun w -> List.mem w escritos_palabras) (despues @ antes) then r := Some v
      | None -> ()
  done;
  !r

let smart texto =
  if G.contiene texto [ "smart ok"; "smart werte"; "smart wert"; "smart test"; "smart gut"; "smart top"; "smart perfecto"; "crystaldiskinfo"; "crystal disk info"; "smart daten"; "smart datos"; "smart status" ]
  then "si" else "?"

(* --- decidir ------------------------------------------------------------------ *)

type decision = Decide of tipo | Defecto of string

let tri = function G.Si -> "si" | G.No -> "no" | G.No_dice -> "?"

(* «2x Samsung», «3× WD», «(2 Stück)»: varias unidades en el título. *)
let varias_unidades titulo =
  let s = String.lowercase_ascii titulo in
  let n = String.length s in
  let hay = ref false in
  for i = 0 to n - 1 do
    if G.es_cifra s.[i] && (i = 0 || not (G.es_cifra s.[i - 1] || Texto.es_letra s.[i - 1] || s.[i - 1] = '.' || s.[i - 1] = ',')) then begin
      let j = ref i in
      while !j < n && G.es_cifra s.[!j] do incr j done;
      let v = int_of_string (String.sub s i (min 3 (!j - i))) in
      let k = if !j < n && s.[!j] = ' ' then !j + 1 else !j in
      let x = (k < n && s.[k] = 'x') || (k + 1 < n && s.[k] = '\xc3' && s.[k + 1] = '\x97') in
      let fin = if k < n && s.[k] = 'x' then k + 1 else k + 2 in
      if x && v >= 2 && v <= 99 && (fin >= n || not (Texto.es_letra s.[fin] || G.es_cifra s.[fin])) then hay := true
    end
  done;
  !hay || G.contiene titulo [ "2 stuck"; "3 stuck"; "4 stuck"; "2 unidades"; "3 unidades"; "2 pcs"; "3 pcs"; "2 stk"; "3 stk" ]

let antes_de a b = match (a, b) with Some i, Some j -> i < j | Some _, None -> true | None, _ -> false

(* [ws] en el título, y no detrás de «para»/«für»: «SSD para PS5» no es una consola. *)
let pos_propia t ws =
  match Texto.posicion t ws with
  | Some i ->
    let palabras = Texto.palabras_plegadas t in
    if i > 0 && List.mem (List.nth palabras (i - 1)) para then None else Some i
  | None -> None

let decidir (a : Grafica_anuncio.anuncio) (l : lectura) =
  let t = a.titulo in
  let cat ws = G.contiene a.categoria ws in
  let pos_modelo = Texto.primer_modelo t in
  let pos_disco = match (Texto.posicion t disco, pos_modelo) with Some i, Some j -> Some (min i j) | (Some _ as x), None | None, x -> x in
  let hay_capacidad = l.capacidades <> [] in
  let hay_modelo = l.modelos <> [] in
  let primero ws = antes_de (pos_propia t ws) pos_disco in
  let nvme_dicho = l.interfaz.nvme || l.interfaz.pcie <> None || (match l.formato with Some ("u2" | "u3" | "e1s" | "e1l" | "e3s") -> true | _ -> false) in
  if Option.fold ~none:false ~some:(fun i -> i <= 2) (Texto.posicion t busca) then Decide Busca
  else if Texto.posicion t lote = Some 0 then Decide Lote
  else if (Texto.posicion t lote <> None || varias_unidades t) && (not (G.contiene t sueltas)) && not (primero pc || primero portatil) then Decide Lote
  else if primero portatil || (cat categoria_portatil && not (pos_disco = Some 0)) then Decide Portatil
  else if primero consola || (List.mem (String.trim (String.lowercase_ascii a.categoria)) categoria_consola && not (pos_disco = Some 0)) then Decide Consola
  else if primero pc || (cat categoria_pc && not (pos_disco = Some 0)) then Decide Pc
  else if primero adaptador || (Texto.posicion t adaptador <> None && (not hay_capacidad) && not hay_modelo) then Decide Adaptador
  else if primero caja || (Texto.posicion t caja <> None && (not hay_capacidad) && not hay_modelo) then Decide Caja
  else if primero componente then Decide Componente
  else if ((not hay_modelo) && G.menciona_cpu t) || G.contiene t [ "placa base"; "mainboard"; "motherboard"; "ram ddr4"; "ram ddr5" ] then
    (* Un disco con un procesador o una placa: un combo. Con un modelo del
       catálogo, el número es suyo: la P5800X no es un Ryzen 5800X. *)
    Decide (if pos_disco = None then Componente else Lote)
  else if Texto.posicion t externo <> None && (not (List.exists (fun s -> Catalogo.es_nvme s.modelo) l.modelos)) && not (G.contiene t caja) then
    Decide Externo
  else if Texto.posicion t hdd <> None && (not hay_modelo) && not (G.contiene t [ "ssd"; "nvme"; "m 2" ] || nvme_dicho) then Decide Hdd
  else if (not hay_modelo) && G.contiene t [ "festplatte"; "disco duro" ] && (not (G.contiene t [ "ssd"; "nvme"; "m 2"; "solid state" ])) && not nvme_dicho then Decide Hdd
  else
    match (l.modelos, l.desconocidos) with
    | [ s ], _ -> Decide (if Catalogo.es_nvme s.modelo then Ssd else Sata)
    | _ :: _ :: _, _ -> Defecto ("varios modelos: " ^ String.concat ", " (List.map (fun s -> s.modelo.Catalogo.clave) l.modelos))
    | [], _ :: _ when l.interfaz.sas || (l.interfaz.sata && not nvme_dicho) -> Decide Sata
    | [], d :: _ when pos_disco <> None || hay_capacidad -> Defecto ("modelo desconocido: " ^ d)
    | [], _ ->
      if pos_disco = None && not hay_capacidad then Decide Otro
      else if l.interfaz.sas || (l.interfaz.sata && not nvme_dicho) then Decide Sata
      else if nvme_dicho || l.formato <> None then Decide Ssd
      else if G.contiene t [ "ssd" ] then Decide Sata (* un SSD sin rastro de NVMe ni de M.2: casi siempre SATA de 2,5 pulgadas *)
      else Decide Otro

let estado (a : Grafica_anuncio.anuncio) =
  if G.dice ~negaciones (a.titulo ^ "\n" ^ a.descripcion) averiada_disco = G.Si then "averiada" else Grafica_anuncio.estado a

let opt f = function Some x -> f x | None -> `Null
let str s = `String s

let nand_dicha texto =
  if G.contiene texto [ "qlc" ] then Some "qlc" else if G.contiene texto [ "tlc" ] then Some "tlc" else if G.contiene texto [ "mlc" ] then Some "mlc"
  else if G.contiene texto [ "slc" ] && not (G.contiene texto [ "slc cache"; "slc caching" ]) then Some "slc" else None

let dram_dicha texto =
  if G.contiene texto [ "dramless"; "dram less"; "sin dram"; "ohne dram"; "without dram"; "hmb"; "no dram" ] then Some "hmb"
  else if G.contiene texto [ "dram"; "dram cache"; "con dram"; "mit dram"; "with dram"; "lpddr4"; "ddr4 cache" ] then Some "dram" else None

let json (a : Grafica_anuncio.anuncio) (l : lectura) tipo : Yojson.Safe.t =
  let todo = a.titulo ^ "\n" ^ a.descripcion in
  let disco = match tipo with Ssd | Sata -> true | _ -> false in
  let s = if disco then (match l.modelos with [ s ] -> Some s | _ -> None) else None in
  let m f = match s with Some s -> f s | None -> `Null in
  let d v = if disco then v else `Null in
  let lt = leer a.titulo in
  let capacidad = match s with Some { capacidad = Some c; _ } -> Some c | _ -> (match lt.capacidades with c :: _ -> Some c | [] -> None) in
  let interfaz = match s with Some s -> Some (Catalogo.interfaz_texto s.modelo.interfaz) | None -> interfaz_texto l.interfaz in
  let formato = match s with Some s -> Some s.formato | None -> l.formato in
  let marca = match s with Some s -> Some s.modelo.marca | None -> (match lt.marcas with x :: _ -> Some x | [] -> None) in
  let segmento =
    match s with
    | Some s -> Catalogo.segmento_texto s.modelo.segmento
    | None -> if l.enterprise then "enterprise" else "consumo"
  in
  `Assoc
    [ ("tipo", str (tipo_texto tipo));
      ("modelo", m (fun s -> str s.modelo.clave));
      ("nombre", m (fun s -> str s.modelo.nombre));
      ("marca", d (opt str marca));
      ("segmento", d (str segmento));
      ("interfaz", d (opt str interfaz));
      ("formato", d (opt str formato));
      ("dram", d (match s with Some s -> str (Catalogo.dram_texto s.modelo.dram) | None -> opt str (dram_dicha todo)));
      ("nand", d (match s with Some s -> str (Catalogo.nand_texto s.modelo.nand) | None -> opt str (nand_dicha todo)));
      ("controladora", m (fun s -> if s.modelo.controladora = "" then `Null else str s.modelo.controladora));
      ("plp", d (`Bool (match s with Some s -> s.modelo.plp | None -> G.contiene todo [ "plp"; "power loss" ])));
      ("capacidad", d (opt (fun c -> `Int c) capacidad));
      ("tbw", m (fun s -> opt (fun t -> `Int t) s.tbw));
      ("anyo", m (fun s -> `Int s.modelo.anyo));
      ("lectura", m (fun s -> opt (fun x -> `Int x) s.modelo.lectura));
      ("estado", str (estado a));
      ("horas", d (opt (fun h -> `Int h) (horas todo)));
      ("escritos", d (opt (fun h -> `Int h) (escritos todo)));
      ("vida", d (opt (fun h -> `Int h) (vida todo)));
      ("smart", str (if disco then smart todo else "?"));
      ("garantia", str (tri (G.dice ~negaciones todo garantia)));
      ("factura", str (tri (G.dice ~negaciones todo factura)));
      ("caja", str (tri (G.dice ~negaciones todo caja_original)));
      ("disipador", str (if disco && G.contiene todo disipador then "si" else "?"));
      ("cambio", str (tri (G.dice ~negaciones a.titulo cambio))) ]

(* El título manda; si no nombra modelo ni capacidad, la descripción los da. *)
let lectura_de (a : Grafica_anuncio.anuncio) =
  let lt = leer a.titulo in
  if lt.modelos <> [] || a.descripcion = "" then lt
  else
    let ld = leer a.descripcion in
    let modelos =
      match ld.modelos with
      | [ s ] -> [ (if lt.capacidades <> [] then { s with capacidad = Some (List.hd lt.capacidades); tbw = (match List.find_opt (fun (k, _) -> Texto.casi k (List.hd lt.capacidades)) s.modelo.capacidades with Some (_, t) -> t | None -> None) } else s) ]
      | _ -> []
    in
    { lt with modelos; desconocidos = (if modelos = [] then lt.desconocidos else []) }

let aplicar entrada : (string, string) result =
  let a = Grafica_anuncio.partes entrada in
  if String.trim a.titulo = "" then Error "sin título"
  else
    let l = lectura_de a in
    match decidir a l with
    | Defecto m -> Error m
    | Decide t -> Ok (Yojson.Safe.to_string (json a l t))

let cristal = Cristal.cristal "nvme-anuncio" aplicar
