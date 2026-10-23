(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: qué se vende en un anuncio de televisores de segunda mano (y
   nuevos). Ver SEMILLA.md.

   La entrada es la de memoria-anuncio («Título: …», «Categoría: …»,
   «Precio: …», «Portal: …», «País: …», «Descripción: …» hasta el final; sin
   «Título:», todo es el título), leída con su [partes]. Lo que es (una tele,
   un monitor, un proyector, un accesorio, una pieza, un lote, alguien que
   busca) se decide por el título mirando qué va antes: «Main Board TV LG» es
   una pieza; «Mando Samsung Smart TV», un accesorio; «TV Samsung 75 pulgadas
   para piezas», una tele (para piezas); y la categoría del portal cuando el
   título no lo dice. La tele (modelo, serie, pulgadas…) la lee tv-modelo: del
   título y, lo que el título calla, de la descripción. *)

module M = Tv_modelo
module C = Tv_modelo.Catalogo
module T = Tv_modelo.Texto
module G = Grafica_modelo.Texto

type tipo = Tv | Monitor | Proyector | Accesorio | Pieza | Lote | Busca | Otro

let tipo_texto = function
  | Tv -> "tv" | Monitor -> "monitor" | Proyector -> "proyector" | Accesorio -> "accesorio" | Pieza -> "pieza" | Lote -> "lote"
  | Busca -> "busca" | Otro -> "otro"

(* --- palabras de cada cosa (plegadas) ------------------------------------------- *)

let busca =
  [ "busco"; "compro"; "buscando"; "suche"; "sucht"; "suchen"; "gesucht"; "gesuch"; "ankauf"; "kaufe"; "wtb"; "cerco"; "procuro"; "compramos";
    "wir kaufen"; "we buy"; "looking for"; "je cherche"; "cherche"; "achete"; "acquisto"; "compro tu" ]

let lote = [ "lote"; "lotes"; "lotto"; "konvolut"; "posten"; "paket"; "pack"; "mehrere"; "varios televisores"; "dos televisores"; "zwei fernseher" ]

let tele =
  [ "tv"; "tvs"; "tele"; "televisor"; "televisores"; "television"; "televisiones"; "smart tv"; "smarttv"; "fernseher"; "fernsehgerat";
    "fernsehen"; "flachbildfernseher"; "flachbild"; "flatscreen"; "flat screen"; "televisore"; "televisori"; "televisao"; "televisoes";
    "televiseur"; "televiseurs"; "pantalla plana"; "tivu"; "led tv"; "lcd tv"; "oled tv" ]

(* Piezas de una tele. «panel» solo al principio: «Panel TV Samsung» es la pieza; «TV Sony (panel roto)», no. *)
let pieza =
  [ "placa base"; "placa main"; "placa principal"; "placa madre"; "placa de video"; "placa video"; "tarjeta tcom"; "tcom"; "t com"; "main board"; "mainboard"; "main"; "x main"; "y main"; "placa t con";
    "t con"; "tcon"; "t con board"; "placa de alimentacion"; "placa alimentacion"; "fuente de alimentacion"; "fuente alimentacion";
    "power board"; "power supply"; "netzteil"; "netzteilplatine"; "psu"; "platine"; "hauptplatine"; "tira led"; "tiras led"; "leds";
    "juego de leds"; "kit de leds"; "led strips"; "led strip"; "led streifen"; "ledstreifen"; "led leiste"; "led leisten"; "backlight strips";
    "modulo wifi"; "wifi modul"; "wlan modul"; "sensor ir"; "ir sensor"; "botonera"; "lvds"; "despiece"; "ersatzteil"; "ersatzteile";
    "ricambi"; "ricambio"; "scheda madre"; "alimentatore"; "repuesto"; "repuestos"; "recambio"; "recambios"; "piezas tv"; "pecas";
    "flex"; "cable flex"; "difusor"; "difusores"; "inverter"; "inverter board" ]

let pieza_al_principio = [ "panel"; "pantalla de repuesto"; "display panel"; "panel lcd"; "panel led" ]

