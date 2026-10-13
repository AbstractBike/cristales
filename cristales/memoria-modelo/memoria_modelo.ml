(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: la memoria que nombra un texto (los part numbers que trae, con
   lo que dicen; lo que el texto dice de ella; las placas y servidores que
   nombra, con la memoria que admiten). Ver SEMILLA.md. *)

module Catalogo = Catalogo
module Texto = Texto
open Catalogo

type especificacion = {
  generacion : generacion option;
  formato : formato option;
  formato_dicho : bool;  (** El formato lo dice el texto o su etiqueta; si no, se ha deducido (y un part number manda). *)
  ecc : bool option;
  registrada : bool option;
  capacidad : int option;  (** MB por módulo. *)
  modulos : int option;
  total : int option;  (** MB. *)
  iguales : bool option;
  disponibles : int option;
  velocidad : int option;
  cas : int option;
  rangos : int option;
  anchura : int option;
  voltaje : float option;
}

type lectura = {
  modulos : (modulo * int) list;  (** Los part numbers leídos, con la palabra donde empiezan. *)
  desconocidos : string list;
  especificacion : especificacion;  (** Lo que dice el texto, sin los part numbers. *)
  generaciones : generacion list;  (** Las que nombra, sin repetir. *)
  velocidades : int list;
  varias : int list;  (** Capacidades (MB) sueltas que no casan entre sí. *)
  placas : placa list;
  marcas : string list;
  oem : string option;
  lineas : string list;
  kit : bool;
  servidor : bool;
  portatil : bool;
}

(* --- marcas, OEM y líneas ------------------------------------------------------- *)

let para = [ "para"; "for"; "fur"; "per"; "pour"; "compatible"; "kompatibel"; "passend"; "geeignet"; "fits"; "compatibile" ]

let marcas ws =
  List.filter_map (fun (w, m) -> Option.map (fun p -> (p, m)) (Texto.posicion ws [ w ])) Catalogo.marcas
  |> List.sort compare
  |> List.fold_left (fun acc (_, m) -> if List.mem m acc then acc else acc @ [ m ]) []

(** La marca de la etiqueta: HPE, Dell, Lenovo…; no la de «für HP Z620» ni
    cuando nombra varias («Dell HP Lenovo»: con qué es compatible). *)
let oem ws ms =
  let propios = List.filter (fun m -> List.mem m Catalogo.oems && m <> "synology" && m <> "qnap") ms in
  let n = Array.length ws in
  let tras_para m =
    let alias = List.filter_map (fun (w, k) -> if k = m then Some w else None) Catalogo.marcas in
    let rec mira i = i < n && ((List.exists (Texto.encaja ws i) alias && i > 0 && (List.mem ws.(i - 1) para || (i > 1 && List.mem ws.(i - 2) para))) || mira (i + 1)) in
    mira 0
  in
  match List.filter (fun m -> not (tras_para m)) propios with [ m ] -> Some m | _ -> None

(* Las líneas de los kits de juego: con disipador; las que dicen «Impact», de portátil. *)
let lineas_juego =
  [ ("vengeance", "Vengeance"); ("dominator", "Dominator"); ("fury beast", "Fury Beast"); ("fury renegade", "Fury Renegade");
    ("hyperx fury", "HyperX Fury"); ("hyperx predator", "HyperX Predator"); ("predator", "Predator"); ("trident", "Trident Z");
    ("tridentz", "Trident Z"); ("ripjaws", "Ripjaws"); ("ripsaw", "Ripjaws"); ("flare x", "Flare X"); ("flare x5", "Flare X5"); ("aegis", "Aegis");
    ("sniper", "Sniper X"); ("ballistix", "Ballistix"); ("viper", "Viper"); ("t force", "T-Force"); ("tforce", "T-Force"); ("xtreem", "Xtreem");
    ("delta", "Delta"); ("t create", "T-Create"); ("lancer", "Lancer"); ("spectrix", "Spectrix"); ("gammix", "Gammix"); ("novakey", "Novakey");
    ("ares", "Ares"); ("bolt x", "Bolt X"); ("cras", "Cras"); ("shadow", "Shadow"); ("redline", "Redline"); ("irdm", "IRDM");
    ("crucial pro", "Crucial Pro"); ("game pro", "Game Pro"); ("elite", "Elite"); ("xlr8", "XLR8");
    (* Fury y HyperX, de sobremesa salvo «Impact», que va antes. *)
    ("fury", "Fury"); ("hyperx", "HyperX"); ("hyper x", "HyperX") ]

