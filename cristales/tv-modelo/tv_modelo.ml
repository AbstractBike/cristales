(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: los televisores que nombra un texto (o que pide alguien al darse
   de alta en smarttv.email), con su serie del catálogo y lo que pide: tamaños,
   tecnologías, marcas, Hz. Ver SEMILLA.md. *)

module Catalogo = Catalogo
module Texto = Texto
module C = Catalogo

type tele = {
  familia : Texto.familia;
  pulgadas : int option;
  modelo : string;  (** Canónico: «LG OLED77C6», «Hisense 75U7SE», «Samsung TQ77S95H»; sin tamaño, «LG OLED C6». *)
  serie : string;
  anio : int option;
  tecnologia : C.tecnologia option;
  gama : C.gama option;
  hz : int option;
  hdmi21 : bool option;
  sistema : C.sistema option;
  ocho_k : bool;
  precio_nuevo : float option;
  precio_lanzamiento : float option;
}

type lectura = {
  teles : tele list;  (** Una vez cada una, en el orden del texto. *)
  desconocidos : string list;  (** Las que lee de un código pero no están en el catálogo («Samsung TQ65S99H»). *)
  pulgadas : int list;
  tecnologias : C.tecnologia list;
  marcas : string list;
  hz : int option;
}

(* --- el modelo canónico ------------------------------------------------------- *)

(* «u7spro» -> «U7S PRO». *)
let codigo_hisense clave =
  let n = String.length clave in
  if n > 3 && String.sub clave (n - 3) 3 = "pro" then String.uppercase_ascii (String.sub clave 0 (n - 3)) ^ " PRO" else String.uppercase_ascii clave

(* La serie de una Hisense es su familia: «u7se» -> «U7», «a85n» -> «A85», «uxk» -> «UX». *)
let familia_hisense clave =
  if Texto.empieza clave "ux" then "UX"
  else
    let n = String.length clave in
    let i = ref 0 in
    while !i < n && Texto.es_letra clave.[!i] do incr i done;
    let j = ref !i in
    while !j < n && Texto.es_cifra clave.[!j] do incr j done;
    let digitos = String.sub clave !i (!j - !i) in
    let letras = String.sub clave 0 !i in
    String.uppercase_ascii (letras ^ if letras = "a" || digitos = "" then digitos else String.make 1 digitos.[0])

let es_oled (f : Texto.familia) =
  match f.entrada with Some { tecnologia = Some (C.Oled | C.Qd_oled); _ } -> true | Some _ -> false | None -> f.tecnologia = Some C.Oled

let modelo_de (f : Texto.familia) pulgadas =
  let marca = C.nombre_marca f.marca in
  let nombre = match f.entrada with Some e -> e.serie | None -> f.codigo in
  let p = match pulgadas with Some p -> string_of_int p | None -> "" in
  let con_tamano = pulgadas <> None in
  let codigo = if f.marca = "hisense" && f.entrada <> None && f.codigo = String.uppercase_ascii f.clave then codigo_hisense f.clave else f.codigo in
  match f.marca with
  | "lg" when es_oled f -> if con_tamano then Printf.sprintf "LG OLED%s%s" p codigo else "LG OLED " ^ codigo
  | "samsung" when con_tamano -> Printf.sprintf "Samsung %s%s%s" (if f.crystal then "UE" else "TQ") p codigo
  | "samsung" | "sony" | "philips" | "panasonic" when not con_tamano -> marca ^ " " ^ nombre
  | "panasonic" -> Printf.sprintf "Panasonic TX-%s%s" p codigo
  | "xiaomi" ->
    (* «Xiaomi TV S Mini LED 75 2025»: Xiaomi no pone el año en el código, el canónico lo lleva. *)
    let anio = match f.entrada with Some { anio = Some a; _ } when not f.generica -> " " ^ string_of_int a | _ -> "" in
    "Xiaomi TV " ^ nombre ^ (if con_tamano then " " ^ p else "") ^ anio
  | _ -> Printf.sprintf "%s %s%s" marca p codigo

