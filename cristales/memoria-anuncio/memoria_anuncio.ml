(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: qué se vende en un anuncio de segunda mano de memoria RAM. Ver
   SEMILLA.md.

   La entrada es la de grafica-anuncio y nvme-anuncio («Título: …»,
   «Categoría: …», «Descripción: …» hasta el final; sin «Título:», todo es el
   título), más «Precio:», «Portal:» y «País:» si van antes de la
   descripción. Lo que es (memoria suelta: un módulo, un kit, un lote; o un
   equipo, una placa o una CPU que la lleva; otra pieza; alguien que busca)
   se decide por el título y la categoría, mirando qué va antes: «HP Z440
   Workstation 128GB RAM» es un PC; «Server RAM 16GB», memoria; «Ryzen 7
   5800X + 32 GB DDR4», una CPU con RAM. La memoria la lee memoria-modelo:
   del título y, lo que el título calla, de la descripción. *)

open Memoria_modelo
module C = Memoria_modelo.Catalogo
module T = Memoria_modelo.Texto
module G = Grafica_modelo.Texto

type tipo = Modulo | Kit | Lote | Pc | Portatil | Servidor | Placa | Cpu | Componente | Busca | Otro

let tipo_texto = function
  | Modulo -> "modulo" | Kit -> "kit" | Lote -> "lote" | Pc -> "pc" | Portatil -> "portatil" | Servidor -> "servidor" | Placa -> "placa"
  | Cpu -> "cpu" | Componente -> "componente" | Busca -> "busca" | Otro -> "otro"

let es_memoria = function Modulo | Kit | Lote -> true | _ -> false

type anuncio = {
  titulo : string;
  categoria : string;
  descripcion : string;
  precio : float option;
  portal : string;
  pais : string;
}

(* --- la entrada --------------------------------------------------------------- *)

(** «185», «185.0», «1.250 €», «88,99», «17.500»: el primer número. *)
let leer_precio s =
  let n = String.length s in
  let i = ref 0 in
  while !i < n && not (C.es_cifra s.[!i]) do incr i done;
  let j = ref !i in
  while !j < n && (C.es_cifra s.[!j] || s.[!j] = '.' || s.[!j] = ',') do incr j done;
  let t = String.sub s !i (!j - !i) in
  let t = if t <> "" && (t.[String.length t - 1] = '.' || t.[String.length t - 1] = ',') then String.sub t 0 (String.length t - 1) else t in
  if t = "" then None
  else
    let miles sep =
      (* «1.250», «17.500»: el separador va seguido de tres cifras justas. *)
      let partes = String.split_on_char sep t in
      List.length partes > 1 && List.for_all (fun p -> String.length p = 3) (List.tl partes)
    in
    let normal =
      if String.contains t '.' && String.contains t ',' then
        if String.rindex t ',' > String.rindex t '.' then G.reemplaza_todo "," "." (G.reemplaza_todo "." "" t) else G.reemplaza_todo "," "" t
      else if String.contains t ',' then if miles ',' then G.reemplaza_todo "," "" t else G.reemplaza_todo "," "." t
      else if String.contains t '.' && miles '.' then G.reemplaza_todo "." "" t
      else t
    in
    float_of_string_opt normal

(* Las etiquetas de dato ajeno («<posting>», «</posting>») no son del anuncio. *)
let sin_etiquetas s =
  String.split_on_char '\n' s
  |> List.filter (fun l ->
         let l = String.trim l in
         not (String.length l >= 3 && l.[0] = '<' && l.[String.length l - 1] = '>' && not (String.contains l ' ')))
  |> String.concat "\n"

(* «Tags: 1650 1660ti … DDR4, DDR5, ECC, non-ECC…»: las palabras clave de
   una tienda no dicen nada del anuncio. *)
let sin_palabras_clave d =
  let l = String.lowercase_ascii d in
  let corte =
    List.filter_map
      (fun m ->
        let lm = String.length m in
        let rec busca i = if i + lm > String.length l then None else if String.sub l i lm = m then Some i else busca (i + 1) in
        busca 0)
      [ "tags:"; "tags :"; "etiquetas:"; "keywords:"; "palabras clave"; "suchbegriffe"; "stichworte"; "stichwörter"; "parole chiave" ]
  in
  match corte with [] -> d | cs -> String.sub d 0 (List.fold_left min max_int cs)

let partes entrada =
  let entrada = sin_etiquetas entrada in
  let a = Grafica_anuncio.partes entrada in
  let lineas = String.split_on_char '\n' entrada in
  (* Las líneas de cabecera: hasta la descripción. *)
  let rec cabecera = function
    | [] -> []
    | l :: resto ->
      let t = String.lowercase_ascii (String.trim l) in
      if C.empieza t "descripci" then [] else l :: cabecera resto
  in
  let campo nombres =
    List.find_map
      (fun l ->
        let l = String.trim l in
        List.find_map
          (fun nombre ->
            let p = nombre ^ ":" in
            if String.length l >= String.length p && String.lowercase_ascii (String.sub l 0 (String.length p)) = String.lowercase_ascii p then
              Some (String.trim (String.sub l (String.length p) (String.length l - String.length p)))
            else None)
          nombres)
      (cabecera lineas)
  in
  {
    titulo = a.titulo;
    categoria = a.categoria;
    descripcion = sin_palabras_clave a.descripcion;
    precio = Option.bind (campo [ "Precio"; "Price"; "Preis" ]) leer_precio;
    portal = Option.value ~default:"" (campo [ "Portal" ]);
    pais = Option.value ~default:"" (campo [ "País"; "Pais"; "Country" ]);
  }