let lineas_portatil = [ ("fury impact", "Fury Impact"); ("impact", "Impact") ]

let lineas ws =
  List.filter_map (fun (w, l) -> if Texto.hay ws [ w ] then Some l else None) (lineas_portatil @ lineas_juego)
  |> List.sort_uniq compare

let de_juego ws = List.exists (fun (w, _) -> Texto.hay ws [ w ]) lineas_juego
let de_portatil_linea ws = List.exists (fun (w, _) -> Texto.hay ws [ w ]) lineas_portatil

(* --- leer -------------------------------------------------------------------------- *)

let palabras_ram = [ "ram"; "memoria"; "memorias"; "memoria ram"; "arbeitsspeicher"; "speicher"; "dimm"; "udimm"; "rdimm"; "lrdimm"; "sodimm"; "ecc"; "reg"; "memory"; "riegel" ]
let palabras_servidor = [ "server"; "servidor"; "servidores"; "serveur"; "serverspeicher"; "serverram"; "server ram"; "datacenter"; "rack" ]

let primera xs = match xs with x :: _ -> Some x | [] -> None
let sin_repetir xs = List.fold_left (fun acc x -> if List.mem x acc then acc else acc @ [ x ]) [] xs

let placas ws =
  let n = Array.length ws in
  List.filter_map
    (fun (p : placa) ->
      let rec mira i = if i >= n then None else if List.exists (Texto.encaja ws i) p.alias then Some i else mira (i + 1) in
      Option.map (fun i -> (i, p)) (mira 0))
    Catalogo.placas
  |> List.sort (fun (a, _) (b, _) -> compare a b)
  |> List.map snd
  |> List.fold_left (fun acc (p : placa) -> if List.exists (fun (q : placa) -> q.clave = p.clave) acc then acc else acc @ [ p ]) []

let modulos_de ws =
  let n = Array.length ws in
  let rec ir i acc =
    if i >= n then List.rev acc
    else
      match Catalogo.modulo_en ws i with
      | Some (m, toma) -> ir (i + toma) ((m, i) :: acc)
      | None -> ir (i + 1) acc
  in
  ir 0 []

(** El formato: el que se dice o el de la etiqueta; si no, lo que se deduce
    (registrada, o con chips x4, es RDIMM: no hay UDIMM con chips x4; un
    portátil, SO-DIMM; un kit de juego o un sobremesa, DIMM sin registro). Con
    ECC, el de ECC. El del part number lo pone [combinar]. *)
let resolver_formato ~dicho ~etiqueta ~ecc ~registrada ~anchura ~portatil ~sobremesa ~juego =
  let base =
    match (dicho, etiqueta) with
    | Some f, _ | None, Some f -> Some f
    | None, None ->
      if registrada = Some true || anchura = Some 4 then Some Rdimm
      else if portatil && not sobremesa then Some Sodimm
      else if registrada = Some false && ecc = Some true then Some Ecc_udimm
      else if juego || (sobremesa && (not portatil) && ecc <> Some true) then Some Udimm
      else None
  in
  match (base, ecc) with
  | Some f, Some true -> Some (con_ecc f)
  | b, _ -> b