let accesorio =
  [ "mando"; "mandos"; "mando a distancia"; "telecomando"; "telecomandi"; "fernbedienung"; "fernbedienungen"; "remote"; "remote control";
    "control remoto"; "comando"; "soporte"; "soportes"; "wandhalterung"; "halterung"; "fernsehhalterung"; "tv halterung"; "standfuss";
    "standfusse"; "tischstandfuss"; "fuss"; "fusse"; "pie"; "pies"; "patas"; "base"; "peana"; "piedistallo"; "supporto"; "staffa"; "mount";
    "wall mount"; "bracket"; "stand"; "tv stand"; "mueble"; "mueble tv"; "mesa tv"; "tv schrank"; "fernsehschrank"; "fernsehtisch";
    "lowboard"; "tv mobel"; "wohnwand"; "fire tv stick"; "fire stick"; "firestick"; "fire tv cube"; "chromecast"; "tv box"; "android tv box";
    "android box"; "apple tv"; "mi box"; "tv stick"; "nvidia shield"; "shield tv"; "google tv streamer"; "roku"; "antena"; "antenne";
    "antenna"; "cable"; "cables"; "kabel"; "soundbar"; "barra de sonido"; "barra sonido"; "altavoz"; "altavoces"; "lautsprecher"; "receptor";
    "receiver"; "decodificador"; "decoder"; "sat receiver"; "tdt"; "sintonizador"; "gafas 3d"; "3d brille"; "transmisor"; "transmitter";
    "hue"; "lightstrip"; "sync box"; "pantalla de proyector"; "pantalla proyector"; "leinwand"; "beamer leinwand"; "lona"; "funda";
    "protector de pantalla"; "displayschutz"; "bildschirmschutz"; "one connect"; "reproductor multimedia"; "mediaplayer"; "media player";
    "streaming stick"; "iptv"; "receptor iptv"; "mesa de tv"; "mueble de tv"; "mesa television"; "mesa para tv"; "you box"; "tv box s" ]

let proyector =
  [ "proyector"; "proyectores"; "beamer"; "projector"; "proiettore"; "projetor"; "videoprojecteur"; "videoproyector"; "mini proyector";
    "laser tv"; "lasertv"; "projektor" ]

let monitor = [ "monitor"; "monitores"; "moniteur"; "bildschirm"; "pantalla interactiva"; "smart board"; "smartboard"; "digital signage"; "monitore" ]

let otro =
  [ "dvd"; "blu ray"; "bluray"; "reproductor"; "vhs"; "videograbador"; "videocassetta"; "videoregistratore"; "videorecorder";
    "videorekorder"; "laserdisc"; "betamax"; "camara"; "kamera"; "consola"; "konsole"; "playstation"; "xbox"; "nintendo"; "ps5"; "ps4";
    "radio"; "tocadiscos"; "plattenspieler"; "amplificador"; "verstarker"; "medidor"; "lampara"; "recorder"; "cassette"; "camcorder";
    "videocamara"; "cornice"; "marco digital"; "bilderrahmen"; "fotorahmen"; "photo frame" ]

let para = [ "para"; "for"; "fur"; "per"; "pour"; "compatible"; "kompatibel"; "fits"; "passend"; "passt" ]

let categoria_tv = [ "tvs"; "tv"; "fernseher"; "televisores"; "televisori"; "televisoes"; "televiseurs" ]
let categoria_accesorio = [ "remote controls"; "tv stands"; "other tv projector accessories"; "projection screens" ]
let categoria_proyector = [ "projectors" ]
let categoria_otro = [ "dvd blu ray" ]

(* --- estado ------------------------------------------------------------------------- *)

let negaciones =
  [ "sin"; "no"; "ni"; "nunca"; "ningun"; "ninguna"; "nada"; "never"; "not"; "nie"; "kein"; "keine"; "keinen"; "keinem"; "keiner"; "keinerlei";
    "ohne"; "without"; "nicht"; "senza"; "nessun"; "nessuna"; "sem"; "nenhum"; "nenhuma"; "nao"; "non"; "pas"; "sans"; "aucun"; "aucune" ]

(* «keine Pixelfehler oder Burn-in», «sin rayas ni manchas»: la negación alcanza lo que se une con «oder», «ni», «o». *)
let uniones = [ "oder"; "noch"; "o"; "ni"; "or"; "nor"; "ou" ]

let para_piezas =
  [ "para piezas"; "para despiece"; "despiece"; "for parts"; "spare parts"; "bastler"; "fur bastler"; "bastlerware"; "bastlergerat";
    "ersatzteilspender"; "als ersatzteil"; "ersatzteile"; "per pezzi"; "per ricambi"; "pezzi di ricambio"; "para pecas"; "pour pieces";
    "pieces detachees"; "para recambios"; "para repuestos" ]