(* --- palabras de cada cosa (plegadas) -------------------------------------------- *)

let busca =
  [ "busco"; "compro"; "buscando"; "suche"; "sucht"; "suchen"; "gesucht"; "gesuch"; "ankauf"; "kaufe"; "wtb"; "cerco"; "procuro";
    "compramos"; "wir kaufen"; "we buy"; "interesado"; "interesada"; "precio mas alto"; "looking for"; "compro tu" ]

let ram =
  [ "ram"; "rams"; "memoria"; "memorias"; "memorie"; "arbeitsspeicher"; "arbeitspeicher"; "speicher"; "serverspeicher"; "ramspeicher";
    "speicherriegel"; "ramriegel"; "riegel"; "speichermodul"; "premier"; "modul"; "module"; "modulo"; "modulos"; "moduli"; "dimm"; "dimms"; "udimm";
    "rdimm"; "lrdimm"; "sodimm"; "so dimm"; "memory"; "banchi"; "simm"; "edo"; "sdram"; "ramkit"; "sd ram" ]

let portatil =
  [ "portatil"; "portatiles"; "laptop"; "notebook"; "netbook"; "macbook"; "chromebook"; "ultrabook"; "thinkpad"; "elitebook"; "probook";
    "zbook"; "latitude"; "ideapad"; "yoga"; "vivobook"; "zenbook"; "legion"; "victus"; "pavilion"; "envy"; "xps"; "zephyrus"; "aspire";
    "inspiron"; "galaxy book"; "surface laptop"; "nitro"; "omen 16"; "omen 17"; "rog strix g"; "tuf gaming f"; "tuf gaming a" ]

let pc =
  [ "pc"; "ordenador"; "ordenadores"; "torre"; "sobremesa"; "computer"; "computadora"; "rechner"; "desktop"; "workstation"; "mini pc";
    "minipc"; "imac"; "mac mini"; "mac studio"; "nuc"; "nuc8"; "barebone"; "thin client"; "prodesk"; "elitedesk"; "optiplex";
    "thinkcentre"; "z420"; "z440"; "z620"; "z640"; "z820"; "z840"; "z8"; "z4"; "z2"; "precision"; "nas"; "diskstation"; "rackstation";
    "homeserver"; "home server"; "htpc"; "setup"; "equipo"; "lockerstore"; "terramaster"; "qnap ts"; "synology ds"; "pc gamer" ]

let servidor =
  [ "servidor"; "servidores"; "server"; "rackserver"; "serverschrank"; "poweredge"; "proliant"; "sun fire"; "ucs"; "thinksystem sr";
    "primergy"; "x3690"; "x3650"; "x3550"; "nodo" ]

let placa =
  [ "placa base"; "placa madre"; "placas base"; "placa"; "mainboard"; "motherboard"; "scheda madre"; "mobo"; "server mainboard";
    "lga1200"; "lga1151"; "lga1700"; "lga 1700"; "lga2011"; "lga 2011"; "lga1851"; "lga3647"; "sockel"; "socket" ]

let cpu = [ "procesador"; "procesadores"; "cpu"; "cpus"; "prozessor"; "processore"; "epyc"; "opteron"; "core i3"; "core i5"; "core i7"; "core i9"; "amd fx" ]

let componente =
  [ "tarjeta grafica"; "tarjetas graficas"; "grafica"; "grafikkarte"; "scheda video"; "gpu"; "geforce"; "radeon"; "rtx"; "gtx"; "quadro";
    "tesla"; "firepro"; "ssd"; "nvme"; "hdd"; "disco duro"; "festplatte"; "fuente"; "netzteil"; "alimentatore"; "psu"; "caja"; "gehause";
    "monitor"; "teclado"; "raton"; "riser"; "adaptador"; "adapter"; "kuhler"; "cooler"; "ventilador"; "lufter"; "sd karten"; "sd karte";
    "micro sd"; "microsd"; "pendrive"; "usb stick"; "tarjeta de memoria"; "speicherkarte"; "piezas de ordenador"; "componentes" ]

let otro_categoria = [ "smartphones"; "tablets"; "tv"; "projector"; "consoles"; "phones"; "handys" ]

let lote = [ "lote"; "lotes"; "lotto"; "konvolut"; "sammlung"; "paket"; "posten"; "bundle"; "pack"; "conjunto"; "sammel"; "lot" ]
let mezcla = [ "verschiedene"; "varios"; "varias"; "variados"; "variadas"; "varie"; "diversi"; "diverse"; "mix"; "assorted"; "misti"; "vari"; "y otros"; "u a"; "und mehr" ]
let gratis = [ "gratis"; "free"; "geschenkt"; "dazu"; "regalo"; "de regalo"; "omaggio"; "inklusive gratis" ]
let conectores = [ "plus"; "con"; "mit"; "y"; "und"; "with"; "and"; "e"; "inkl"; "incl"; "inklusive"; "incluye" ]

(* «para», «für»: lo de detrás es con qué va. «de», «aus», solo justo delante («RAM de servidor»). *)
let para = [ "para"; "for"; "fur"; "per"; "pour"; "compatible"; "kompatibel"; "passend"; "geeignet" ]
let de = [ "de"; "aus"; "from"; "von"; "da"; "del" ]

(* El título para decidir: el «+» queda como palabra («plus»). *)
let palabras_titulo t = T.palabras (G.reemplaza_todo "+" " plus " t)