let leer texto =
  let ws = Texto.palabras texto in
  let gens = Texto.generaciones ws in
  let mods = modulos_de ws in
  let pn_de f = primera (List.filter_map (fun (m, _) -> f m) mods) in
  let ms = marcas ws in
  let contexto = gens <> [] || Texto.hay ws palabras_ram in
  let ecc_t = Texto.ecc ws and reg_t = Texto.registrada ws in
  let dicho = Texto.formato_dicho ws and etiqueta = Texto.formato_de_etiqueta ws in
  let portatil = Texto.hay ws Texto.de_portatil || de_portatil_linea ws in
  let sobremesa = Texto.hay ws Texto.de_sobremesa in
  let juego = de_juego ws in
  let vels = sin_repetir (List.map fst (Texto.velocidades_dichas ~contexto ws gens)) in
  (* La generación que se dice; si no, la de la velocidad cuando solo una la tiene (2933, 3200: DDR4). *)
  let generacion = match (gens, vels) with g :: _, _ -> Some g.gen | [], v :: _ -> generacion_de_velocidad v | [], [] -> None in
  let rangos, anchura = Texto.rangos ws in
  let formato = resolver_formato ~dicho ~etiqueta ~ecc:ecc_t ~registrada:reg_t ~anchura ~portatil ~sobremesa ~juego in
  let consumo =
    ecc_t = Some false || juego || portatil || sobremesa
    || (match formato with Some (Udimm | Sodimm | Cudimm | Csodimm) -> true | _ -> false)
  in
  let servidor =
    ecc_t = Some true || reg_t = Some true || Texto.hay ws palabras_servidor
    || (match formato with Some (Rdimm | Lrdimm | Rdimm_3ds | Mrdimm | Fbdimm) -> true | _ -> false)
  in
  let gen_pn = pn_de (fun m -> m.generacion) in
  let cuenta = Texto.contar ?gen:(match generacion with Some g -> Some g | None -> gen_pn) ?formato ~servidor ~consumo ws in
  let especificacion =
    {
      generacion;
      formato;
      formato_dicho = dicho <> None || etiqueta <> None;
      ecc = (match ecc_t with Some _ -> ecc_t | None -> Option.bind formato ecc_de);
      registrada = (match reg_t with Some _ -> reg_t | None -> Option.bind formato registrada_de);
      capacidad = cuenta.capacidad;
      modulos = cuenta.modulos;
      total = cuenta.total_mb;
      iguales = cuenta.iguales;
      disponibles = cuenta.disponibles;
      velocidad = (match vels with [] -> None | v :: _ -> Some v);
      cas = Texto.cas ws;
      rangos;
      anchura;
      voltaje = Texto.voltaje texto gens;
    }
  in
  let desconocidos =
    let usadas = List.concat_map (fun (m, i) -> [ i; i + 1 ] |> List.filter (fun _ -> m.pn <> "")) mods in
    Array.to_list (Array.mapi (fun i w -> (i, w)) ws)
    |> List.filter_map (fun (i, w) -> if Catalogo.parece_pn w && not (List.mem i usadas) then Some (String.uppercase_ascii w) else None)
    |> sin_repetir
  in
  {
    modulos = mods;
    desconocidos;
    especificacion;
    generaciones = sin_repetir (List.map (fun g -> g.Texto.gen) gens);
    velocidades = vels;
    varias = cuenta.varias;
    placas = placas ws;
    marcas = ms;
    oem = oem ws ms;
    lineas = lineas ws;
    kit = cuenta.kit;
    servidor;
    portatil;
  }

(** La especificación del texto completada con la del part number (el texto
    manda; el part number da lo que el texto calla). *)
let combinar (e : especificacion) (m : modulo option) =
  match m with
  | None -> e
  | Some m ->
    let o a b = match a with Some _ -> a | None -> b in
    (* El formato que dice el texto manda; el deducido («para portátil», una
       línea de juego) cede ante el del part number. *)
    let formato = match (e.formato, m.formato) with Some f, _ when e.formato_dicho -> Some f | _, Some f -> Some f | f, None -> f in
    let formato = match (formato, e.ecc) with Some f, Some true -> Some (con_ecc f) | f, _ -> f in
    (* «8x M393A8G40AB2-CWE 64GB»: el texto leyó los 64 GB como el total de los
       ocho; el part number dice que son los de cada módulo. *)
    let capacidad, total =
      match (e.capacidad, e.total, e.modulos, m.capacidad) with
      | Some c, Some t, Some k, Some mc when k > 1 && c <> mc && t = mc && e.iguales <> Some false -> (Some mc, Some (mc * k))
      | _ -> (o e.capacidad m.capacidad, e.total)
    in
    {
      e with
      generacion = o e.generacion m.generacion;
      formato;
      ecc = o e.ecc (match m.ecc with Some _ -> m.ecc | None -> Option.bind formato ecc_de);
      registrada = o e.registrada (match m.registrada with Some _ -> m.registrada | None -> Option.bind formato registrada_de);
      capacidad;
      total;
      velocidad = o e.velocidad m.velocidad;
      cas = o e.cas m.cas;
      rangos = o e.rangos m.rangos;
      anchura = o e.anchura m.anchura;
      voltaje = o e.voltaje m.voltaje;
    }