let averias =
  [ ( "pantalla rota",
      [ "pantalla rota"; "pantalla partida"; "pantalla rajada"; "panel roto"; "cristal roto"; "pantalla esta rota"; "panel esta roto"; "panel interno roto"; "unidades rotas";
        "pantalla danada"; "panel danado"; "display beschadigt"; "bildschirm beschadigt"; "schermo rotto"; "schermo danneggiato"; "ecra danificado";
        "ecran endommage"; "pantalla quebrada"; "pantalla golpeada"; "golpe en pantalla"; "golpeado"; "golpeada";
        "golpe en la pantalla"; "display gebrochen"; "display kaputt"; "display defekt"; "panel defekt"; "panel kaputt"; "panelschaden";
        "panel schaden"; "displayschaden"; "bildschirm kaputt"; "bildschirm defekt"; "bildschirm gebrochen"; "glasbruch"; "gebrochen";
        "riss"; "broken screen"; "cracked screen"; "screen broken"; "cracked"; "schermo rotto"; "ecra partido"; "ecran casse";
        "fallo panel"; "fallo de panel"; "fallo en el panel" ] );
    ( "rayas",
      [ "rayas"; "raya vertical"; "raya horizontal"; "lineas verticales"; "lineas horizontales"; "linea vertical"; "linea horizontal";
        "lineas en la pantalla"; "streifen"; "linien"; "vertical lines"; "horizontal lines"; "lines on screen"; "righe"; "riscas"; "franjas" ] );
    ( "manchas",
      [ "manchas"; "mancha"; "flecken"; "fleck"; "spots"; "macchie"; "puntos blancos"; "pixel muertos"; "pixeles muertos"; "dead pixel";
        "dead pixels"; "pixelfehler"; "pixel fehler"; "clouding"; "dse" ] );
    ( "retroiluminacion",
      [ "fallo de retroiluminacion"; "fallo retroiluminacion"; "falla retroiluminacion"; "retroiluminacion rota"; "retroiluminacion fundida";
        "problema de retroiluminacion"; "averia retroiluminacion"; "reparar backlight"; "backlight defekt"; "backlight kaputt"; "backlight broken";
        "hintergrundbeleuchtung defekt"; "hintergrundbeleuchtung kaputt"; "leds fundidos"; "led fundido"; "retroilluminazione"; "retroiluminacao";
        "pantalla oscura"; "pantalla negra"; "bild dunkel"; "dunkles bild"; "kein bild aber ton"; "solo sonido"; "sonido pero no imagen";
        "se oye pero no se ve"; "ton aber kein bild"; "ton ja bild nein" ] );
    ( "no enciende",
      [ "no enciende"; "no se enciende"; "no arranca"; "no prende"; "geht nicht an"; "geht nicht mehr an"; "lasst sich nicht einschalten";
        "schaltet nicht ein"; "startet nicht"; "does not turn on"; "doesnt turn on"; "won t turn on"; "not turning on"; "non si accende";
        "nao liga"; "ne s allume pas" ] );
    ( "quemado",
      [ "quemado"; "quemada"; "quemados"; "burn in"; "burnin"; "einbrennung"; "einbrennungen"; "eingebrannt"; "eingebrannte"; "screen burn";
        "retencion de imagen"; "image retention"; "bruciatura" ] );
    ("sin imagen", [ "sin imagen"; "no da imagen"; "no hay imagen"; "kein bild"; "no picture"; "no image"; "nessuna immagine"; "sem imagem" ]) ]

let averiada =
  [ "averiado"; "averiada"; "averia"; "defekt"; "defekte"; "defektes"; "defekter"; "kaputt"; "broken"; "faulty"; "defective"; "not working";
    "no funciona"; "guasto"; "guasta"; "non funziona"; "avariada"; "avariado"; "nao funciona"; "en panne"; "hors service"; "para reparar";
    "a reparar"; "reparatur"; "fallo"; "falla"; "defectuosa"; "defectuoso"; "defectuosos"; "defectuosas"; "difettoso"; "difettosa";
    "defeituoso"; "defeituosa"; "defectueux"; "defectueuse"; "ne fonctionne pas"; "funktioniert nicht"; "se reinicia"; "reinicia sola";
    "renicia sola"; "se reinicia solo"; "se apaga sola"; "se apaga solo"; "startet neu" ]

(* En el título basta la palabra: «TV TCL 75P8L Nueva Rota.», «Samsung TV kaputt», «Televisore rotto». *)
let rota_titulo =
  [ "rota"; "roto"; "rotas"; "rotos"; "rotto"; "rotta"; "rotti"; "rotte"; "partida"; "partido"; "rajada"; "rajado"; "quebrada"; "quebrado";
    "kaputt"; "gebrochen"; "broken"; "cracked"; "casse"; "cassee"; "golpe"; "golpeada"; "golpeado"; "danada"; "danado"; "partita" ]

let precintado =
  [ "precintado"; "precintada"; "precinto"; "sin abrir"; "sin desprecintar"; "sealed"; "versiegelt"; "ungeoffnet"; "ungeoffnete";
    "sigillato"; "sigillata"; "selado"; "selada"; "scelle"; "eingeschweisst" ]

let nuevo_titulo = [ "nuevo"; "nueva"; "neu"; "brandneu"; "fabrikneu"; "neuware"; "neugerat"; "new"; "brand new"; "nuovo"; "nuova"; "novo"; "nova"; "neuf"; "neuve" ]
let nuevo = [ "a estrenar"; "sin estrenar"; "sin usar"; "nunca usado"; "nunca usada"; "unbenutzt"; "nie benutzt"; "never used"; "mai usato" ]

let como_nuevo =
  [ "como nuevo"; "como nueva"; "casi nuevo"; "casi nueva"; "practicamente nuevo"; "practicamente nueva"; "seminuevo"; "seminueva";
    "wie neu"; "neuwertig"; "neuwertiger"; "neuwertigem"; "neuwertigen"; "fast neu"; "nahezu neu"; "quasi neu"; "like new"; "as new";
    "come nuovo"; "come nuova"; "pari al nuovo"; "como novo"; "como nova"; "comme neuf"; "comme neuve"; "b ware"; "bware"; "vorfuhrware";
    "vorfuhrgerat"; "retoure"; "open box"; "reacondicionado"; "reacondicionada"; "refurbished" ]