let tras_para ws i =
  (i > 0 && (List.mem ws.(i - 1) para || List.mem ws.(i - 1) de)) || (i > 1 && List.mem ws.(i - 2) para && ws.(i - 1) <> "plus")

(** La primera de [frases] en [ws] que no es un adjetivo de la memoria («Server
    RAM», «für PC», «Laptop RAM»). *)
let primera_propia ws frases =
  let n = Array.length ws in
  let rec mira i =
    if i >= n then None
    else if List.exists (T.encaja ws i) frases then
      let largo = List.fold_left (fun m f -> if T.encaja ws i f then max m (List.length (String.split_on_char ' ' f)) else m) 0 frases in
      let detras = i + largo in
      (* «Server RAM», «Server-RAM», «Server DDR4 RAM», «Server ECC RAM», «Laptop RAM»: adjetivos. *)
      let de_memoria k =
        k < n
        && (List.exists (T.encaja ws k) ram
           || (match T.trozos ws.(k) with "ddr" :: _ | [ "pc"; _ ] | [ "pc"; _; _ ] -> true | _ -> false))
      in
      let modifica = de_memoria detras || (detras + 1 < n && List.mem ws.(detras) [ "ecc"; "reg" ] && de_memoria (detras + 1)) in
      if modifica || tras_para ws i then mira (i + 1) else Some i
    else mira (i + 1)
  in
  mira 0

(* ¿Nombra un procesador? Lo de grafica-modelo más «Xeon E5-2670», «FX-6350», «i7-860». *)
let posicion_cpu ws =
  let n = Array.length ws in
  let rec mira i =
    if i >= n then None
    else
      let w = ws.(i) in
      let es =
        List.mem w [ "ryzen"; "xeon"; "celeron"; "pentium"; "athlon"; "threadripper"; "opteron"; "epyc" ]
        || (match T.trozos w with [ ("i3" | "i5" | "i7" | "i9") ] -> true | [ "i"; d ] -> List.mem d [ "3"; "5"; "7"; "9" ] | _ -> false)
        || (match T.trozos w with [ d; s ] when C.todo_cifras d && String.length d >= 4 -> List.mem s [ "x3d"; "x"; "k"; "kf"; "ks"; "f"; "hx"; "hs"; "xt"; "g"; "ge" ] | _ -> false)
        || (w = "fx" && i + 1 < n && C.todo_cifras ws.(i + 1))
        (* «96 Core», «24 Kerne», «12 Núcleos»: un procesador, de un equipo. *)
        || (i > 0 && C.todo_cifras ws.(i - 1) && List.mem w [ "core"; "cores"; "kerne"; "kernen"; "nucleos"; "nucleo" ])
        || List.exists (T.encaja ws i) cpu
      in
      if es && not (tras_para ws i) then Some i else mira (i + 1)
  in
  mira 0

(* ¿Nombra una placa? Las palabras, las plataformas de memoria-modelo y los
   modelos de placa de servidor (X10DRi, H12SSL, Z10PC-D8, S8030, MZ32). *)
let posicion_placa ws =
  let n = Array.length ws in
  (* Los zócalos y chipsets de memoria-modelo; «EPYC 7002» es una CPU, no una placa. *)
  let plataformas =
    List.concat_map (fun (p : C.placa) -> if p.tipo = "servidor" then [] else List.filter (fun a -> not (C.empieza a "epyc")) p.alias) C.placas
  in
  let modelo w =
    match T.trozos w with
    | [ ("x" | "h"); d; l ] when C.todo_cifras d && String.length d <= 2 && (l.[0] = 'd' || l.[0] = 's') -> true
    | [ "lga"; _ ] | [ "nforce"; _ ] -> true
    | [ "z"; d; l ] when C.todo_cifras d && (l.[0] = 'p') -> true
    | [ "s"; d ] when String.length d = 4 && C.todo_cifras d && (d.[0] = '8' || d.[0] = '7' || d.[0] = '5') -> true
    | [ ("mz" | "me" | "md"); d ] when String.length d = 2 -> true
    | [ l; d; s ] when String.length l = 1 && C.todo_cifras d && String.length d = 3 && String.length s <= 2 ->
      (* «B550M», «Z590M», «A320M», «X570S» *)
      List.mem (l ^ d) plataformas
    | _ -> false
  in
  let rec mira i =
    if i >= n then None
    else if (List.exists (T.encaja ws i) placa || List.exists (T.encaja ws i) plataformas || modelo ws.(i)) && not (tras_para ws i) then Some i
    else mira (i + 1)
  in
  mira 0

let antes a b = match (a, b) with Some i, Some j -> i < j | Some _, None -> true | None, _ -> false

(* ¿Va [pos] detrás de un «+», «con», «mit»… y sin «gratis» detrás? Un combo. *)
let en_combo ws pos =
  match pos with
  | Some i ->
    let n = Array.length ws in
    let unido = (i > 0 && List.mem ws.(i - 1) conectores) || (i > 1 && List.mem ws.(i - 2) conectores) in
    let regalo = List.exists (fun d -> i + d < n && List.mem ws.(i + d) gratis) [ 1; 2; 3 ] in
    unido && not regalo
  | None -> false

(* --- decidir ---------------------------------------------------------------------- *)

type decision = Decide of tipo | Defecto of string

let primera_ram ws (l : lectura) =
  let por_palabra = T.posicion ws ram in
  let por_gen = match T.generaciones ws with g :: _ -> Some g.en | [] -> None in
  let por_pn = match l.modulos with (_, i) :: _ -> Some i | [] -> None in
  List.fold_left (fun acc x -> match (acc, x) with Some a, Some b -> Some (min a b) | None, b -> b | a, None -> a) None [ por_palabra; por_gen; por_pn ]