let tele (f : Texto.familia) pulgadas =
  let e = f.entrada in
  let de g = Option.bind e g in
  let anio = if f.generica then None else match de (fun e -> e.anio) with Some a -> Some a | None -> f.anio in
  let sistema =
    match de (fun e -> e.sistema) with
    | Some s -> Some s
    | None -> (
      (* Las LG y las Samsung con Smart TV de 2016 en adelante: webOS y Tizen, sin excepción. *)
      match (f.marca, anio) with
      | "lg", Some a when a >= 2016 -> Some C.Webos
      | "samsung", Some a when a >= 2016 -> Some C.Tizen
      | _ -> None)
  in
  let precio xs = match (pulgadas, e) with Some p, Some _ when not f.generica -> List.assoc_opt p xs | _ -> None in
  {
    familia = f;
    pulgadas;
    modelo = modelo_de f pulgadas;
    serie = (match e with Some e -> e.serie | None -> if f.marca = "hisense" then familia_hisense f.clave else f.codigo);
    anio;
    tecnologia = (match de (fun e -> e.tecnologia) with Some t -> Some t | None -> f.tecnologia);
    gama = (match de (fun e -> e.gama) with Some g -> Some g | None -> C.gama_deducida f.marca f.clave);
    hz = (if f.generica then None else de (fun e -> e.hz));
    hdmi21 = de (fun e -> e.hdmi21);
    sistema;
    ocho_k = f.ocho_k;
    precio_nuevo = precio (match e with Some e -> e.precio_nuevo | None -> []);
    precio_lanzamiento = precio (match e with Some e -> e.precio_lanzamiento | None -> []);
  }

(* --- leer ----------------------------------------------------------------------- *)

let misma (a : Texto.familia) (b : Texto.familia) =
  a.marca = b.marca && (a.clave = b.clave || match (a.entrada, b.entrada) with Some x, Some y -> x == y | _ -> false)

(** Las familias que nombra el texto, en orden, con el tamaño de su código; las nombradas sin
    código que repiten una con código, fuera. *)
let menciones texto =
  let cods = List.filter_map (fun (c : Texto.codigo) -> c.mencion) (Texto.codigos texto) in
  let sers = List.filter (fun (s : Texto.mencion) -> not (List.exists (fun (c : Texto.mencion) -> misma c.familia s.familia) cods)) (Texto.series texto) in
  List.sort (fun (a : Texto.mencion) b -> compare a.pos b.pos) (cods @ sers)

(** Los tamaños que dice el texto (sin los de un soporte, «hasta 75″»), en orden y sin repetir: los de
    las unidades, los de los códigos y, si [sueltas], los números sueltos de los tamaños que se fabrican. *)
let tamanos ?(sueltas = true) ?(cm = true) texto =
  let ms = List.filter (fun (m : Texto.medida) -> not m.compat) (Texto.medidas ~sueltas ~cm texto) in
  let de_codigos =
    List.filter_map
      (fun (c : Texto.codigo) ->
        match (c.mencion, c.solo_pulgadas) with
        | Some { pulgadas = Some p; pos; _ }, _ -> Some (p, pos)
        | _, Some (p, pos) -> Some (p, pos)
        | _ -> None)
      (Texto.codigos texto)
  in
  let todos = List.sort (fun (_, a) (_, b) -> compare a b) (List.map (fun (m : Texto.medida) -> (m.valor, m.pos)) ms @ de_codigos) in
  List.fold_left (fun acc (v, _) -> if List.mem v acc then acc else acc @ [ v ]) [] todos, todos

