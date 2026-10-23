(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: de qué va una noticia de imagen y sonido, para quien sigue los
   televisores. Ver SEMILLA.md.

   La entrada es la de grafica-noticia (líneas «Título: …», «Resumen: …» y
   «Fuente: …»; sin «Título:», todo es el título), y se lee con su [partes].
   Se decide por el título; el resumen solo suma marcas y modelos cuando el
   título ya va de teles o de imagen y sonido. *)

module M = Tv_modelo
module T = Tv_modelo.Texto
module C = Tv_modelo.Catalogo
module G = Grafica_modelo.Texto

(* --- palabras (plegadas) ----------------------------------------------------- *)

let tele =
  [ "tv"; "tvs"; "television"; "televisions"; "televisor"; "televisores"; "television"; "televisiones"; "tele"; "teles"; "fernseher";
    "fernsehen"; "fernsehgerat"; "televiseur"; "televiseurs"; "televisore"; "televisori"; "smart tv"; "smart tvs"; "oled tv"; "oled tvs";
    "qd oled"; "mini led"; "miniled"; "qled"; "neo qled"; "rgb mini led"; "micro rgb"; "woled"; "mla"; "ambilight"; "bravia"; "webos";
    "tizen"; "vidaa"; "titan os"; "tv lineup"; "tv range"; "viera" ]

(* Lo que, con «TV» en el nombre, no es una tele: los reproductores y los servicios. *)
let no_tele =
  [ "apple tv"; "fire tv stick"; "fire tv cube"; "firetv stick"; "youtube tv"; "google tv streamer"; "chromecast"; "android tv box"; "tv box";
    "tvos"; "apple tv 4k"; "nvidia shield"; "shield tv"; "roku streaming"; "sling tv"; "vodafone tv"; "live tv"; "tv series"; "tv show"; "tv shows";
    "serie de tv"; "tv serie"; "tv serien"; "tv spot" ]

let oled = [ "oled"; "oleds" ]

let imagen_sonido =
  [ "soundbar"; "soundbars"; "barra de sonido"; "barras de sonido"; "altavoz"; "altavoces"; "speaker"; "speakers"; "lautsprecher"; "enceinte";
    "enceintes"; "headphones"; "headphone"; "auriculares"; "kopfhorer"; "earbuds"; "earphones"; "casque"; "cuffie"; "amplifier"; "amplifiers";
    "amp"; "amplificador"; "verstarker"; "turntable"; "turntables"; "tocadiscos"; "plattenspieler"; "hifi"; "hi fi"; "hi res"; "av receiver";
    "receiver"; "receptor av"; "blu ray"; "blu rays"; "bluray"; "uhd blu ray"; "4k blu ray"; "4k uhd blu ray"; "steelbook"; "projector";
    "projectors"; "proyector"; "proyectores"; "beamer"; "videoprojecteur"; "proiettore"; "apple tv"; "fire tv"; "chromecast"; "roku"; "shield";
    "streaming"; "streamer"; "netflix"; "disney"; "prime video"; "hbo"; "max"; "dazn"; "skyshowtime"; "plex"; "youtube"; "spotify"; "tidal";
    "deezer"; "qobuz"; "apple music"; "music"; "musica"; "musik"; "audio"; "sound"; "sonido"; "dolby"; "atmos"; "dolby vision"; "dolby atmos";
    "dts"; "hdr"; "hdr10"; "imax"; "hdmi"; "hdmi 2 2"; "monitor"; "monitors"; "monitores"; "moniteur"; "display"; "displays"; "panel"; "panels";
    "4k"; "8k"; "uhd"; "sonos"; "bose"; "denon"; "marantz"; "yamaha"; "naim"; "kef"; "bowers"; "b w"; "bluesound"; "cambridge audio"; "technics";
    "home cinema"; "home theater"; "home theatre"; "heimkino"; "cine en casa"; "dac"; "vinyl"; "vinilo"; "cd player"; "kino"; "cine";
    "pelicula"; "peliculas"; "film"; "filme"; "movie"; "movies"; "serie"; "series"; "trailer" ]

(* Lo que no es de imagen y sonido aunque lo parezca: los teléfonos, los ordenadores, los coches, los juegos. *)
let fuera =
  [ "smartphone"; "smartphones"; "iphone"; "galaxy s"; "galaxy z"; "pixel"; "movil"; "moviles"; "telefono"; "handy"; "portatil"; "laptop";
    "macbook"; "ipad"; "tablet"; "coche"; "coches"; "car"; "cars"; "auto"; "electric car"; "ev"; "xbox"; "playstation"; "ps5"; "nintendo";
    "switch 2"; "gta"; "game pass"; "robot aspirador"; "aspirador"; "vacuum"; "lavadora"; "frigorifico"; "watch"; "reloj" ]