let categoria_es (a : anuncio) ws = G.contiene a.categoria ws

(* Lo que hace de una CPU con memoria un PC: un disco, una gráfica. *)
let de_sistema = [ "ssd"; "hdd"; "nvme"; "rtx"; "gtx"; "radeon"; "geforce"; "quadro"; "win"; "windows"; "wifi"; "monitor" ]

(** Lo que es, solo por el título y la categoría: lo primero que nombra (un
    equipo, una placa, una CPU, otra pieza) si va antes que la memoria. Una
    CPU con placa es una placa; con disco o gráfica, un PC. *)
let que_es (a : anuncio) (l : lectura) =
  let ws = palabras_titulo a.titulo in
  let p_ram = primera_ram ws l in
  let p_cpu = posicion_cpu ws and p_placa = posicion_placa ws in
  let p_portatil = primera_propia ws portatil and p_pc = primera_propia ws pc and p_srv = primera_propia ws servidor in
  let p_comp = primera_propia ws componente in
  let de_portatil = categoria_es a [ "laptops"; "gaming laptops"; "notebooks" ] in
  let de_sobremesa = categoria_es a [ "desktop computers"; "gaming desktops"; "pcs" ] in
  let sistema = T.hay ws de_sistema || Array.exists (fun w -> match T.trozos w with [ _; "tb" ] -> true | _ -> false) ws in
  (* Lo primero que nombra antes que la memoria; en un empate, el orden de la lista. *)
  let primero =
    List.fold_left
      (fun acc (p, c) ->
        match (p, acc) with
        | Some i, Some (j, _) when antes p p_ram && i < j -> Some (i, c)
        | Some i, None when antes p p_ram -> Some (i, c)
        | _ -> acc)
      None
      [ (p_placa, Placa); (p_portatil, Portatil); (p_srv, Servidor); (p_pc, Pc); (p_cpu, Cpu); (p_comp, Componente) ]
  in
  (* Una CPU que no va sola: la placa o el equipo que se nombra, el de la categoría, o un PC si lleva disco o gráfica. *)
  let con_cpu () =
    if p_placa <> None then Placa
    else if p_portatil <> None || de_portatil then Portatil
    else if p_srv <> None then Servidor
    else if p_pc <> None || de_sobremesa || sistema then Pc
    else Cpu
  in
  let gpu () = Grafica_modelo.Texto.menciones a.titulo |> List.exists (fun (m : Grafica_modelo.Texto.mencion) -> m.modelo <> None) in
  if T.hay ws busca then Busca
  (* Una placa y una CPU juntas («Kit Servidor X99 + Xeon»): una placa con lo que lleve. *)
  else if p_placa <> None && (en_combo ws p_cpu || en_combo ws p_placa) then Placa
  (* Un «riser» de memoria no es memoria, aunque lo diga. *)
  else if T.hay ws [ "riser"; "risers" ] then Componente
  else if categoria_es a otro_categoria && p_ram <> Some 0 then Otro
  else
    match primero with
    | Some (_, Cpu) -> con_cpu ()
    | Some (_, Componente) ->
      if p_placa <> None && (p_cpu <> None || p_ram <> None) then Placa else if p_cpu <> None && p_ram <> None then Cpu else Componente
    | Some (_, c) -> c
    | None ->
      if en_combo ws p_placa then Placa
      else if en_combo ws p_cpu then con_cpu ()
      else if p_ram = None then
        (* Sin memoria en el título: la categoría, o lo que nombre. *)
        if de_portatil then Portatil
        else if de_sobremesa then Pc
        else if p_placa <> None then Placa
        else if p_cpu <> None then con_cpu ()
        else if p_comp <> None || gpu () then Componente
        else Otro
      else if (de_portatil || de_sobremesa) && p_ram <> Some 0 && p_cpu <> None then con_cpu ()
      else Modulo

(* --- estado y demás -------------------------------------------------------------------- *)

let negaciones = [ "sin"; "no"; "nunca"; "ningun"; "ninguna"; "nada"; "never"; "not"; "nie"; "kein"; "keine"; "keinen"; "ohne"; "without"; "nicht"; "senza"; "sem"; "nao"; "non" ]

let averiada =
  [ "fehlerhaft"; "fehlerhafte"; "memtest fehler"; "fehler im memtest"; "errores en memtest"; "error en memtest"; "da error"; "da errores";
    "bsod"; "pantallazo azul"; "pantallazos azules"; "no arranca"; "no detecta"; "nicht erkannt"; "wird nicht erkannt"; "not detected";
    "bluescreen"; "defekt"; "defekte"; "averiada"; "averiado"; "averiadas"; "estropeada"; "para piezas"; "for parts"; "broken" ]

let nuevas = [ "nuevas"; "nuevos"; "nuove"; "nuovi"; "novas"; "novos"; "neue"; "neuer"; "neues"; "ungeoffnet"; "originalverpackt"; "sealed" ]
let como = [ "como"; "casi"; "practicamente"; "wie"; "fast"; "like"; "quasi"; "come"; "semi"; "estado"; "zustand" ]

(* «NON funziona sui normali PC», «funktioniert nicht in normalen PCs»: lo que
   dice de la compatibilidad no es una avería. *)
let compatibilidad =
  [ "non funziona sui"; "non funziona su"; "non funziona con"; "no funciona en"; "no funciona con"; "no funciona en pc"; "funktioniert nicht in";
    "funktioniert nicht mit"; "funktioniert nicht auf"; "laufen nicht in"; "lauft nicht in"; "does not work in"; "does not work with";
    "will not work in"; "wont work in"; "nicht kompatibel" ]