(* --- JSON ------------------------------------------------------------------------------ *)

let opt f = function Some x -> f x | None -> `Null
let str s = `String s
let entero i = `Int i
let booleano b = `Bool b

(** GB: entero si lo es; 0.5 para 512 MB. *)
let gb_json mb = if mb mod 1024 = 0 then `Int (mb / 1024) else `Float (float_of_int mb /. 1024.)

let lista f xs = `List (List.map f xs)

let json_modulo (m : modulo) : Yojson.Safe.t =
  `Assoc
    [ ("pn", str m.pn);
      ("fabricante", str m.fabricante);
      ("oem", opt str m.oem);
      ("equivalentes", lista str m.equivalentes);
      ("linea", opt str m.linea);
      ("generacion", opt (fun g -> str (generacion_texto g)) m.generacion);
      ("formato", opt (fun f -> str (formato_texto f)) m.formato);
      ("ecc", opt booleano m.ecc);
      ("registrada", opt booleano m.registrada);
      ("capacidad", opt gb_json m.capacidad);
      ("modulos", entero m.modulos);
      ("velocidad", opt entero m.velocidad);
      ("cas", opt entero m.cas);
      ("rangos", opt entero m.rangos);
      ("anchura", opt entero m.anchura);
      ("voltaje", opt (fun v -> `Float v) m.voltaje) ]

let json_placa (p : placa) : Yojson.Safe.t =
  `Assoc
    [ ("clave", str p.clave);
      ("nombre", str p.nombre);
      ("tipo", str p.tipo);
      ("generaciones", lista (fun g -> str (generacion_texto g)) p.generaciones);
      ("formatos", lista (fun f -> str (formato_texto f)) p.formatos);
      ("ecc", str (ecc_placa_texto p.ecc));
      ("ranuras", opt entero p.ranuras);
      ("canales", opt entero p.canales);
      ("velocidad", opt entero p.velocidad);
      ("maximo", opt entero p.maximo) ]

let especificacion_vacia (e : especificacion) =
  e.generacion = None && e.formato = None && e.ecc = None && e.registrada = None && e.capacidad = None && e.modulos = None
  && e.total = None && e.velocidad = None && e.cas = None && e.rangos = None && e.anchura = None && e.voltaje = None

let json_especificacion (e : especificacion) : Yojson.Safe.t =
  if especificacion_vacia e then `Null
  else
    `Assoc
      [ ("generacion", opt (fun g -> str (generacion_texto g)) e.generacion);
        ("formato", opt (fun f -> str (formato_texto f)) e.formato);
        ("ecc", opt booleano e.ecc);
        ("registrada", opt booleano e.registrada);
        ("capacidad", opt gb_json e.capacidad);
        ("modulos", opt entero e.modulos);
        ("total", opt gb_json e.total);
        ("velocidad", opt entero e.velocidad);
        ("cas", opt entero e.cas);
        ("rangos", opt entero e.rangos);
        ("anchura", opt entero e.anchura);
        ("voltaje", opt (fun v -> `Float v) e.voltaje) ]

let aplicar texto : (string, string) result =
  let l = leer texto in
  if l.modulos = [] && l.placas = [] && especificacion_vacia l.especificacion then
    match l.desconocidos with
    | d :: _ -> Error ("part number desconocido: " ^ d)
    | [] -> Error "no nombra ningún módulo de memoria"
  else
    Ok
      (Yojson.Safe.to_string
         (`Assoc
            [ ("modulos", lista (fun (m, _) -> json_modulo m) l.modulos);
              ("especificacion", json_especificacion l.especificacion);
              ("placas", lista json_placa l.placas);
              ("desconocidos", lista str l.desconocidos);
              ("marcas", lista str (sin_repetir (l.marcas @ List.map (fun ((m : modulo), _) -> m.fabricante) l.modulos))) ]))

let cristal = Cristal.cristal "memoria-modelo" aplicar