let tipos =
  [ ( "analisis",
      [ "review"; "reviewed"; "reviews"; "tested"; "test"; "im test"; "analisis"; "analizamos"; "probamos"; "a prueba"; "hands on"; "vs"; "versus";
        "comparison"; "comparativa"; "comparatif"; "vergleich"; "prova"; "recensione"; "avis"; "notre avis"; "verdict"; "best"; "mejores";
        "mejor"; "beste"; "besten"; "meilleur"; "meilleurs"; "migliori"; "calibrated"; "calibration"; "benchmark"; "demo" ] );
    ( "oferta",
      [ "deal"; "deals"; "discount"; "discounted"; "oferta"; "ofertas"; "rebaja"; "rebajas"; "chollo"; "a precio de"; "precio minimo";
        "lowest price"; "price drop"; "dropped to"; "bon plan"; "angebot"; "angebote"; "sale"; "black friday"; "prime day"; "cyber monday";
        "save"; "ahorra"; "descuento"; "descuentos"; "promo"; "promocion"; "soldes"; "sconto"; "offerta"; "rabatt"; "bestpreis" ] );
    ( "precio",
      [ "price"; "prices"; "pricing"; "priced"; "precio"; "precios"; "preis"; "preise"; "prix"; "prezzo"; "more expensive"; "mas caro"; "mas caros";
        "mas caras"; "teurer"; "cost"; "costs"; "coste"; "costes"; "price hike"; "cuesta"; "cuestan"; "subida"; "sube"; "suben"; "cheaper"; "barato";
        "baratos" ] );
    ( "rumor",
      [ "rumor"; "rumors"; "rumour"; "rumoured"; "rumored"; "leak"; "leaks"; "leaked"; "reportedly"; "allegedly"; "could"; "might"; "tipped";
        "spotted"; "expected"; "filtra"; "filtrado"; "filtracion"; "rumorea"; "llegaria"; "tendria"; "seria"; "angeblich"; "soll"; "sollen";
        "geruecht"; "gerucht"; "rumeur"; "indiscrezione" ] );
    ( "software",
      [ "firmware"; "update"; "updates"; "actualizacion"; "actualizaciones"; "aktualisierung"; "mise a jour"; "aggiornamento"; "software"; "app";
        "apps"; "webos"; "tizen"; "google tv"; "vidaa"; "titan os"; "android tv"; "tvos"; "feature"; "features"; "funcion"; "funciones" ] );
    ( "mercado",
      [ "market"; "markets"; "shipments"; "market share"; "cuota"; "ventas"; "returns to"; "exits"; "exit"; "abandona"; "abandonar"; "abandoning";
        "discontinued"; "discontinues"; "descatalogado"; "descatalogar"; "warns"; "omdia"; "counterpoint"; "trendforce"; "supply"; "tariff";
        "tariffs"; "aranceles"; "earnings"; "revenue"; "profit"; "lawsuit"; "acquisition"; "acquires"; "crisis"; "factory"; "fabrica"; "production";
        "produccion"; "markt"; "marche"; "mercato"; "mercado"; "future"; "futuro"; "zukunft" ] );
    ( "lanzamiento",
      [ "launch"; "launches"; "launched"; "launching"; "unveil"; "unveils"; "unveiled"; "announce"; "announces"; "announced"; "now available";
        "available"; "availability"; "disponible"; "disponibles"; "llega"; "llegan"; "lanza"; "lanzan"; "presenta"; "presentan"; "a la venta";
        "erscheint"; "erscheinen"; "startet"; "kommt"; "kommen"; "vorgestellt"; "debuts"; "introduces"; "coming"; "arrives"; "arriving"; "new";
        "nuevo"; "nueva"; "nuevos"; "nuevas"; "neue"; "neuer"; "neues"; "nouveau"; "nouvelle"; "arriva"; "lancia"; "nuova"; "nuovo"; "revealed";
        "reveals"; "lineup"; "range"; "gama" ] ) ]

(* --- decidir -------------------------------------------------------------------- *)

let hay t ws = G.contiene t ws

let tema t (ms : T.mencion list) =
  let marcas = T.marcas t in
  let es_tele = ms <> [] || (hay t tele && not (hay t no_tele && not (hay t [ "tvs"; "televisores"; "fernseher" ]))) in
  if hay t fuera && not es_tele then Some "otro"
  else if es_tele then Some "tv"
  else if hay t oled && not (hay t [ "monitor"; "monitors"; "monitores"; "moniteur"; "panel"; "phone"; "smartphone"; "laptop" ]) then
    (* «OLED» sin más, con una marca de teles: una tele. *)
    if marcas <> [] then Some "tv" else Some "imagen-sonido"
  else if hay t imagen_sonido then Some "imagen-sonido"
  else if List.exists (fun m -> List.mem m [ "lg"; "samsung"; "sony"; "tcl"; "hisense"; "philips"; "panasonic"; "xiaomi" ]) marcas then None
  else Some "otro"

let distintas xs = List.fold_left (fun acc x -> if List.mem x acc then acc else acc @ [ x ]) [] xs

let serie teles = distintas (List.map (fun (x : M.tele) -> (M.tele x.familia None).modelo) teles)

let aplicar entrada : (string, string) result =
  let n = Grafica_noticia.partes entrada in
  let t = n.titulo in
  if String.trim t = "" then Error "sin título"
  else
    let ms = M.menciones t in
    match tema t ms with
    | None -> Error "no sé si va de teles"
    | Some tema ->
      let dentro = tema <> "otro" in
      let tipo =
        if dentro then Option.value ~default:"otro" (List.find_map (fun (k, ws) -> if hay t ws then Some k else None) tipos) else "otro"
      in
      let todo = t ^ "\n" ^ n.resumen in
      let l = M.leer ~sueltas:false todo in
      let lista xs = `List (List.map (fun s -> `String s) (if dentro then xs else [])) in
      Ok
        (Yojson.Safe.to_string
           (`Assoc
              [ ("tema", `String tema);
                ("tipo", `String tipo);
                ("marcas", lista l.marcas);
                (* Las series, sin tamaño: una noticia va de la C6, no de la de 77. *)
                ("modelos", lista (serie (List.filter (fun (x : M.tele) -> x.familia.entrada <> None) l.teles)));
                ("nuevos", lista (serie (List.filter (fun (x : M.tele) -> x.familia.entrada = None) l.teles)));
                ("tecnologias", lista (List.map C.tecnologia_texto (T.tecnologias t))) ]))

let cristal = Cristal.cristal "tv-noticia" Cristal.texto aplicar