let sin_compatibilidad s = List.fold_left (fun acc f -> G.reemplaza_todo (" " ^ f ^ " ") " " acc) (" " ^ G.pliega s ^ " ") compatibilidad

let estado (a : anuncio) =
  let a = { a with titulo = sin_compatibilidad a.titulo; descripcion = sin_compatibilidad a.descripcion } in
  let base = Grafica_anuncio.estado { Grafica_anuncio.titulo = a.titulo; categoria = a.categoria; descripcion = a.descripcion } in
  let todo = a.titulo ^ "\n" ^ a.descripcion in
  if base = "averiada" || G.dice ~negaciones todo averiada = G.Si then "averiada"
  else if base = "usada" && G.dice ~negaciones:(negaciones @ como) a.titulo nuevas = G.Si && not (G.contiene todo [ "neuwertig"; "wie neu"; "como nuevas"; "like new" ])
  then "nueva"
  else base

let tri = function G.Si -> "si" | G.No -> "no" | G.No_dice -> "?"

let garantia = [ "garantia"; "garantie"; "warranty"; "garanzia"; "gewahrleistung"; "herstellergarantie" ]
let factura = [ "factura"; "rechnung"; "invoice"; "fattura"; "ticket de compra"; "kaufbeleg"; "receipt"; "kassenbon"; "mwst"; "iva" ]
let cambio = [ "cambio"; "cambiaria"; "intercambio"; "tausch"; "tausche"; "swap"; "trade"; "scambio"; "troca" ]
let envio = [ "envio"; "envios"; "envio gratis"; "versand"; "versandkostenfrei"; "spedizione"; "spedisco"; "shipping"; "envoi"; "porto"; "dhl"; "hermes"; "correos"; "seur" ]
let solo_mano = [ "solo en mano"; "solo mano"; "solo recogida"; "nur abholung"; "nur selbstabholung"; "selbstabholung"; "kein versand"; "local pickup"; "pickup only"; "solo a mano" ]
let disipador = [ "disipador"; "heatsink"; "heatspreader"; "kuhlkorper"; "kuehlkoerper"; "kuhler"; "dissipatore"; "dissipador" ]
let rgb = [ "rgb"; "argb"; "led"; "leds" ]
let memtest = [ "memtest"; "memtest86"; "mentest"; "memtest86plus"; "testmem"; "tm5"; "karhu"; "memtester" ]
let probado = [ "getestet"; "gepruft"; "probado"; "probada"; "probados"; "probadas"; "testado"; "testada"; "testados"; "testadas"; "testeado"; "testeada"; "testato"; "testata"; "testati"; "tested"; "testet"; "verificado"; "verificada" ]
let sin_probar = [ "ungetestet"; "ungepruft"; "sin probar"; "untested"; "non testato"; "non testata"; "nao testado"; "no probado"; "no probada" ]
let divisible_si = [ "divisible"; "por separado"; "separado"; "auch einzeln"; "einzeln"; "einzelverkauf"; "individually"; "separately"; "sueltas"; "unidades sueltas"; "singolarmente"; "separati"; "tambien por unidades"; "por unidades" ]
let divisible_no = [ "nur komplett"; "verkauf nur komplett"; "solo junto"; "solo juntas"; "solo en lote"; "no se separa"; "no separo"; "nicht einzeln"; "kein einzelverkauf"; "only as a lot"; "solo lote"; "nur zusammen"; "nur als set"; "nur im set" ]
let desmontaje = [ "desmontada"; "desmontadas"; "desmontado"; "desmontados"; "desmontaje"; "extraida"; "extraidas"; "extraido"; "extraidos"; "sacada"; "sacadas"; "retirada"; "retiradas"; "ausgebaut"; "ausbau"; "pulled"; "pull"; "removed"; "smontata"; "smontate"; "smontati"; "stammen aus"; "stammt aus"; "serverauflosung"; "rechenzentrumsauflosung"; "decommissioned"; "de un servidor"; "de mi servidor"; "de mi pc"; "de un pc"; "de mi portatil"; "de un portatil"; "aus server" ]
let palabras_servidor = [ "server"; "servidor"; "servidores"; "servers"; "rechenzentrum"; "datacenter"; "rack"; "poweredge"; "proliant"; "serverauflosung"; "rechenzentrumsauflosung"; "serversystemen"; "serversystem" ]
let palabras_pc = [ "pc"; "rechner"; "ordenador"; "desktop"; "sobremesa"; "computer"; "gaming pc"; "torre" ]
let palabras_portatil = [ "laptop"; "notebook"; "portatil"; "macbook" ]

(* La procedencia: de dónde dice que se desmontó, en las seis palabras de
   alrededor del verbo («ausgebaut» detrás: «aus Serversystemen … ausgebaut»). *)
let procedencia todo =
  let ws = T.palabras todo in
  let n = Array.length ws in
  let cerca i frases = List.exists (fun k -> k >= 0 && k < n && List.exists (T.encaja ws k) frases) (List.init 13 (fun d -> i - 6 + d)) in
  let rec mira i =
    if i >= n then "?"
    else if List.exists (T.encaja ws i) desmontaje then
      if cerca i palabras_servidor then "servidor"
      else if cerca i palabras_portatil then "portatil"
      else if cerca i palabras_pc then "pc"
      else mira (i + 1)
    else mira (i + 1)
  in
  mira 0