let como = [ "como"; "casi"; "practicamente"; "wie"; "fast"; "like"; "quasi"; "come"; "semi"; "nahezu"; "as" ]

let garantia = [ "garantia"; "garantie"; "warranty"; "garanzia"; "gewahrleistung"; "herstellergarantie"; "restgarantie"; "plusgarantie" ]
let sin_garantia = [ "ausschluss jeglicher"; "unter ausschluss"; "keine garantie"; "keine gewahrleistung"; "ohne garantie"; "ohne gewahrleistung"; "sin garantia"; "privatverkauf" ]
let factura = [ "factura"; "rechnung"; "invoice"; "fattura"; "ticket de compra"; "ticket"; "kaufbeleg"; "receipt"; "kassenbon"; "kaufnachweis"; "fatura"; "facture" ]
let caja = [ "caja original"; "con caja"; "con su caja"; "en su caja"; "caja"; "ovp"; "originalverpackung"; "originalkarton"; "karton"; "verpackung"; "original box"; "scatola"; "imballo originale"; "caixa"; "embalaje original"; "embalaje"; "boite" ]
let envio = [ "envio"; "envios"; "envio gratis"; "hago envios"; "versand"; "versandkostenfrei"; "spedizione"; "spedisco"; "shipping"; "envoi"; "porto"; "dhl"; "hermes"; "correos"; "seur"; "mrw"; "nacex"; "gls"; "dpd" ]
let solo_recogida =
  [ "solo recogida"; "solo en mano"; "solo mano"; "solo a mano"; "solo entrega en mano"; "nur abholung"; "nur selbstabholung"; "nur an selbstabholer";
    "selbstabholung"; "nur fur selbstabholer"; "nur abholer"; "pickup only"; "local pickup"; "collection only"; "solo ritiro"; "so recolha";
    "apenas recolha"; "retrait uniquement"; "kein versand" ]
let cambio = [ "acepto cambio"; "acepto cambios"; "admito cambio"; "admito cambios"; "cambio por"; "o cambio"; "cambiaria"; "intercambio"; "intercambios"; "cambios"; "tausch"; "tausche"; "tauschen"; "swap"; "trade"; "scambio"; "troca"; "trocas"; "echange" ]

(* --- decidir ------------------------------------------------------------------------- *)

type decision = Decide of tipo | Defecto of string

(* La palabra donde empieza la primera de [frases] en [t], y lo larga que es: con dos en el mismo
   sitio, la más larga («tv stick» no es «tv»). *)
let primera t frases =
  let ws = T.palabras t in
  let n = Array.length ws in
  let encaja i f =
    let ps = Array.of_list (String.split_on_char ' ' f) in
    let k = Array.length ps in
    if i + k <= n && Array.for_all Fun.id (Array.init k (fun j -> ws.(i + j) = ps.(j))) then Some k else None
  in
  let rec busca i =
    if i >= n then None
    else
      match List.filter_map (encaja i) frases with
      | [] -> busca (i + 1)
      | ks -> Some (i, List.fold_left max 0 ks)
  in
  busca 0

let pos t frases = Option.map fst (primera t frases)

(* [frases] en el título, y no detrás de «para»/«für»: «Mando para TV» no es una tele. Con su largo. *)
let propia t frases =
  match primera t frases with
  | Some (i, k) ->
    let ws = T.palabras t in
    if i > 0 && List.mem ws.(i - 1) para then None else Some (i, k)
  | None -> None

let pos_propia t frases = Option.map fst (propia t frases)

let en_categoria cat ws = let c = String.concat " " (G.palabras cat) in List.mem c ws

(* Cuántas veces nombra una tele: «TCL Fernseher und Toshiba Fernseher» son dos. *)
let veces t frases =
  let ws = T.palabras t in
  let n = Array.length ws in
  let encaja i f =
    let ps = Array.of_list (String.split_on_char ' ' f) in
    let k = Array.length ps in
    i + k <= n && Array.for_all Fun.id (Array.init k (fun j -> ws.(i + j) = ps.(j)))
  in
  let rec cuenta i acc = if i >= n then acc else if List.exists (encaja i) frases then cuenta (i + 2) (acc + 1) else cuenta (i + 1) acc in
  cuenta 0 0

(* «2 Televisores», «3 TVs», «zwei Fernseher»: varias teles. *)
let varias t =
  let ws = T.palabras t in
  let plurales = [ "televisores"; "tvs"; "televisori"; "televisoes"; "fernseher"; "fernsehgerate"; "televiseurs"; "teles" ] in
  let num w = match int_of_string_opt w with Some k -> k >= 2 && k <= 9 | None -> List.mem w [ "dos"; "tres"; "cuatro"; "zwei"; "drei"; "vier"; "due"; "tre"; "deux"; "trois" ] in
  let suelto i = i = 0 || not (String.exists T.es_cifra ws.(i - 1)) in
  List.exists (fun i -> num ws.(i) && suelto i && List.mem ws.(i + 1) plurales) (List.init (max 0 (Array.length ws - 1)) Fun.id)