let leer ?(sueltas = true) texto =
  let ms = menciones texto in
  let lista, con_pos = tamanos ~sueltas texto in
  let tecs = Texto.tecnologias_en texto in
  (* El tamaño de una serie nombrada sin código: el que va justo detrás («LG C6 77»); si no, el que va
     con su tecnología («una OLED de 77 o una mini-LED de 75, LG C6 o Hisense U7»); si no, el único del
     texto; si no, el de justo delante («77 Zoll LG C6»). *)
  let tamano_de (m : Texto.mencion) =
    let suya = (tele m.familia None).tecnologia in
    let primero = function (p, _) :: _ -> Some p | [] -> None in
    let detras = List.filter (fun (_, pos) -> pos > m.pos && pos - m.pos <= 3) con_pos in
    let delante = List.filter (fun (_, pos) -> pos < m.pos && m.pos - pos <= 2) (List.rev con_pos) in
    let con_tec =
      List.filter
        (fun (_, pos) -> List.exists (fun (t, tp) -> Some t = suya && tp < pos && pos - tp <= 3) tecs)
        con_pos
    in
    match m.pulgadas with
    | Some p -> Some p
    | None -> (
      match primero detras with
      | Some p -> Some p
      | None -> (
        match (primero con_tec, lista) with
        | Some p, _ -> Some p
        | None, [ p ] -> Some p
        | None, _ -> primero delante))
  in
  let teles =
    List.fold_left
      (fun acc (m : Texto.mencion) ->
        let t = tele m.familia (tamano_de m) in
        if List.exists (fun x -> x.modelo = t.modelo) acc then acc else acc @ [ t ])
      [] ms
  in
  {
    teles;
    desconocidos = List.filter_map (fun t -> if t.familia.entrada = None then Some t.modelo else None) teles;
    pulgadas = lista;
    tecnologias = Texto.tecnologias texto;
    marcas = Texto.marcas texto;
    hz = Texto.hz texto;
  }

(* --- JSON ----------------------------------------------------------------------- *)

let opt f = function Some x -> f x | None -> `Null
let str s = `String s
let lista xs = `List (List.map str xs)

let json_tele (t : tele) : Yojson.Safe.t =
  `Assoc
    [ ("marca", str t.familia.marca);
      ("modelo", str t.modelo);
      ("serie", str t.serie);
      ("anio", opt (fun a -> `Int a) t.anio);
      ("pulgadas", opt (fun p -> `Int p) t.pulgadas);
      ("tecnologia", opt (fun x -> str (C.tecnologia_texto x)) t.tecnologia);
      ("gama", opt (fun x -> str (C.gama_texto x)) t.gama);
      ("precio_lanzamiento", opt (fun x -> `Float x) t.precio_lanzamiento);
      ("precio_nuevo", opt (fun x -> `Float x) t.precio_nuevo);
      ("hz", opt (fun x -> `Int x) t.hz);
      ("sistema", opt (fun x -> str (C.sistema_texto x)) t.sistema);
      ("en_catalogo", `Bool (t.familia.entrada <> None)) ]

(* «75 pulgadas o más», «mínimo 65», «ab 75 Zoll». *)
let como_minimo = [ "o mas"; "or more"; "oder mehr"; "oder grosser"; "o superior"; "o mayor"; "minimo"; "al menos"; "a partir de"; "mindestens"; "ab"; "at least"; "or bigger"; "or larger"; "o piu"; "ou mais"; "ou plus"; "como poco"; "mas de"; "plus" ]

let aplicar texto : (string, string) result =
  let l = leer texto in
  if l.teles = [] && l.pulgadas = [] && l.tecnologias = [] && l.marcas = [] then Error "no nombra ninguna tele, ni tamaño, ni tecnología, ni marca"
  else
    let minimo = if l.pulgadas <> [] && Texto.G.contiene texto como_minimo then Some (List.fold_left min max_int l.pulgadas) else None in
    Ok
      (Yojson.Safe.to_string
         (`Assoc
            [ ("modelos", `List (List.map json_tele l.teles));
              ("desconocidos", lista l.desconocidos);
              ("pulgadas", `List (List.map (fun p -> `Int p) l.pulgadas));
              ("pulgadas_min", opt (fun p -> `Int p) minimo);
              ("tecnologias", lista (List.map C.tecnologia_texto l.tecnologias));
              ("marcas", lista l.marcas);
              ("hz_min", opt (fun h -> `Int h) l.hz) ]))

let cristal = Cristal.cristal "tv-modelo" Cristal.texto aplicar