let probado_texto todo =
  (* «memtest86», «mentest1-13»: por cómo empieza la palabra. *)
  if G.contiene todo memtest || Array.exists (fun w -> List.exists (fun p -> C.empieza w p) [ "memtest"; "mentest"; "testmem" ]) (T.palabras todo) then "memtest"
  else if G.contiene todo sin_probar then "no"
  else match G.dice ~negaciones todo probado with G.Si -> "si" | G.No -> "no" | G.No_dice -> "?"

let envio_texto todo =
  match G.dice ~negaciones todo envio with
  | G.Si -> if G.contiene todo [ "nur abholung"; "solo en mano"; "kein versand" ] then "no" else "si"
  | G.No -> "no"
  | G.No_dice -> if G.contiene todo solo_mano then "no" else "?"

let divisible_texto todo = if G.contiene todo divisible_no then "no" else if G.dice ~negaciones todo divisible_si = G.Si then "si" else "?"

(* El precio por módulo que dice el texto: «55€/ud», «600 € VB pro Riegel», «Festpreis / Stk. 400,-», «350 €/u». *)
let por_unidad = [ "ud"; "uds"; "u"; "unidad"; "stk"; "stuck"; "riegel"; "modul"; "module"; "cada"; "each"; "pz"; "pezzo"; "unit"; "piece"; "stick" ]
let marca_unidad = [ "pro"; "por"; "per"; "je"; "cada"; "each"; "a" ]

let precio_dicho todo =
  let ws = T.palabras todo in
  let n = Array.length ws in
  (* «400», «5,50» (la coma decimal queda como «d»: «5d50»). *)
  let valor i =
    if i < 0 || i >= n then None
    else
      match T.trozos ws.(i) with
      | [ d ] when C.todo_cifras d && String.length d <= 5 -> float_of_string_opt d
      | [ a; "d"; b ] when C.todo_cifras a && C.todo_cifras b && String.length a <= 5 && String.length b <= 2 -> float_of_string_opt (a ^ "." ^ b)
      | _ -> None
  in
  let es_precio i = valor i <> None in
  let rec mira i =
    if i >= n then None
    else
      let w = ws.(i) in
      (* número, [€|eur|euro|vb|,-], [pro|por|/] y la unidad *)
      let tras k = List.filter_map (fun d -> if k + d < n then Some ws.(k + d) else None) [ 1; 2; 3; 4 ] in
      let r =
        if es_precio i then
          let siguientes = tras i in
          let unidad = match siguientes with
            | ("eur" | "euro" | "euros" | "e") :: u :: _ when List.mem u por_unidad -> true
            | ("eur" | "euro" | "euros" | "e" | "vb") :: m :: u :: _ when List.mem m marca_unidad && List.mem u por_unidad -> true
            | ("eur" | "euro" | "euros" | "e") :: "vb" :: m :: u :: _ when List.mem m marca_unidad && List.mem u por_unidad -> true
            | m :: u :: _ when List.mem m marca_unidad && List.mem u por_unidad -> true
            | u :: _ when List.mem u [ "ud"; "uds" ] -> true
            | _ -> false
          in
          if unidad then valor i else None
        else if List.mem w [ "stk"; "stuck" ] && i > 0 && List.mem ws.(i - 1) [ "pro"; "je"; "festpreis" ] && es_precio (i + 1) then valor (i + 1)
        (* «Precio unitario: 90 €», «Stückpreis 400» *)
        else if List.mem w [ "unitario"; "unitaria"; "stuckpreis"; "einzelpreis"; "cadauno" ] && es_precio (i + 1) then valor (i + 1)
        else None
      in
      match r with Some _ -> r | None -> mira (i + 1)
  in
  mira 0

let precio_es_por_unidad todo =
  G.contiene todo
    [ "price for 1"; "price per module"; "price per unit"; "price per piece"; "price each"; "preis pro modul"; "preis pro stuck"; "preis pro riegel";
      "preis je"; "pro modul"; "pro riegel"; "pro stuck"; "per module"; "per stick"; "precio por unidad"; "precio por modulo"; "precio unidad";
      "precio unitario"; "por unidad"; "por modulo"; "a unidad"; "la unidad"; "stuckpreis"; "einzelpreis"; "prezzo cadauno"; "cadauno" ]

(* --- leer ------------------------------------------------------------------------------- *)

let fabricante_de (l : lectura) (pn : C.modulo option) =
  match pn with
  | Some m when not (List.mem m.fabricante C.oems) -> Some m.fabricante
  | _ -> List.find_opt (fun m -> not (List.mem m C.oems)) l.marcas

(** Lo que el título calla, de la descripción: la generación, el formato, la
    velocidad, los rangos; la cuenta solo si el título no dice capacidad. *)