let decidir (a : Memoria_anuncio.anuncio) =
  let t = a.titulo in
  let ms = M.menciones t in
  let marcas = T.marcas t in
  let tamanos, _ = M.tamanos t in
  (* «Röhrenfernseher», «LED-Fernseher» pegado: la palabra que acaba en «fernseher» también. *)
  let palabra_tele =
    match propia t tele with
    | Some x -> Some x
    | None -> (
      let ws = T.palabras t in
      let acaba w s = let n = String.length w and k = String.length s in n > k && String.sub w (n - k) k = s in
      match List.find_opt (fun i -> acaba ws.(i) "fernseher" || acaba ws.(i) "fernsehgerat") (List.init (Array.length ws) Fun.id) with
      | Some i -> Some (i, 1)
      | None -> None)
  in
  let pos_modelo = match ms with m :: _ -> Some (m.pos, 1) | [] -> None in
  let pos_tec = match T.tecnologias_en t with (_, p) :: _ when tamanos <> [] || marcas <> [] -> Some (p, 1) | _ -> None in
  (* «Sony Bravia 47 Zoll»: una marca de teles con un tamaño también es una tele (donde la marca). *)
  let pos_marca =
    match (pos t (List.map fst C.marcas), M.tamanos t) with
    | Some i, (_ :: _, (_, j) :: _) -> Some (max i j, 1)
    | _ -> None
  in
  let pos_tele =
    List.fold_left (fun acc x -> match (acc, x) with Some (a, _), Some (b, _) -> if b < a then x else acc | None, x | x, None -> x) None
      [ palabra_tele; pos_modelo; pos_tec; pos_marca ]
  in
  (* Antes que la tele; en el mismo sitio, si es más larga («TV Box», «TV Stick» no son la palabra «TV»). *)
  let antes = function Some (i, k) -> (match pos_tele with Some (j, l) -> i < j || (i = j && k > l) | None -> true) | None -> false in
  (* Una pieza o un accesorio justo detrás de la palabra «TV» («TV Standfuß», «Samsung TV Platine») es para la tele. *)
  let justo_detras = function
    | Some (i, _) -> (
      match palabra_tele with Some (j, _) -> i = j + 1 | None -> false)
    | None -> false
  in
  let piezas = match primera t pieza_al_principio with Some (0, k) -> Some (0, k) | _ -> propia t pieza in
  let candidatos = [ (piezas, Pieza); (propia t accesorio, Accesorio); (propia t proyector, Proyector); (propia t monitor, Monitor); (propia t otro, Otro) ] in
  let delante = List.find_opt (fun (p, _) -> antes p) (List.sort (fun (a, _) (b, _) -> compare (Option.map fst a) (Option.map fst b)) (List.filter (fun (p, _) -> p <> None) candidatos)) in
  let detras = List.find_opt (fun (p, k) -> (k = Pieza || k = Accesorio) && justo_detras p) candidatos in
  let cat = a.categoria in
  if Option.fold ~none:false ~some:(fun i -> i <= 2) (pos t busca) then Decide Busca
  else
    match (delante, detras) with
    (* «Lote de 3 mandos» es de mandos; «Lote televisores», un lote (más abajo). *)
    | Some (_, k), _ | None, Some (_, k) -> Decide k
    | None, None ->
      if (pos t lote <> None && pos_tele <> None) || varias t || (veces t tele >= 2 && List.length marcas >= 2) then Decide Lote
      else if pos_tele <> None then Decide Tv
      else if G.contiene t para_piezas && marcas <> [] then Decide Tv
      else if en_categoria cat categoria_accesorio then Decide Accesorio
      else if en_categoria cat categoria_proyector then Decide Proyector
      else if en_categoria cat categoria_otro then Decide Otro
      else if marcas <> [] && (tamanos <> [] || en_categoria cat categoria_tv) then Decide Tv
      else if en_categoria cat categoria_tv || marcas <> [] then Defecto "no sé si es una tele"
      else Decide Otro

(* --- la tele ------------------------------------------------------------------------- *)

type lectura = { tele : M.tele option; pulgadas : int option; marca : string option }

let distintas xs = List.fold_left (fun acc x -> if List.mem x acc then acc else acc @ [ x ]) [] xs

(* Las pulgadas del título, por lo que más fe da: el código de un modelo («OLED77C6»), las unidades
   («75″», «75 Zoll»), los cm, el tamaño de un código sin modelo («H65M80FUX») y los números sueltos
   («TV Samsung 55 4K»). Con dos que no casan, defecto; salvo un número suelto detrás de la unidad
   («70 Zoll LG … Prime, 75») o unos cm que no casan con las pulgadas («138 cm 65 Zoll»). *)
