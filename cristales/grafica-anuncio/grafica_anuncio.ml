(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: qué se vende en un anuncio de segunda mano de la categoría de
   informática. Ver SEMILLA.md.

   La entrada es el anuncio en líneas «Título: …», «Categoría: …» y
   «Descripción: …» (la descripción hasta el final); sin «Título:», todo el
   texto es el título. Lo que es (una gráfica suelta, un PC, un portátil, una
   pieza para una gráfica, un lote, alguien que busca) se decide por el
   título y la categoría; la descripción solo da el modelo si el título no lo
   dice, y el estado. *)

open Grafica_modelo

type tipo = Grafica | Antigua | Profesional | Pc | Portatil | Pieza | Componente | Busca | Lote | Otro

let tipo_texto = function
  | Grafica -> "grafica" | Antigua -> "antigua" | Profesional -> "profesional" | Pc -> "pc"
  | Portatil -> "portatil" | Pieza -> "pieza" | Componente -> "componente" | Busca -> "busca"
  | Lote -> "lote" | Otro -> "otro"

type anuncio = { titulo : string; categoria : string; descripcion : string }

let partes entrada =
  let lineas = String.split_on_char '\n' entrada in
  let campo nombre l =
    let p = nombre ^ ":" in
    let l = String.trim l in
    if String.length l >= String.length p && String.lowercase_ascii (String.sub l 0 (String.length p)) = String.lowercase_ascii p
    then Some (String.trim (String.sub l (String.length p) (String.length l - String.length p)))
    else None
  in
  let titulo = List.find_map (campo "Título") lineas |> Option.fold ~none:(List.find_map (campo "Titulo") lineas) ~some:Option.some in
  match titulo with
  | None -> { titulo = String.trim entrada; categoria = ""; descripcion = "" }
  | Some titulo ->
    let categoria = Option.value ~default:"" (List.find_map (fun l -> match campo "Categoría" l with Some c -> Some c | None -> campo "Categoria" l) lineas) in
    let rec desde = function
      | [] -> []
      | l :: resto -> ( match (campo "Descripción" l, campo "Descripcion" l) with Some d, _ | None, Some d -> d :: resto | _ -> desde resto)
    in
    { titulo; categoria; descripcion = String.trim (String.concat "\n" (desde lineas)) }

(* --- palabras de cada cosa (plegadas) ------------------------------------ *)

let busca = [ "busco"; "compro"; "buscando"; "suche"; "ich suche"; "wtb"; "looking for"; "cerco"; "procuro"; "kaufe"; "ankauf"; "compramos"; "compro tu" ]

let lote = [ "lote"; "lotes"; "pack de"; "konvolut"; "bundle"; "dos graficas"; "dos tarjetas"; "2 graficas"; "2 tarjetas graficas"; "3 tarjetas graficas"; "4 tarjetas graficas"; "zwei grafikkarten"; "mehrere grafikkarten"; "varias graficas"; "varias tarjetas" ]

(* Piezas para una gráfica: cuentan en cualquier sitio salvo detrás de un «con». *)
let pieza_fuerte =
  [ "backplate"; "disipador"; "heatsink"; "kuhler"; "wasserkuhler"; "wasserblock"; "waterblock"; "water block"; "eisblock";
    "kuhlkorper"; "egpu"; "e gpu"; "razer core"; "thermal pad"; "thermal pads"; "pasta termica"; "warmeleitpad"; "warmeleitpads";
    "shroud"; "bracket"; "anti sag"; "gpu support"; "grafikkartenhalterung"; "grafikkarten halterung"; "stutze"; "caja vacia";
    "solo caja"; "solo la caja"; "nur ovp"; "leere ovp"; "empty box"; "box only"; "nur karton"; "riser" ]

(* Solo si el título empieza por ellas: «Ventiladores para RTX 3080» es una pieza; «RTX 3080 3 ventiladores», no. *)
let pieza_debil = [ "ventilador"; "ventiladores"; "fan"; "fans"; "lufter"; "cable"; "cables"; "kabel"; "adaptador"; "adapter"; "soporte"; "support"; "halterung"; "carcasa" ]