let completar (t : especificacion) (d : especificacion) =
  let o a b = match a with Some _ -> a | None -> b in
  let sin_cuenta = t.capacidad = None && t.total = None in
  (* El formato dicho en el título; si no, el dicho en la descripción; si no, el deducido. *)
  let formato, formato_dicho =
    if t.formato_dicho then (t.formato, true) else if d.formato_dicho then (d.formato, true) else (o t.formato d.formato, false)
  in
  let total = if sin_cuenta then d.total else t.total in
  let modulos =
    match t.modulos with Some _ -> t.modulos | None -> if sin_cuenta || (t.total <> None && d.total = t.total) then d.modulos else None
  in
  (* «64GB» en el título y «2 x 32 GB» en la descripción: dos de 32. *)
  let capacidad =
    match ((if sin_cuenta then d.capacidad else t.capacidad), total, modulos) with
    | None, Some t, Some k when k > 0 && t mod k = 0 -> Some (t / k)
    | c, _, _ -> c
  in
  {
    generacion = o t.generacion d.generacion;
    formato;
    formato_dicho;
    ecc = o t.ecc d.ecc;
    registrada = o t.registrada d.registrada;
    velocidad = o t.velocidad d.velocidad;
    cas = o t.cas d.cas;
    rangos = o t.rangos d.rangos;
    anchura = o t.anchura d.anchura;
    voltaje = o t.voltaje d.voltaje;
    capacidad;
    total;
    modulos;
    (* Si el título dice cuánto, la descripción no lo mezcla. *)
    iguales = (if sin_cuenta then o t.iguales d.iguales else t.iguales);
    disponibles = o t.disponibles d.disponibles;
  }


(* La memoria del anuncio: lo que dice el título, completado con la
   descripción y con el part number. *)
type memoria = { lt : lectura; esp : especificacion; pn : C.modulo option; ws : string array }

let memoria_de (a : anuncio) =
  let lt = leer a.titulo in
  let ld = if a.descripcion = "" then None else Some (leer a.descripcion) in
  let ws = palabras_titulo a.titulo in
  (* El part number del título; si no, el de la descripción, si da uno solo. *)
  let pn = match (lt.modulos, ld) with (m, _) :: _, _ -> Some m | [], Some { modulos = [ (m, _) ]; _ } -> Some m | _ -> None in
  let esp = match ld with Some d -> completar lt.especificacion d.especificacion | None -> lt.especificacion in
  (* Un lote mezclado lo es antes de mirar el part number: su capacidad no es la de ese módulo. *)
  let esp = if List.length lt.generaciones >= 2 || T.hay ws mezcla then { esp with iguales = Some false } else esp in
  let esp = combinar esp pn in
  (* El ECC del texto sobre un formato sin ECC: «UDIMM ECC». *)
  let esp = match (esp.formato, esp.ecc) with Some f, Some true -> { esp with formato = Some (C.con_ecc f) } | _ -> esp in
  { lt; esp; pn; ws }

let gb_texto mb = Yojson.Safe.to_string (gb_json mb)

(** Lo que es y, si es memoria, cuántos módulos y de cuánto (o el defecto). *)
let decidir (a : anuncio) =
  match que_es a (leer a.titulo) with
  | t when not (es_memoria t) -> (Decide t, None)
  | _ ->
    let m = memoria_de a in
    let { lt; esp; ws; _ } = m in
    let de_lote = T.hay ws lote || T.hay ws mezcla in
    let d =
      (* Varias capacidades sueltas en el título («32GB 64GB 128GB 256GB»): varias ofertas; la descripción no lo arregla. *)
      if lt.varias <> [] && (not de_lote) && lt.especificacion.modulos = None then
        Defecto ("varias capacidades: " ^ String.concat ", " (List.map gb_texto lt.varias) ^ " GB")
      else if esp.iguales = Some false then Decide Lote
      else
        match (esp.modulos, esp.capacidad, esp.total) with
        | Some 1, None, _ when de_lote -> Decide Lote
        | Some 1, Some _, _ -> Decide Modulo
        | Some k, _, _ when k >= 2 ->
          (* Dos o cuatro iguales sin ECC ni registro: un kit; lo de servidor, un lote. *)
          let consumo = (not lt.servidor) && esp.ecc <> Some true && esp.registrada <> Some true in
          Decide (if de_lote || (not consumo) || k > 4 then Lote else Kit)
        | None, None, Some _ when de_lote -> Decide Lote
        | None, None, Some t -> Defecto ("no se sabe si es un módulo o un kit: " ^ gb_texto t ^ " GB")
        | _, None, None when de_lote -> Decide Lote
        | _ when lt.varias <> [] && not de_lote -> Defecto ("varias capacidades: " ^ String.concat ", " (List.map gb_texto lt.varias) ^ " GB")
        | _, None, None -> Defecto "no dice la capacidad"
        | _ -> Decide Modulo
    in
    (d, Some m)

(* --- JSON --------------------------------------------------------------------------------------- *)

let opt f = function Some x -> f x | None -> `Null
let str s = `String s
let redondea x = Float.round (x *. 100.) /. 100.

(* Un número con dos decimales como mucho: 9.95, no 9.949999999999999. *)
let numero x =
  let x = redondea x in
  if Float.is_integer x then `Int (int_of_float x)
  else
    let s = Printf.sprintf "%.2f" x in
    `Intlit (if s.[String.length s - 1] = '0' then String.sub s 0 (String.length s - 1) else s)

(* Las líneas que llevan disipador de serie. *)
let con_disipador =
  [ "Vengeance"; "Dominator"; "Fury Beast"; "Fury Renegade"; "HyperX Fury"; "HyperX Predator"; "Predator"; "Trident Z"; "Ripjaws"; "Flare X";
    "Flare X5"; "Aegis"; "Sniper X"; "Ballistix"; "Viper"; "T-Force"; "Xtreem"; "Delta"; "Lancer"; "Spectrix"; "Gammix"; "Novakey"; "Ares";
    "Bolt X"; "Cras"; "Shadow"; "Redline"; "IRDM"; "Crucial Pro"; "XLR8" ]