let pulgadas_titulo t =
  let ms = List.filter (fun (m : T.medida) -> not m.compat) (T.medidas ~sueltas:true t) in
  let de f = List.filter_map (fun (m : T.medida) -> if m.fuente = f then Some (m.valor, m.pos) else None) ms in
  let cods = T.codigos t in
  let modelo = List.filter_map (fun (c : T.codigo) -> match c.mencion with Some { pulgadas = Some p; pos; _ } -> Some (p, pos) | _ -> None) cods in
  let sin_modelo = List.filter_map (fun (c : T.codigo) -> c.solo_pulgadas) cods in
  let unidad = de T.Unidad and cm = de T.Cm and sueltas = de T.Suelto in
  let vals xs = distintas (List.map fst xs) in
  let todas = vals (modelo @ unidad @ cm @ sin_modelo @ sueltas) in
  let varias () = Error ("varias pulgadas: " ^ String.concat ", " (List.map string_of_int todas)) in
  match (vals modelo, vals unidad) with
  | [ p ], u when List.for_all (( = ) p) u -> Ok (Some p)
  | _ :: _, _ -> varias ()
  | [], [ p ] ->
    let pos_u = List.fold_left (fun m (_, i) -> min m i) max_int unidad in
    if List.for_all (fun (v, i) -> v = p || i > pos_u) (sueltas @ sin_modelo) then Ok (Some p) else varias ()
  | [], _ :: _ -> varias ()
  | [], [] -> (
    match (vals cm, vals sin_modelo, vals sueltas) with
    | [ p ], _, _ -> Ok (Some p)
    | _ :: _, _, _ -> varias ()
    | [], [ p ], s when List.for_all (( = ) p) s -> Ok (Some p)
    | [], [], [ p ] -> Ok (Some p)
    | [], [], [] -> Ok None
    | _ -> varias ())

(* Si el título no las dice, las de la descripción: solo con unidades, en un código, o en cm detrás
   de «Diagonale». La primera. *)
let pulgadas_descripcion d =
  match M.tamanos ~sueltas:false ~cm:false d with
  | p :: _, _ -> Some p
  | [], _ ->
    let ws = T.palabras d in
    let diagonal i =
      List.exists (fun k -> k >= 0 && k < Array.length ws && List.exists (T.empieza ws.(k)) [ "diagonal"; "bildschirmdiagonal"; "bilddiagonal" ]) [ i - 1; i - 2; i - 3 ]
    in
    List.find_map (fun (m : T.medida) -> if m.fuente = T.Cm && diagonal m.pos && not m.compat then Some m.valor else None) (T.medidas ~cm:true d)

let pulgadas (a : Memoria_anuncio.anuncio) =
  match pulgadas_titulo a.titulo with
  | Ok None -> Ok (pulgadas_descripcion a.descripcion)
  | r -> r
let la_tele (a : Memoria_anuncio.anuncio) p =
  let de t = match M.menciones t with m :: _ -> Some m | [] -> None in
  let m = match de a.titulo with Some m -> Some m | None -> (match M.menciones a.descripcion with [ m ] -> Some m | _ -> None) in
  match m with
  | Some m ->
    (* El tamaño del código manda sobre el del texto. *)
    let p = match m.pulgadas with Some c -> Some c | None -> p in
    Some (M.tele m.familia p)
  | None -> None

let lectura (a : Memoria_anuncio.anuncio) p =
  let tele = la_tele a p in
  let marca =
    match tele with
    | Some t -> Some t.familia.marca
    | None -> (match T.marcas a.titulo with x :: _ -> Some x | [] -> (match T.marcas a.descripcion with x :: _ -> Some x | [] -> None))
  in
  { tele; pulgadas = (match tele with Some { pulgadas = Some c; _ } -> Some c | _ -> p); marca }

(* --- estado ---------------------------------------------------------------------------- *)

(* Sí, no o no lo dice: como [G.dice], con la negación hasta dos palabras antes, o más allá de una unión. *)
let dice todo frases =
  let ws = T.palabras todo in
  let n = Array.length ws in
  let encaja i f =
    let ps = Array.of_list (String.split_on_char ' ' f) in
    let k = Array.length ps in
    i + k <= n && Array.for_all Fun.id (Array.init k (fun j -> ws.(i + j) = ps.(j)))
  in
  let neg k = k >= 0 && List.mem ws.(k) negaciones in
  let rec negada i = neg (i - 1) || neg (i - 2) || (i >= 1 && List.mem ws.(i - 1) uniones && negada (i - 1)) || (i >= 2 && List.mem ws.(i - 2) uniones && negada (i - 2)) in
  let r = ref G.No_dice in
  for i = 0 to n - 1 do
    if List.exists (encaja i) frases then r := (match (!r, negada i) with G.Si, _ -> G.Si | _, false -> G.Si | _, true -> G.No)
  done;
  !r

(* En la descripción, «roto» sin más es la tele si nada lo ata a otra cosa: empieza una frase o una
   línea («Roto por instalación»), lleva «por» detrás («rota por una caída») o va con su verbo («se
   rompió», «está rota», «llegó rota»); y no tiene delante otro sustantivo («el botón está roto», «la
   peana rota», «tapa rota»). *)