let conectores = [ "con"; "mit"; "with"; "inkl"; "incl"; "inklusive"; "incluye"; "incluido"; "incluida"; "plus"; "y"; "und"; "and"; "e"; "avec"; "com" ]

let portatil =
  [ "portatil"; "portatiles"; "laptop"; "notebook"; "netbook"; "macbook"; "chromebook"; "ultrabook"; "razer blade"; "zephyrus";
    "legion"; "ideapad"; "thinkpad"; "victus"; "pavilion"; "nitro 5"; "nitro v"; "predator helios"; "helios"; "aspire";
    "strix scar"; "katana"; "stealth"; "raider"; "vector"; "crosshair"; "sword"; "cyborg"; "bravo"; "xps"; "envy"; "zenbook";
    "vivobook"; "surface"; "galaxy book"; "yoga"; "alienware"; "omen 15"; "omen 16"; "omen 17"; "gaming laptop" ]

(* Líneas de portátil que llevan número pegado: «GF65», «GL75», «ROG Strix G16», «TUF F15». *)
let linea_portatil palabras =
  List.exists
    (fun w ->
      let n = String.length w in
      n >= 3 && n <= 4
      && (List.exists (fun p -> String.length w > String.length p && String.sub w 0 (String.length p) = p) [ "gf"; "gl"; "gp"; "ge"; "gs" ]
          || (List.mem (String.sub w 0 1) [ "g"; "f"; "a" ] && String.for_all (fun c -> c >= '0' && c <= '9') (String.sub w 1 (n - 1)) && n = 3))
      && String.for_all (fun c -> (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z')) w
      && String.exists (fun c -> c >= '0' && c <= '9') w)
    palabras

let pc =
  [ "pc"; "ordenador"; "ordenadores"; "torre"; "sobremesa"; "setup"; "computer"; "computadora"; "computadores"; "rechner";
    "komplettsystem"; "komplett pc"; "gaming pc"; "pc gaming"; "pc gamer"; "desktop"; "workstation"; "mini pc"; "imac";
    "mac pro"; "mac mini"; "nuc"; "all in one"; "barebone"; "equipo gaming"; "equipo completo"; "omen 25l"; "omen 30l";
    "omen 40l"; "omen 45l"; "aurora"; "corsair one"; "build"; "pc completo"; "torre gaming" ]

let para = [ "para"; "for"; "fur"; "per"; "pour"; "compatible"; "kompatibel"; "fits"; "passend" ]

let componente =
  [ "procesador"; "cpu"; "prozessor"; "placa base"; "placa madre"; "motherboard"; "mainboard"; "ram"; "memoria"; "arbeitsspeicher";
    "fuente"; "fuente de alimentacion"; "netzteil"; "psu"; "ssd"; "hdd"; "disco duro"; "nvme"; "monitor"; "pantalla"; "caja";
    "gehause"; "teclado"; "raton"; "tastatur"; "maus"; "auriculares"; "headset"; "router"; "cargador"; "ladegerat"; "tarjeta de sonido";
    "soundkarte"; "tarjeta de red"; "tarjeta wifi"; "capturadora"; "webcam"; "kit ram"; "refrigeracion liquida"; "aio" ]

let palabras_gpu =
  [ "tarjeta grafica"; "tarjetas graficas"; "tarjeta de video"; "tarjeta de video"; "grafica"; "graficas"; "placa grafica"; "placa de video";
    "grafikkarte"; "grafikkarten"; "graphics card"; "video card"; "gpu"; "scheda video"; "scheda grafica"; "placa de video"; "geforce";
    "radeon"; "nvidia"; "vga" ]

let categoria_gpu = [ "grafikkarten"; "graphics cards"; "tarjetas graficas"; "schede video" ]
let categoria_portatil = [ "laptops"; "portatiles"; "notebooks"; "laptop" ]
let categoria_pc = [ "desktops"; "gaming desktops"; "ordenadores de sobremesa"; "desktop computers"; "gaming pcs"; "pc"; "sobremesa" ]

let averiada =
  [ "averiada"; "averiado"; "averia"; "rota"; "roto"; "estropeada"; "no funciona"; "para piezas"; "para reparar"; "defectuosa";
    "defectuoso"; "artefactos"; "no da imagen"; "sin imagen"; "pantallazos"; "defekt"; "defekte"; "defektiv"; "bastler";
    "fur bastler"; "kein bild"; "artefakte"; "broken"; "faulty"; "defective"; "not working"; "for parts"; "artifacts";
    "artifacting"; "no display"; "guasta"; "non funziona"; "per pezzi"; "avariada"; "nao funciona"; "para pecas" ]

let nueva =
  [ "precintada"; "precintado"; "sin abrir"; "sin estrenar"; "a estrenar"; "sin usar"; "nueva"; "nuevo"; "new"; "brand new";
    "sealed"; "unopened"; "neu"; "fabrikneu"; "versiegelt"; "ungeoffnet"; "unbenutzt"; "nuova"; "sigillata"; "nova"; "selada" ]

(* «como nueva», «wie neu», «like new»: usada, en buen estado. *)
let como = [ "como"; "casi"; "practicamente"; "wie"; "fast"; "like"; "quasi"; "come"; "semi"; "estado"; "zustand" ]

let mineria = [ "mineria"; "minado"; "minada"; "minar"; "mining"; "mined"; "minen"; "gemined"; "mineado"; "mineada"; "miner"; "rig" ]
let garantia = [ "garantia"; "garantie"; "warranty"; "garanzia"; "gewahrleistung" ]
let factura = [ "factura"; "rechnung"; "invoice"; "fattura"; "ticket de compra"; "kaufbeleg"; "receipt" ]
let caja = [ "caja original"; "con caja"; "con su caja"; "en su caja"; "caja"; "ovp"; "original box"; "box"; "originalverpackung"; "verpackung"; "karton"; "scatola"; "embalaje original" ]
let cambio = [ "cambio"; "cambiaria"; "cambia"; "intercambio"; "tausch"; "tausche"; "swap"; "trade"; "scambio"; "troca" ]

let negaciones = [ "sin"; "no"; "nunca"; "ningun"; "ninguna"; "nada"; "never"; "not"; "nie"; "niemals"; "kein"; "keine"; "keinen"; "ohne"; "without"; "nicht"; "senza"; "sem"; "nao" ]

(* --- decidir ------------------------------------------------------------ *)

let empieza_por texto frases = match Texto.posicion texto frases with Some i -> i <= 1 | None -> false

let tri = function Texto.Si -> "si" | Texto.No -> "no" | Texto.No_dice -> "?"

type decision = Decide of tipo * gpu option | Defecto of string

(* Las gráficas que ofrece el título: lo que va detrás de «cambio por», «tausch gegen» es lo que quiere a cambio. *)
let ofrecidas titulo =
  let corte = Texto.posicion titulo [ "cambio por"; "cambiaria por"; "tausch gegen"; "tausche gegen"; "tausch"; "swap for"; "trade for"; "o cambio por"; "por" ] in
  match corte with
  | Some k ->
    let palabras = Texto.palabras titulo in
    let antes = String.concat " " (List.filteri (fun i _ -> i < k) palabras) in
    let l = leer antes in
    if l.modelos = [] && l.desconocidos = [] then leer titulo else l
  | None -> leer titulo

let decidir a =
  let t = a.titulo in
  let ws = Texto.palabras t in
  let lt = ofrecidas t in
  let hay_modelo = lt.modelos <> [] || lt.desconocidos <> [] || lt.antiguas <> [] || lt.profesionales <> [] in
  let primer_modelo =
    List.fold_left min max_int (List.map (fun (x : Texto.mencion) -> x.palabra) (Texto.menciones t))
  in
  let gpu_al_principio = empieza_por t palabras_gpu in
  let cat w = Texto.contiene a.categoria w in
  let pieza () =
    match Texto.posicion t pieza_fuerte with
    | Some i ->
      (* Detrás del modelo y de un «con»/«mit»/«+»: viene con la gráfica, no es la pieza. *)
      not (primer_modelo < i && List.exists (fun c -> match Texto.posicion t [ c ] with Some k -> k > primer_modelo && k < i | None -> false) conectores)
    | None -> empieza_por t pieza_debil && not gpu_al_principio
  in
  let pc_dicho () =
    (* «para PC» no es un PC. *)
    match Texto.posicion t pc with
    | Some i -> not (i > 0 && List.mem (List.nth ws (i - 1)) para)
    | None -> false
  in
  let sistema = Texto.menciona_cpu t && hay_modelo in
  (* «Busco RTX 3080», «[SUCHE] RTX 3080», «✨SUCHE: …»: en las tres primeras palabras. *)
  if Option.fold ~none:false ~some:(fun i -> i <= 2) (Texto.posicion t busca) then Decide (Busca, None)
  else if Texto.contiene t lote then Decide (Lote, None)
  else if pieza () then Decide (Pieza, None)
  else if Texto.contiene t portatil || linea_portatil ws || Texto.menciona_cpu_portatil t
          || (cat categoria_portatil && not gpu_al_principio) then Decide (Portatil, None)
  else if (pc_dicho () && not gpu_al_principio) || sistema || (cat categoria_pc && not gpu_al_principio && not (Texto.contiene t palabras_gpu)) then
    Decide (Pc, None)
  else if empieza_por t componente && not gpu_al_principio then Decide (Componente, None)
  else
    match (lt.modelos, lt.desconocidos) with
    | [ g ], [] -> Decide (Grafica, Some g)
    | [], [] when lt.antiguas <> [] -> Decide (Antigua, None)
    | [], [] when lt.profesionales <> [] -> Decide (Profesional, None)
    | [], d :: _ -> Defecto ("modelo desconocido: " ^ d)
    | _ :: _ :: _, _ | _ :: _, _ :: _ ->
      Defecto ("varios modelos: " ^ String.concat ", " (List.map (fun g -> g.modelo.Catalogo.clave) lt.modelos @ lt.desconocidos))
    | [], [] ->
      if Texto.contiene t componente then Decide (Componente, None)
      else if Texto.contiene t palabras_gpu || cat categoria_gpu then
        (* Sin modelo en el título: el de la descripción, si es uno solo. *)
        match leer a.descripcion with
        | { modelos = [ g ]; desconocidos = []; _ } -> Decide (Grafica, Some g)
        | _ -> Defecto "gráfica sin modelo"
      else Decide (Otro, None)

let estado a =
  let todo = a.titulo ^ "\n" ^ a.descripcion in
  if Texto.dice ~negaciones todo averiada = Texto.Si then "averiada"
  else if Texto.dice ~negaciones:(negaciones @ como) todo nueva = Texto.Si
          && not (Texto.contiene todo [ "neuwertig"; "seminueva"; "seminuevo"; "como nueva"; "como nuevo"; "wie neu"; "like new" ])
  then "nueva"
  else "usada"

let json a (t : tipo) (g : gpu option) : Yojson.Safe.t =
  let todo = a.titulo ^ "\n" ^ a.descripcion in
  let o f = match g with Some g -> f g | None -> `Null in
  `Assoc
    [ ("tipo", `String (tipo_texto t));
      ("modelo", o (fun g -> `String g.modelo.clave));
      ("nombre", o (fun g -> `String g.modelo.nombre));
      ("fabricante", o (fun g -> `String (Catalogo.fabricante_texto g.modelo.fabricante)));
      ("vram", o (fun g -> `Int (Texto.memoria_de g.modelo todo)));
      ("anyo", o (fun g -> `Int g.modelo.anyo));
      ("pvp", o (fun g -> match g.modelo.pvp with Some p -> `Int p | None -> `Null));
      ("rendimiento", o (fun g -> `Int g.modelo.rendimiento));
      ("estado", `String (estado a));
      ("mineria", `String (tri (Texto.dice ~negaciones todo mineria)));
      ("garantia", `String (tri (Texto.dice ~negaciones todo garantia)));
      ("factura", `String (tri (Texto.dice ~negaciones todo factura)));
      ("caja", `String (tri (Texto.dice ~negaciones todo caja)));
      ("cambio", `String (tri (Texto.dice ~negaciones a.titulo cambio))) ]

let aplicar entrada : (string, string) result =
  let a = partes entrada in
  if String.trim a.titulo = "" then Error "sin título"
  else
    match decidir a with
    | Defecto m -> Error m
    | Decide (t, g) -> Ok (Yojson.Safe.to_string (json a t g))

let cristal = Cristal.cristal "grafica-anuncio" aplicar