let json (a : anuncio) (t : tipo) (m : memoria option) : Yojson.Safe.t =
  (* Plegado una vez: las búsquedas de palabras no lo repiten. *)
  let todo = G.pliega (a.titulo ^ "\n" ^ a.descripcion) in
  let estado = estado a and garantia = tri (G.dice ~negaciones todo garantia) and factura = tri (G.dice ~negaciones todo factura) in
  let envio = envio_texto todo and cambio = tri (G.dice ~negaciones a.titulo cambio) in
  let comunes = [ ("estado", str estado); ("garantia", str garantia); ("factura", str factura); ("envio", str envio); ("cambio", str cambio); ("precio", opt numero a.precio) ] in
  let campos =
    match m with
    | Some { lt; esp; pn; _ } when es_memoria t ->
      let modulos = match (t, esp.modulos) with Modulo, _ -> Some 1 | _, m -> m in
      let iguales = match (t, esp.iguales) with Modulo, _ -> Some true | _, i -> i in
      let disipador =
        match G.dice ~negaciones todo disipador with
        | G.Si -> "si"
        | G.No -> "no"
        | G.No_dice -> if List.exists (fun l -> List.mem l con_disipador) lt.lineas then "si" else "?"
      in
      let precio_modulo =
        match (precio_dicho (a.titulo ^ "\n" ^ a.descripcion), a.precio, modulos) with
        | Some p, _, _ -> Some p
        | None, Some p, _ when precio_es_por_unidad todo -> Some p
        | None, Some p, Some k when k >= 1 -> Some (p /. float_of_int k)
        | _ -> None
      in
      [ ("modulos", opt (fun k -> `Int k) modulos);
        ("disponibles", opt (fun k -> `Int k) esp.disponibles);
        ("iguales", opt (fun b -> `Bool b) iguales);
        ("capacidad", opt gb_json (if modulos = Some 1 && esp.capacidad = None then esp.total else esp.capacidad));
        ("total", opt gb_json (match (esp.total, esp.capacidad, modulos) with Some t, _, _ -> Some t | None, Some c, Some k -> Some (c * k) | _ -> None));
        ("generacion", opt (fun g -> str (C.generacion_texto g)) esp.generacion);
        ("formato", opt (fun f -> str (C.formato_texto f)) esp.formato);
        ("ecc", opt (fun b -> `Bool b) esp.ecc);
        ("registrada", opt (fun b -> `Bool b) esp.registrada);
        ("velocidad", opt (fun v -> `Int v) esp.velocidad);
        ("cas", opt (fun v -> `Int v) esp.cas);
        ("rangos", opt (fun v -> `Int v) esp.rangos);
        ("anchura", opt (fun v -> `Int v) esp.anchura);
        ("voltaje", opt numero esp.voltaje);
        ("fabricante", opt str (fabricante_de lt pn));
        ("pn", opt (fun (m : C.modulo) -> str m.pn) pn);
        ("oem", opt str (match pn with Some { oem = Some o; _ } -> Some o | _ -> lt.oem));
        ("equivalentes", `List (match pn with Some m -> List.map str m.equivalentes | None -> []));
        ("disipador", str disipador);
        ("rgb", str (if G.contiene todo rgb || List.mem "Novakey" lt.lineas then "si" else "?"));
        ("procedencia", str (procedencia todo));
        ("probado", str (probado_texto todo));
        ("divisible", str (divisible_texto todo));
        ("precioModulo", opt numero precio_modulo) ]
    | _ ->
      List.map (fun k -> (k, `Null))
        [ "modulos"; "disponibles"; "iguales"; "capacidad"; "total"; "generacion"; "formato"; "ecc"; "registrada"; "velocidad"; "cas"; "rangos";
          "anchura"; "voltaje"; "fabricante"; "pn"; "oem"; "equivalentes"; "disipador"; "rgb"; "procedencia"; "probado"; "divisible"; "precioModulo" ]
      |> List.map (fun (k, v) -> match k with "equivalentes" -> (k, `List []) | "disipador" | "rgb" | "procedencia" | "probado" | "divisible" -> (k, str "?") | _ -> (k, v))
  in
  (* El orden del contrato: el tipo, la memoria, lo que dice el anuncio y el precio. *)
  let orden =
    [ "tipo"; "modulos"; "disponibles"; "iguales"; "capacidad"; "total"; "generacion"; "formato"; "ecc"; "registrada"; "velocidad"; "cas"; "rangos";
      "anchura"; "voltaje"; "fabricante"; "pn"; "oem"; "equivalentes"; "disipador"; "rgb"; "procedencia"; "probado"; "estado"; "garantia";
      "factura"; "envio"; "divisible"; "cambio"; "precio"; "precioModulo" ]
  in
  let todos = (("tipo", str (tipo_texto t)) :: campos) @ comunes in
  `Assoc (List.map (fun k -> (k, List.assoc k todos)) orden)

(* «Tausch 2x 64GB … gegen 8x 16GB»: lo que se ofrece es lo de antes de «gegen». *)
let ofrecido titulo =
  if not (G.contiene titulo cambio) then titulo
  else
    let ws = T.palabras titulo in
    match T.posicion ws [ "gegen"; "vs"; "por"; "contra"; "a cambio de"; "swap for"; "trade for"; "for" ] with
    | Some k when k > 1 -> String.concat " " (Array.to_list (Array.sub ws 0 k))
    | _ -> titulo

let aplicar entrada : (string, string) result =
  let a = partes entrada in
  let a = { a with titulo = ofrecido a.titulo } in
  if String.trim a.titulo = "" then Error "sin título"
  else match decidir a with Defecto m, _ -> Error m | Decide t, m -> Ok (Yojson.Safe.to_string (json a t m))

let cristal = Cristal.cristal "memoria-anuncio" aplicar