let rotas = [ "roto"; "rota"; "rotos"; "rotas"; "rotto"; "rotta" ]
let verbos_rota = [ "se rompio"; "se ha roto"; "se han roto"; "se rompe"; "esta rota"; "esta roto"; "estan rotas"; "llego rota"; "llego roto"; "vino rota"; "vino roto"; "se cayo"; "e rotto"; "e rotta" ]

let otra_cosa =
  [ "boton"; "botones"; "mando"; "mandos"; "tapa"; "pie"; "pies"; "peana"; "soporte"; "caja"; "pata"; "patas"; "base"; "cable"; "embalaje";
    "marco"; "esquina"; "carcasa"; "mueble"; "enchufe"; "puerto"; "conector"; "pilas"; "tornillo"; "tornillos"; "anclaje"; "tecla"; "led"; "leds"; "placa"; "fuente" ]

let rota_en_descripcion d =
  let frases = String.split_on_char '\n' d |> List.concat_map (String.split_on_char '.') |> List.concat_map (String.split_on_char '!') in
  List.exists
    (fun f ->
      let ws = T.palabras f in
      let n = Array.length ws in
      (* Lo de delante: ni otra cosa (la peana), ni una negación (no está rota). *)
      let libre i = not ((i >= 1 && (List.mem ws.(i - 1) otra_cosa || List.mem ws.(i - 1) negaciones)) || (i >= 2 && (List.mem ws.(i - 2) otra_cosa || List.mem ws.(i - 2) negaciones))) in
      let encaja i f =
        let ps = Array.of_list (String.split_on_char ' ' f) in
        let k = Array.length ps in
        i + k <= n && Array.for_all Fun.id (Array.init k (fun j -> ws.(i + j) = ps.(j)))
      in
      List.exists
        (fun i ->
          (List.mem ws.(i) rotas && (i = 0 || (i + 1 < n && List.mem ws.(i + 1) [ "por"; "per"; "durch"; "beim"; "al"; "en" ])) && libre i)
          || (List.exists (encaja i) verbos_rota && libre i))
        (List.init n Fun.id))
    frases

let averia ?(titulo = "") ?(descripcion = "") todo =
  match List.find_map (fun (etiqueta, frases) -> if dice todo frases = G.Si then Some etiqueta else None) averias with
  | Some a -> Some a
  | None -> if dice titulo rota_titulo = G.Si || rota_en_descripcion descripcion then Some "pantalla rota" else None

(* El estado que declara el portal, si la entrada lo trae en una línea «Estado: …» de la cabecera
   (Wallapop: «como nuevo», «en buen estado»; Kleinanzeigen: «Sehr gut», «Defekt»). *)
let declarado entrada =
  let lineas = String.split_on_char '\n' entrada in
  let rec cabecera = function
    | [] -> []
    | l :: resto -> if T.empieza (String.lowercase_ascii (String.trim l)) "descripci" then [] else l :: cabecera resto
  in
  let valor l =
    let l = String.trim l in
    List.find_map
      (fun p ->
        let p = p ^ ":" in
        let k = String.length p in
        if String.length l >= k && String.lowercase_ascii (String.sub l 0 k) = p then Some (String.sub l k (String.length l - k)) else None)
      [ "estado"; "condición"; "condicion"; "condition"; "zustand"; "condizione" ]
  in
  match List.find_map valor (cabecera lineas) with
  | None -> None
  | Some v ->
    if G.contiene v [ "para piezas"; "for parts"; "defekt"; "defectuoso"; "no funciona"; "per pezzi" ] then Some "para-piezas"
    else if G.contiene v [ "precintado"; "sin abrir"; "sealed"; "versiegelt"; "ungeoffnet" ] then Some "precintado"
    else if G.contiene v [ "como nuevo"; "like new"; "as good as new"; "wie neu"; "neuwertig"; "sehr gut"; "come nuovo"; "como novo" ] then Some "como-nuevo"
    else if G.contiene v [ "nuevo"; "new"; "neu"; "nuovo"; "novo"; "neuf" ] then Some "nuevo"
    else if G.contiene v [ "buen estado"; "good"; "gut"; "aceptable"; "fair"; "usado"; "used"; "gebraucht"; "buono"; "usato" ] then Some "usado"
    else None

let estado ?declarado (a : Memoria_anuncio.anuncio) =
  let todo = a.titulo ^ "\n" ^ a.descripcion in
  let av = averia ~titulo:a.titulo ~descripcion:a.descripcion todo in
  (* Lo que dice el texto de una avería manda; si no, lo que declara el portal; si no, lo que dice el texto. *)
  if dice todo para_piezas = G.Si then ("para-piezas", av)
  else if av <> None || dice todo averiada = G.Si then ("averiado", av)
  else
    match declarado with
    | Some e -> (e, None)
    | None ->
      if dice todo precintado = G.Si then ("precintado", None)
      else if G.contiene todo como_nuevo then ("como-nuevo", None)
      else if G.dice ~negaciones:(negaciones @ como) a.titulo nuevo_titulo = G.Si || dice todo nuevo = G.Si then ("nuevo", None)
      else ("usado", None)

let tri = function G.Si -> `Bool true | G.No -> `Bool false | G.No_dice -> `Null

let garantia_de todo = if G.contiene todo sin_garantia then `Bool false else tri (dice todo garantia)

let envio_y_recogida todo =
  let solo = G.contiene todo solo_recogida in
  match (dice todo envio, solo) with
  | G.No, _ -> (`Bool false, `Bool true)
  | _, true -> (`Bool false, `Bool true)
  | G.Si, false -> (`Bool true, `Bool false)
  | G.No_dice, false -> (`Null, `Null)

(* --- JSON ------------------------------------------------------------------------------- *)

let opt f = function Some x -> f x | None -> `Null
let str s = `String s

let json ?declarado (a : Memoria_anuncio.anuncio) tipo (l : lectura) : Yojson.Safe.t =
  let todo = a.titulo ^ "\n" ^ a.descripcion in
  let de_tele = match tipo with Tv | Monitor | Lote | Busca -> true | Proyector | Accesorio | Pieza | Otro -> false in
  let te = if de_tele then l.tele else None in
  let m f = match te with Some t -> f t | None -> `Null in
  let d v = if de_tele then v else `Null in
  (* Lo del catálogo manda; lo que no sabe, lo dice el título y, si calla, la descripción. *)
  let del_texto f = match f a.titulo with Some x -> Some x | None -> f a.descripcion in
  (* La del catálogo; si no, la del título, la que dice el código (de la letra de su serie) y la de la descripción. *)
  let tecnologia =
    match te with
    | Some { familia = { entrada = Some { tecnologia = Some x; _ }; _ }; _ } -> Some x
    | _ -> (
      match (T.tecnologia a.titulo, te) with
      | Some x, _ -> Some x
      | None, Some { familia = { tecnologia = Some x; _ }; _ } -> Some x
      | None, _ -> T.tecnologia a.descripcion)
  in
  let resolucion =
    match te with
    | Some { ocho_k = true; _ } -> Some "8k"
    | Some { familia = { entrada = Some _; _ }; _ } -> Some "4k"
    | _ -> del_texto T.resolucion
  in
  let hz = match te with Some { hz = Some h; _ } -> Some h | _ -> del_texto T.hz in
  let hdmi21 = match te with Some { hdmi21 = Some h; _ } -> Some h | _ -> T.hdmi21 todo in
  let sistema = match te with Some { sistema = Some s; _ } -> Some s | _ -> del_texto T.sistema in
  let estado, av = estado ?declarado a in
  let envio, recogida = envio_y_recogida todo in
  let precio = match a.precio with Some p when p > 0. -> `Float p | _ -> `Null in
  `Assoc
    [ ("tipo", str (tipo_texto tipo));
      ("marca", opt str l.marca);
      ("modelo", m (fun t -> str t.modelo));
      ("serie", m (fun t -> str t.serie));
      ("anio", m (fun t -> opt (fun x -> `Int x) t.anio));
      ("pulgadas", d (opt (fun x -> `Int x) l.pulgadas));
      ("tecnologia", d (opt (fun x -> str (C.tecnologia_texto x)) tecnologia));
      ("resolucion", (match tipo with Proyector -> opt str (del_texto T.resolucion) | _ -> d (opt str resolucion)));
      ("hz", d (opt (fun x -> `Int x) hz));
      ("hdmi21", d (opt (fun x -> `Bool x) hdmi21));
      ("sistema", d (opt (fun x -> str (C.sistema_texto x)) sistema));
      ("gama", m (fun t -> opt (fun x -> str (C.gama_texto x)) t.gama));
      ("precio_lanzamiento", m (fun t -> opt (fun x -> `Float x) t.precio_lanzamiento));
      ("precio_nuevo", m (fun t -> opt (fun x -> `Float x) t.precio_nuevo));
      ("estado", str estado);
      ("averia", opt str av);
      ("garantia", garantia_de todo);
      ("factura", tri (dice todo factura));
      ("caja", tri (dice todo caja));
      ("envio", envio);
      ("solo_recogida", recogida);
      ("cambio", tri (dice todo cambio));
      ("precio", precio) ]

let aplicar entrada : (string, string) result =
  let a = Memoria_anuncio.partes entrada in
  if String.trim a.titulo = "" then Error "sin título"
  else
    match decidir a with
    | Defecto m -> Error m
    | Decide tipo -> (
      match pulgadas a with
      | Error m when tipo = Tv -> Error m
      | r ->
        let p = match r with Ok p -> p | Error _ -> None in
        let l = lectura a p in
        if tipo = Tv && l.pulgadas = None then Error "no dice las pulgadas"
        else Ok (Yojson.Safe.to_string (json ?declarado:(declarado entrada) a tipo l)))

let cristal = Cristal.cristal "tv-anuncio" Cristal.texto aplicar
