(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Lo que se sabe de un módulo de memoria por su part number, y de una placa
   o un servidor por su nombre.

   Los part numbers no se buscan en una lista: se leen. Cada fabricante
   escribe en el suyo la generación, el formato, la profundidad (y con ella
   la capacidad), la anchura de los chips y la velocidad: M393A8G40AB2-CWE es
   un RDIMM (393) DDR4 (A) de 8G × 64 bits (64 GB) con chips x4 (40) a 3200
   (WE); HMAA8GR7AJR4N-XN, MTA36ASF8G72PZ-3G2E1, CT32G4DFD832A, KSM32RD4/64,
   CMK32GX4M2E3200C16 y F4-3200C16D-32GVK, igual con sus reglas. Lo que una
   regla no cuenta (los rangos de Samsung dependen del chip) va en una tabla
   corta de los part numbers que se sabe. Las etiquetas de HPE, Dell y Lenovo
   no se leen: van en su tabla, con el módulo que llevan cuando se sabe.

   Las reglas y las tablas son de memoria del modelo que nucleó el cristal,
   contrastadas con los anuncios de la semilla (2026-10-13). Un part number
   que no casa con ninguna es un desconocido: la semilla de la versión
   siguiente. *)

type generacion = Sdr | Ddr | Ddr2 | Ddr3 | Ddr4 | Ddr5

type formato =
  | Udimm
  | Sodimm
  | Rdimm
  | Lrdimm
  | Rdimm_3ds
  | Ecc_udimm
  | Ecc_sodimm
  | Cudimm
  | Csodimm
  | Camm2
  | Mrdimm
  | Fbdimm

let generacion_texto = function
  | Sdr -> "sdr" | Ddr -> "ddr" | Ddr2 -> "ddr2" | Ddr3 -> "ddr3" | Ddr4 -> "ddr4" | Ddr5 -> "ddr5"

let formato_texto = function
  | Udimm -> "udimm" | Sodimm -> "sodimm" | Rdimm -> "rdimm" | Lrdimm -> "lrdimm" | Rdimm_3ds -> "3ds-rdimm"
  | Ecc_udimm -> "ecc-udimm" | Ecc_sodimm -> "ecc-sodimm" | Cudimm -> "cudimm" | Csodimm -> "csodimm"
  | Camm2 -> "camm2" | Mrdimm -> "mrdimm" | Fbdimm -> "fbdimm"

(** Lo que el formato dice del ECC y del registro. *)
let ecc_de = function
  | Udimm | Sodimm | Cudimm | Csodimm -> Some false
  | Camm2 -> None
  | Rdimm | Lrdimm | Rdimm_3ds | Ecc_udimm | Ecc_sodimm | Mrdimm | Fbdimm -> Some true

let registrada_de = function
  | Rdimm | Lrdimm | Rdimm_3ds | Mrdimm | Fbdimm -> Some true
  | Camm2 -> None
  | Udimm | Sodimm | Cudimm | Csodimm | Ecc_udimm | Ecc_sodimm -> Some false

(** El formato con ECC del que no lo tiene. *)
let con_ecc = function Udimm -> Ecc_udimm | Sodimm -> Ecc_sodimm | f -> f

(** Las velocidades (MT/s) de cada generación, las JEDEC y las de los kits de juego. *)
let velocidades = function
  | Sdr -> [ 66; 100; 133 ]
  | Ddr -> [ 200; 266; 333; 400 ]
  | Ddr2 -> [ 400; 533; 667; 800; 1066 ]
  | Ddr3 -> [ 800; 1066; 1333; 1600; 1866; 2133; 2400 ]
  | Ddr4 -> [ 1600; 1866; 2133; 2400; 2666; 2933; 3000; 3200; 3333; 3466; 3600; 3733; 3800; 3866; 4000; 4133; 4266; 4400; 4600; 4800; 5000; 5100 ]
  | Ddr5 -> [ 4000; 4400; 4800; 5200; 5600; 6000; 6200; 6400; 6600; 6800; 7000; 7200; 7600; 7800; 8000; 8200; 8400; 8800; 9000; 9200; 9600 ]

let todas_las_velocidades = List.sort_uniq compare (List.concat_map velocidades [ Ddr; Ddr2; Ddr3; Ddr4; Ddr5 ])

(** La generación por la velocidad, cuando solo una la tiene. *)
let generacion_de_velocidad v =
  match List.filter (fun g -> List.mem v (velocidades g)) [ Ddr; Ddr2; Ddr3; Ddr4; Ddr5 ] with [ g ] -> Some g | _ -> None

(** El voltaje JEDEC de cada generación (el de un módulo de servidor o sin overclock). *)
let voltaje_jedec = function Ddr5 -> Some 1.1 | Ddr4 -> Some 1.2 | Ddr3 -> Some 1.5 | Ddr2 -> Some 1.8 | Ddr -> Some 2.5 | Sdr -> Some 3.3

(** La capacidad más grande de un módulo corriente (MB), por generación, formato
    y si es de servidor: lo que pase de ahí es el total de un kit o de un lote
    («64GB DDR4 3200» no es un DIMM de 64: no los hay). Los LRDIMM y los 3DS
    llegan a 256; un RDIMM DDR4, a 64; un kit de juego DDR5 de «64GB» casi
    siempre es de dos de 32. *)
let capacidad_maxima ?formato ?(consumo = false) gen servidor =
  let gb x = x * 1024 in
  match (formato, gen, servidor) with
  | Some (Lrdimm | Rdimm_3ds), _, _ -> gb 256
  | _, Sdr, _ -> gb 1
  | _, Ddr, _ -> gb 2
  | _, Ddr2, false -> gb 4
  | _, Ddr2, true -> gb 8
  | _, Ddr3, false -> if consumo then gb 8 else gb 16
  | _, Ddr3, true -> gb 32
  | _, Ddr4, false -> gb 32
  | _, Ddr4, true -> gb 64
  | _, Ddr5, false -> gb 48
  | _, Ddr5, true -> gb 128

(* --- el módulo ------------------------------------------------------------ *)

type modulo = {
  pn : string;  (** Como se escribe: «M393A8G40AB2-CWE». *)
  fabricante : string;  (** «samsung», «skhynix», «micron», «crucial», «kingston»… *)
  oem : string option;  (** La marca de la etiqueta: «hpe», «dell», «lenovo», «ibm»… *)
  equivalentes : string list;  (** El módulo que lleva una etiqueta de OEM, si se sabe. *)
  linea : string option;  (** «Vengeance LPX», «Fury Beast»… *)
  generacion : generacion option;
  formato : formato option;
  ecc : bool option;
  registrada : bool option;
  capacidad : int option;  (** MB por módulo. *)
  modulos : int;  (** 1, o los del kit. *)
  velocidad : int option;  (** MT/s. *)
  cas : int option;
  rangos : int option;
  anchura : int option;  (** 4, 8 o 16: la de los chips. *)
  voltaje : float option;
}

let mk ?oem ?(equivalentes = []) ?linea ?generacion ?formato ?ecc ?registrada ?capacidad ?(modulos = 1) ?velocidad ?cas ?rangos
    ?anchura ?voltaje ~fabricante pn =
  let desde f = Option.bind formato f in
  {
    pn;
    fabricante;
    oem;
    equivalentes;
    linea;
    generacion;
    formato;
    ecc = (match ecc with Some _ -> ecc | None -> desde ecc_de);
    registrada = (match registrada with Some _ -> registrada | None -> desde registrada_de);
    capacidad;
    modulos;
    velocidad;
    cas;
    rangos;
    anchura;
    voltaje;
  }

(* --- piezas de las cadenas -------------------------------------------------- *)

let es_cifra c = c >= '0' && c <= '9'
let es_letra c = c >= 'a' && c <= 'z'
let empieza s p = String.length s >= String.length p && String.sub s 0 (String.length p) = p
let resto s i = if i >= String.length s then "" else String.sub s i (String.length s - i)
let todo_cifras s = s <> "" && String.for_all es_cifra s

let tramo p s i =
  let n = String.length s in
  let j = ref i in
  while !j < n && p s.[!j] do incr j done;
  (String.sub s i (!j - i), !j)

let cifras_desde = tramo es_cifra
let letras_desde = tramo es_letra
let entero s = int_of_string_opt s
let gb x = x * 1024

(** La palabra [i] de [ws], o "". *)
let palabra ws i = if i >= 0 && i < Array.length ws then ws.(i) else ""

(** El número con que empieza una palabra («64har» → 64). *)
let numero_inicial w = match cifras_desde w 0 with "", _ -> None | d, _ -> entero d

(** Velocidad de dos cifras de Kingston y compañía: 32 → 3200, 26 → 2666, 29 → 2933. *)
let velocidad_corta = function
  | 13 -> Some 1333 | 16 -> Some 1600 | 18 -> Some 1866 | 21 -> Some 2133 | 24 -> Some 2400 | 26 -> Some 2666 | 29 -> Some 2933
  | 30 -> Some 3000 | 32 -> Some 3200 | 36 -> Some 3600 | 40 -> Some 4000 | 44 -> Some 4400 | 48 -> Some 4800 | 52 -> Some 5200
  | 56 -> Some 5600 | 60 -> Some 6000 | 62 -> Some 6200 | 64 -> Some 6400 | 66 -> Some 6600 | 68 -> Some 6800 | 72 -> Some 7200
  | 80 -> Some 8000 | _ -> None

let generacion_de_corta v = if v >= 48 then Some Ddr5 else if v >= 21 then Some Ddr4 else if v >= 13 then Some Ddr3 else None

(* --- Samsung: M393A8G40AB2-CWE ---------------------------------------------- *)

(* La familia (las tres cifras) da el formato. *)
let formato_samsung = function
  | "378" | "368" | "323" -> Some Udimm
  | "391" | "324" -> Some Ecc_udimm
  | "393" | "392" | "321" | "312" -> Some Rdimm
  | "386" -> Some Lrdimm
  | "395" -> Some Fbdimm
  | "470" | "471" | "425" -> Some Sodimm
  | "474" | "426" -> Some Ecc_sodimm
  | _ -> None

(* La profundidad (8G, 4K, 51…) en MB del módulo: × 64 bits. *)
let profundidad d =
  match d with
  | "28" | "29" -> Some 1024
  | "56" | "57" -> Some 2048
  | "51" | "52" -> Some 4096
  | _ when String.length d = 2 && (d.[1] = 'g' || d.[1] = 'k') -> (
    match d.[0] with
    | '1' -> Some (gb 8) | '2' -> Some (gb 16) | '4' -> Some (gb 32) | '8' -> Some (gb 64) | 'a' -> Some (gb 128) | 'b' -> Some (gb 256)
    | _ -> None)
  | _ -> None

let velocidad_samsung gen suf =
  if String.length suf < 3 then None
  else
    match (gen, String.sub suf 1 2) with
    | Ddr4, "pb" -> Some 2133 | Ddr4, "rc" -> Some 2400 | Ddr4, "td" -> Some 2666 | Ddr4, "vf" -> Some 2933 | Ddr4, "we" -> Some 3200
    | Ddr3, "f8" -> Some 1066 | Ddr3, "h9" -> Some 1333 | Ddr3, "k0" -> Some 1600 | Ddr3, "ma" -> Some 1866
    | Ddr5, "qk" -> Some 4800 | Ddr5, "wm" -> Some 5600
    | Ddr2, "d5" -> Some 533 | Ddr2, "e6" -> Some 667 | Ddr2, "f7" -> Some 800
    | _ -> None

(* Los rangos no salen de la regla (dependen del chip): los que se saben. *)
let rangos_samsung =
  [ ("m393a8g40ab2", 2); ("m393a8g40bb4", 2); ("m393a8g40mb2", 2); ("m393a4k40bb1", 2); ("m393a4k40bb2", 2); ("m393a4k40cb2", 2);
    ("m393a4k40db3", 2); ("m393a2k40bb1", 2); ("m393a2k43bb1", 2); ("m386a4g40dm0", 4); ("m386a8k40bm1", 4); ("m386a8k40bm2", 4);
    ("m378a4g43ab2", 2); ("m471a4g43ab1", 2); ("m393b2g70bh0", 2); ("m393b1k70dh0", 2); ("m393b1k70ch0", 2) ]

let samsung ws i =
  let w = palabra ws i in
  let n = String.length w in
  if n < 10 || w.[0] <> 'm' || not (todo_cifras (String.sub w 1 3)) then None
  else
    let gen = match w.[4] with 'a' -> Some Ddr4 | 'b' -> Some Ddr3 | 'r' -> Some Ddr5 | 't' -> Some Ddr2 | 'l' -> Some Ddr | _ -> None in
    match (gen, formato_samsung (String.sub w 1 3), profundidad (String.sub w 5 2)) with
    | Some g, Some f, Some mb ->
      let org = String.sub w 7 2 in
      let anchura =
        match (g, org) with
        | (Ddr4 | Ddr3), ("40" | "70") -> Some 4 | (Ddr4 | Ddr3), ("43" | "73") -> Some 8 | (Ddr4 | Ddr3), ("44" | "74") -> Some 16
        | Ddr5, "a0" -> Some 4 | Ddr5, "a3" -> Some 8 | Ddr5, "b4" -> Some 16
        | _ -> None
      in
      (* El sufijo de velocidad va detrás del guion (la palabra siguiente) o pegado. *)
      let pegado = n > 12 in
      let suf = if pegado then resto w 12 else palabra ws (i + 1) in
      let velocidad = velocidad_samsung g suf in
      let toma = if velocidad <> None && not pegado then 2 else 1 in
      let base = String.sub w 0 (min n 12) in
      let voltaje = if g = Ddr3 && String.length suf > 0 && suf.[0] = 'y' then Some 1.35 else voltaje_jedec g in
      let pn = String.uppercase_ascii (if toma = 2 then w ^ "-" ^ suf else w) in
      Some
        ( mk ~fabricante:"samsung" ~generacion:g ~formato:f ~capacidad:mb ?velocidad ?anchura ?voltaje
            ?rangos:(List.assoc_opt base rangos_samsung) pn,
          toma )
    | _ -> None

(* --- SK hynix: HMAA8GR7AJR4N-XN ---------------------------------------------- *)

let densidad_hynix gen c =
  match (gen, c) with
  | Ddr4, '4' -> Some 4 | Ddr4, '8' -> Some 8 | Ddr4, 'a' -> Some 16 | Ddr4, 'b' -> Some 32
  | Ddr3, '1' -> Some 1 | Ddr3, '3' -> Some 2 | Ddr3, '4' -> Some 4 | Ddr3, '8' -> Some 8
  | _ -> None

let formato_hynix = function
  | "r7" | "p7" -> Some Rdimm | "u6" | "u8" -> Some Udimm | "u7" -> Some Ecc_udimm | "s6" | "s8" -> Some Sodimm | "s7" -> Some Ecc_sodimm
  | "l7" -> Some Lrdimm | _ -> None

let velocidad_hynix gen suf =
  match gen with
  | Ddr4 when suf <> "" -> (match suf.[0] with 't' -> Some 2133 | 'u' -> Some 2400 | 'v' -> Some 2666 | 'w' -> Some 2933 | 'x' -> Some 3200 | _ -> None)
  | Ddr3 -> (match suf with "g7" -> Some 1066 | "h9" -> Some 1333 | "pb" -> Some 1600 | "rd" -> Some 1866 | "tf" -> Some 2133 | _ -> None)
  | _ -> None

let hynix_ddr5 w =
  (* HMCG94AEBRA: la capacidad por el código de dos cifras; el formato, por la letra tras la «b». *)
  let cap = match String.sub w 4 2 with "66" -> Some 8 | "78" -> Some 16 | "84" | "88" -> Some 32 | "94" -> Some 64 | _ -> None in
  let fmt =
    if String.length w >= 10 then match w.[9] with 'r' -> Some Rdimm | 'u' -> Some Udimm | 's' -> Some Sodimm | _ -> None else None
  in
  Some
    ( mk ~fabricante:"skhynix" ~generacion:Ddr5 ?formato:fmt ?capacidad:(Option.map gb cap) ?voltaje:(voltaje_jedec Ddr5)
        (String.uppercase_ascii w),
      1 )

let hynix ws i =
  let w = palabra ws i in
  let n = String.length w in
  if n >= 10 && empieza w "hmcg" then hynix_ddr5 w
  else if n < 12 || not (empieza w "hma" || empieza w "hmt") then None
  else
    let g = if w.[2] = 'a' then Ddr4 else Ddr3 in
    match (densidad_hynix g w.[3], profundidad (String.sub w 4 2), formato_hynix (String.sub w 6 2)) with
    | dens, Some mb, Some f ->
      let paquete = w.[9] in
      let anchura = match String.sub w 10 2 with "r4" -> Some 4 | "r8" -> Some 8 | "r6" -> Some 16 | _ -> None in
      let apilado = paquete = '2' || paquete = '4' in
      let f = if apilado && f = Rdimm then Rdimm_3ds else f in
      let rangos =
        match (dens, anchura) with
        (* Los LRDIMM suelen llevar chips dobles (4DRx4): no salen de la cuenta. *)
        | Some d, Some a when not apilado && f <> Lrdimm ->
          let r = mb / 1024 * 8 / (d * (64 / a)) in
          if r >= 1 && r <= 8 then Some r else None
        | _ -> None
      in
      let suf = palabra ws (i + 1) in
      let velocidad = if String.length suf = 2 then velocidad_hynix g suf else None in
      let toma = if velocidad <> None then 2 else 1 in
      let pn = String.uppercase_ascii (if toma = 2 then w ^ "-" ^ suf else w) in
      Some (mk ~fabricante:"skhynix" ~generacion:g ~formato:f ~capacidad:mb ?velocidad ?anchura ?rangos ?voltaje:(voltaje_jedec g) pn, toma)
    | _ -> None

(* --- Micron: MTA36ASF8G72PZ-3G2E1, MT36KSF2G72PZ-1G4, MTC40F2046S1RC48BA1 --------- *)

let velocidad_micron suf =
  if String.length suf >= 3 && es_cifra suf.[0] && suf.[1] = 'g' && es_cifra suf.[2] then
    match String.sub suf 0 3 with
    | "3g2" -> Some 3200 | "2g9" -> Some 2933 | "2g6" -> Some 2666 | "2g4" | "2g3" -> Some 2400 | "2g1" -> Some 2133 | "1g8" -> Some 1866
    | "1g6" -> Some 1600 | "1g4" -> Some 1333 | "1g1" -> Some 1066 | "80e" | "800" -> Some 800 | _ -> None
  else None

let micron_ddr5 w =
  (* MTC + chips + F (ECC) o C + rangos y organización + S1 + formato + C + velocidad. *)
  let chips, j = cifras_desde w 3 in
  match entero chips with
  | Some c when j + 9 <= String.length w ->
    let ecc = w.[j] = 'f' in
    let org = String.sub w (j + 1) 4 in
    let rangos = if es_cifra org.[0] then Some (Char.code org.[0] - 48) else None in
    let anchura = match String.sub org 1 3 with "045" | "046" | "047" -> Some 4 | "084" | "085" | "086" -> Some 8 | _ -> None in
    let datos = if ecc then c * 4 / 5 else c in
    let fmt_letra = if j + 7 < String.length w then w.[j + 7] else ' ' in
    let formato =
      match (fmt_letra, ecc) with
      | 'r', _ -> Some Rdimm | 'u', false -> Some Udimm | 'u', true -> Some Ecc_udimm | 's', false -> Some Sodimm
      | 's', true -> Some Ecc_sodimm | _ -> None
    in
    let velocidad = match entero (fst (cifras_desde w (min (String.length w) (j + 9)))) with Some v -> velocidad_corta v | None -> None in
    Some
      ( mk ~fabricante:"micron" ~generacion:Ddr5 ?formato ~capacidad:(gb (datos * 2)) ?rangos ?anchura ?velocidad
          ?voltaje:(voltaje_jedec Ddr5) (String.uppercase_ascii w),
        1 )
  | _ -> None

let micron ws i =
  let w = palabra ws i in
  if String.length w >= 12 && empieza w "mtc" && es_cifra w.[3] then micron_ddr5 w
  else if String.length w < 10 || not (empieza w "mt") then None
  else
    let desde = if empieza w "mta" then 3 else 2 in
    let chips, j = cifras_desde w desde in
    let fam, k = letras_desde w j in
    let dig, l = cifras_desde w k in
    match (entero chips, fam) with
    | Some c, _ when String.length fam >= 2 && String.length fam <= 3 && dig <> "" ->
      let gen =
        if desde = 3 then Some Ddr4 else match fam.[0] with 'j' | 'k' -> Some Ddr3 | 'h' -> Some Ddr2 | _ -> None
      in
      (* La profundidad: «8G» y la anchura detrás, o «51272»: 512M y 72. *)
      let prof, ancho, m =
        if l < String.length w && w.[l] = 'g' then
          let a, m = cifras_desde w (l + 1) in
          ((match entero dig with Some d -> Some (gb (d * 8)) | None -> None), a, m)
        else if String.length dig >= 5 then
          let d = String.sub dig 0 (String.length dig - 2) in
          ((match entero d with Some d -> Some (d * 8) | None -> None), String.sub dig (String.length dig - 2) 2, l)
        else (None, "", l)
      in
      let forma, _ = letras_desde w m in
      let ecc = ancho = "72" in
      let formato =
        if forma = "" then None
        else
          match forma.[0] with
          | 'p' -> Some Rdimm | 'l' -> Some Lrdimm | 'f' -> Some Fbdimm
          | 'a' -> Some (if ecc then Ecc_udimm else Udimm)
          | 'h' -> Some (if ecc then Ecc_sodimm else Sodimm)
          | _ -> None
      in
      if gen = None || prof = None || (ancho <> "72" && ancho <> "64") || formato = None then None
      else
        let dual = String.contains forma 'd' in
        let apilado = String.length fam = 3 && (fam.[2] = 's' || fam.[2] = 'q') in
        let rangos, anchura =
          if apilado then (None, Some 4)
          else
            match (ecc, c) with
            | true, 9 -> (Some 1, Some 8)
            | true, 18 -> if dual || formato <> Some Rdimm then (Some 2, Some 8) else (Some 1, Some 4)
            | true, 36 -> (Some 2, Some 4)
            | true, 72 -> (Some 4, Some 4)
            | false, 4 -> (Some 1, Some 16)
            | false, 8 -> (Some 1, Some 8)
            | false, 16 -> (Some 2, Some 8)
            | _ -> (None, None)
        in
        let formato = if apilado && formato = Some Rdimm then Some Rdimm_3ds else formato in
        let suf = palabra ws (i + 1) in
        let velocidad = velocidad_micron suf in
        let toma = if velocidad <> None then 2 else 1 in
        let g = Option.get gen in
        let voltaje = match (g, fam.[0]) with Ddr3, 'k' -> Some 1.35 | _ -> voltaje_jedec g in
        let pn = String.uppercase_ascii (if toma = 2 then w ^ "-" ^ suf else w) in
        Some (mk ~fabricante:"micron" ~generacion:g ?formato ?capacidad:prof ?velocidad ?rangos ?anchura ?voltaje pn, toma)
    | _ -> None

(* --- Crucial: CT32G4DFD832A, CT2K16G4SFRA32A, CT32G56C46S5, BL2K32G32C16U4B ------------ *)

let kit w i =
  (* «2k», «4k» delante de la capacidad: un kit de 2 o de 4. *)
  if i + 1 < String.length w && es_cifra w.[i] && w.[i + 1] = 'k' && i + 2 < String.length w && es_cifra w.[i + 2] then
    (Char.code w.[i] - 48, i + 2)
  else (1, i)

let velocidad_crucial s =
  if String.length s < 3 then None
  else
    let s = String.sub s 0 3 in
    if s.[2] = 'a' then Option.map (fun v -> v * 100) (entero (String.sub s 0 2))
    else match s with "293" -> Some 2933 | "266" -> Some 2666 | "213" -> Some 2133 | "240" -> Some 2400 | "320" -> Some 3200 | "186" -> Some 1866 | "160" -> Some 1600 | _ -> None

let crucial ws i =
  let w = palabra ws i in
  let n = String.length w in
  let pref = if empieza w "ct" || empieza w "cp" then 2 else 0 in
  if pref = 0 || n < 10 then None
  else
    let kitn, j = kit w pref in
    let cap, k = cifras_desde w j in
    if cap = "" || k >= n || w.[k] <> 'g' then None
    else
      let capacidad = Option.map gb (entero cap) in
      let r = resto w (k + 1) in
      let pn = String.uppercase_ascii w in
      if String.length r >= 7 && r.[0] = '4' && r.[2] = 'f' then
        (* DDR4: forma, F, rangos (S, D, Q o RA), anchura y velocidad. *)
        let formato =
          match r.[1] with
          | 'd' -> Some Udimm | 's' -> Some Sodimm | 'r' | 'v' -> Some Rdimm | 'l' -> Some Lrdimm | 'w' | 'x' -> Some Ecc_udimm
          | 't' -> Some Ecc_sodimm | _ -> None
        in
        let rangos, anchura, v =
          if r.[3] = 'r' && r.[4] = 'a' then (Some 1, Some 8, resto r 5)
          else
            let rg = match r.[3] with 's' -> Some 1 | 'd' -> Some 2 | 'q' -> Some 4 | _ -> None in
            let an = match r.[4] with '4' -> Some 4 | '8' -> Some 8 | '6' -> Some 16 | _ -> None in
            (rg, an, resto r 5)
        in
        if formato = None then None
        else
          Some
            ( mk ~fabricante:"crucial" ~generacion:Ddr4 ?formato ?capacidad ~modulos:kitn ?rangos ?anchura ?velocidad:(velocidad_crucial v)
                ?voltaje:(voltaje_jedec Ddr4) pn,
              1 )
      else
        (* DDR5: velocidad, C, CAS y forma (U5, S5, CU5, CS5). *)
        let v, m = cifras_desde r 0 in
        if String.length v = 2 && m < String.length r && r.[m] = 'c' then
          let cl, m2 = cifras_desde r (m + 1) in
          let forma, _ = letras_desde r m2 in
          let formato = match forma with "u" -> Some Udimm | "s" -> Some Sodimm | "cu" -> Some Cudimm | "cs" -> Some Csodimm | "r" -> Some Rdimm | _ -> None in
          if formato = None then None
          else
            Some
              ( mk ~fabricante:"crucial" ~generacion:Ddr5 ?formato ?capacidad ~modulos:kitn
                  ?velocidad:(Option.bind (entero v) velocidad_corta) ?cas:(entero cl) ?voltaje:(voltaje_jedec Ddr5) pn,
                1 )
        else None

let ballistix ws i =
  let w = palabra ws i in
  let n = String.length w in
  if n < 10 || not (empieza w "bl") then None
  else
    let _, j = letras_desde w 2 in
    let kitn, j = kit w j in
    let cap, k = cifras_desde w j in
    if cap = "" || k >= n || w.[k] <> 'g' then None
    else
      let r = resto w (k + 1) in
      let capacidad = Option.map gb (entero cap) in
      let pn = String.uppercase_ascii w in
      let v, m = cifras_desde r 0 in
      if String.length v = 2 && m < String.length r && r.[m] = 'c' then
        (* BL2K32G32C16U4B *)
        let cl, m2 = cifras_desde r (m + 1) in
        let formato = if m2 < String.length r then match r.[m2] with 'u' -> Some Udimm | 's' -> Some Sodimm | _ -> None else None in
        Some
          ( mk ~fabricante:"crucial" ~linea:"Ballistix" ~generacion:Ddr4 ?formato ?capacidad ~modulos:kitn
              ?velocidad:(Option.bind (entero v) velocidad_corta) ?cas:(entero cl) pn,
            1 )
      else if String.length r >= 5 && r.[0] = '4' then
        (* BLS8G4D240FSB *)
        let formato = match r.[1] with 'd' -> Some Udimm | 's' -> Some Sodimm | _ -> None in
        Some
          ( mk ~fabricante:"crucial" ~linea:"Ballistix" ~generacion:Ddr4 ?formato ?capacidad ~modulos:kitn
              ?velocidad:(velocidad_crucial (resto r 2)) pn,
            1 )
      else None

(* --- Kingston: KSM32RD4/64HAR, KVR32N22D8/32, KF432C16BBK2/32, KCP424SD8/16 ---------- *)

(* La capacidad de detrás de la barra: la palabra siguiente («64har», «32», «16g»). *)
let tras_barra ws i =
  let s = palabra ws (i + 1) in
  match numero_inicial s with
  | Some c when c >= 1 && c <= 512 && String.length s <= 8 -> (Some c, 2)
  | _ -> (None, 1)

let rango_letra = function 's' -> Some 1 | 'd' -> Some 2 | 'q' -> Some 4 | _ -> None
let anchura_cifra = function '4' -> Some 4 | '8' -> Some 8 | '6' -> Some 16 | _ -> None

let ksm ws i w =
  let v, j = cifras_desde w 3 in
  match Option.bind (entero v) velocidad_corta with
  | None -> None
  | Some vel ->
    let g = if vel >= 4800 then Ddr5 else Ddr4 in
    let letras, k = letras_desde w j in
    let n = String.length w in
    let formato_de = function
      | "r" -> Some Rdimm | "e" -> Some Ecc_udimm | "se" | "t" -> Some Ecc_sodimm | "s" -> Some Sodimm | "l" -> Some Lrdimm | _ -> None
    in
    let formato, rangos, anchura, cas =
      if g = Ddr4 && String.length letras >= 2 && k < n then
        (formato_de (String.sub letras 0 (String.length letras - 1)), rango_letra letras.[String.length letras - 1], anchura_cifra w.[k], None)
      else
        (* DDR5: KSM48R40BD4TMM: forma, CAS, B, rangos y anchura. *)
        let cl, m = cifras_desde w k in
        let rg, an = if m + 2 < n && w.[m] = 'b' then (rango_letra w.[m + 1], anchura_cifra w.[m + 2]) else (None, None) in
        (formato_de letras, rg, an, entero cl)
    in
    let cap, toma = tras_barra ws i in
    let pn = String.uppercase_ascii (if toma = 2 then w ^ "/" ^ palabra ws (i + 1) else w) in
    Some
      ( mk ~fabricante:"kingston" ~linea:"Server Premier" ~generacion:g ?formato ?capacidad:(Option.map gb cap) ~velocidad:vel
          ?rangos ?anchura ?cas ?voltaje:(voltaje_jedec g) pn,
        toma )

let kvr ws i w =
  (* «KVR 56S46BD8»: el código puede ir en la palabra siguiente. *)
  let w, extra = if w = "kvr" && numero_inicial (palabra ws (i + 1)) <> None then ("kvr" ^ palabra ws (i + 1), 1) else (w, 0) in
  let v, j = cifras_desde w 3 in
  let n = String.length w in
  let letras, k = letras_desde w j in
  let cap, toma = tras_barra ws (i + extra) in
  let capacidad = Option.map gb cap in
  let toma = toma + extra in
  let pn = String.uppercase_ascii (if toma - extra = 2 then w ^ "/" ^ palabra ws (i + extra + 1) else w) in
  let hecho ?formato ?rangos ?anchura ?cas ?voltaje ?registrada ?ecc g vel =
    Some (mk ~fabricante:"kingston" ~linea:"ValueRAM" ~generacion:g ?formato ?ecc ?registrada ?capacidad ~velocidad:vel ?rangos ?anchura ?cas ?voltaje pn, toma)
  in
  match String.length v with
  | 2 -> (
    match (Option.bind (entero v) velocidad_corta, Option.bind (entero v) generacion_de_corta) with
    | Some vel, Some g ->
      let cl, m = cifras_desde w k in
      let rg, an =
        if m + 1 < n && rango_letra w.[m] <> None then (rango_letra w.[m], anchura_cifra w.[m + 1])
        else if m + 2 < n && w.[m] = 'b' then (rango_letra w.[m + 1], anchura_cifra w.[m + 2])
        else (None, None)
      in
      let baja = String.length letras > 0 && letras.[0] = 'l' && g = Ddr3 in
      let forma = if baja then resto letras 1 else letras in
      let voltaje = if baja then Some 1.35 else voltaje_jedec g in
      (match forma with
       | "n" | "u" -> hecho ~formato:Udimm ?rangos:rg ?anchura:an ?cas:(entero cl) ?voltaje g vel
       | "s" -> hecho ~formato:Sodimm ?rangos:rg ?anchura:an ?cas:(entero cl) ?voltaje g vel
       | "e" -> hecho ~formato:Ecc_udimm ?rangos:rg ?anchura:an ?cas:(entero cl) ?voltaje g vel
       | "r" -> hecho ~formato:Rdimm ?rangos:rg ?anchura:an ?cas:(entero cl) ?voltaje g vel
       (* «L» en DDR4: registrada (RDIMM o LRDIMM), sin saber cuál. *)
       | "l" -> hecho ~ecc:true ~registrada:true ?rangos:rg ?anchura:an ?cas:(entero cl) ?voltaje g vel
       | _ -> None)
    | _ -> None)
  | 3 | 4 -> (
    (* Los de antes: KVR1333D3D4R9S, KVR667D2S8P5, KVR400X64C3A. *)
    match entero v with
    | Some vel ->
      let gen_por = match letras with "d" -> (match entero (fst (cifras_desde w k)) with Some 3 -> Some Ddr3 | Some 2 -> Some Ddr2 | _ -> None) | "x" -> Some Ddr | _ -> None in
      (match gen_por with
       | Some Ddr when empieza (resto w k) "64" -> hecho ~formato:Udimm Ddr vel
       | Some g ->
         let r = resto w (k + 1) in
         let registrada = String.contains r 'r' || String.contains r 'p' in
         let rg, an = if String.length r >= 2 && rango_letra r.[0] <> None then (rango_letra r.[0], anchura_cifra r.[1]) else (None, None) in
         if registrada then hecho ~formato:Rdimm ?rangos:rg ?anchura:an g vel else hecho ?rangos:rg ?anchura:an g vel
       | None -> None)
    | None -> None)
  | _ -> None

let kf_hx ws i w ~fury =
  (* KF432C16BBK2/32, KF556C40BB, HX432C16FB3/16, HX316C10F: generación, velocidad, C o S, CAS, línea, kit. *)
  let d, j = cifras_desde w 2 in
  if String.length d <> 3 || j >= String.length w then None
  else
    let gen = match d.[0] with '3' -> Some Ddr3 | '4' -> Some Ddr4 | '5' -> Some Ddr5 | _ -> None in
    match (gen, entero (String.sub d 1 2)) with
    | Some g, Some v ->
      let vel = if g = Ddr3 then velocidad_corta v else Option.bind (Some v) velocidad_corta in
      let formato = match w.[j] with 'c' -> Some Udimm | 's' -> Some Sodimm | _ -> None in
      let cl, _ = cifras_desde w (j + 1) in
      let cas = match entero (if String.length cl >= 2 then String.sub cl 0 2 else cl) with Some c when c >= 5 && c <= 60 -> Some c | _ -> None in
      (* El kit, «K2» o «K4» al final de las letras. *)
      let ln = String.length w in
      let kitn = if ln >= 2 && w.[ln - 2] = 'k' && es_cifra w.[ln - 1] then Char.code w.[ln - 1] - 48 else 1 in
      let cap, toma = tras_barra ws i in
      let capacidad = match cap with Some c when kitn > 1 && c mod kitn = 0 -> Some (gb (c / kitn)) | Some c -> Some (gb c) | None -> None in
      let pn = String.uppercase_ascii (if toma = 2 then w ^ "/" ^ palabra ws (i + 1) else w) in
      Some
        ( mk ~fabricante:"kingston" ~linea:(if fury then "Fury" else "HyperX") ~generacion:g ?formato ?capacidad ~modulos:kitn ?velocidad:vel
            ?cas pn,
          toma )
    | _ -> None

let kcp ws i w =
  (* KCP424SD8/16, KCP432SD8/32, KCP424NS6/4, KCP3L16RD4/16 *)
  let baja = empieza w "kcp3l" in
  let desde = if baja then 5 else 4 in
  if String.length w < desde + 4 then None
  else
    let gen = match w.[3] with '3' -> Some Ddr3 | '4' -> Some Ddr4 | '5' -> Some Ddr5 | _ -> None in
    let v, j = cifras_desde w desde in
    match (gen, Option.bind (entero v) velocidad_corta) with
    | Some g, Some vel when j + 2 < String.length w ->
      let formato = match w.[j] with 'n' -> Some Udimm | 's' -> Some Sodimm | 'r' -> Some Rdimm | 'e' -> Some Ecc_udimm | _ -> None in
      let cap, toma = tras_barra ws i in
      let pn = String.uppercase_ascii (if toma = 2 then w ^ "/" ^ palabra ws (i + 1) else w) in
      Some
        ( mk ~fabricante:"kingston" ~generacion:g ?formato ?capacidad:(Option.map gb cap) ~velocidad:vel ?rangos:(rango_letra w.[j + 1])
            ?anchura:(anchura_cifra w.[j + 2]) ?voltaje:(if baja then Some 1.35 else voltaje_jedec g) pn,
          toma )
    | _ -> None

(* KTH-PL426/32G, KTD-PE432/64G, KTL-TS421/16G: los de Kingston para los
   servidores de HP (ProLiant), Dell (PowerEdge) y Lenovo (ThinkSystem):
   RDIMM, con la generación y la velocidad en las cifras. *)
let kingston_oem ws i w =
  let oem = match w with "kth" -> Some "hpe" | "ktd" -> Some "dell" | "ktl" -> Some "lenovo" | "ktm" -> Some "ibm" | _ -> None in
  let s = palabra ws (i + 1) in
  match oem with
  | Some o when String.length s >= 5 && List.mem (String.sub s 0 2) [ "pl"; "pe"; "ts" ] && es_cifra s.[2] -> (
    let d, j = cifras_desde s 2 in
    let gen = match d.[0] with '3' -> Some Ddr3 | '4' -> Some Ddr4 | '5' -> Some Ddr5 | _ -> None in
    match (gen, if String.length d = 3 then velocidad_corta (int_of_string (String.sub d 1 2)) else None) with
    | Some g, Some vel ->
      let rangos, anchura = if j + 1 < String.length s then (rango_letra s.[j], anchura_cifra s.[j + 1]) else (None, None) in
      let cap, toma = tras_barra ws (i + 1) in
      let pn = String.uppercase_ascii (w ^ "-" ^ s ^ if toma = 2 then "/" ^ palabra ws (i + 2) else "") in
      Some (mk ~fabricante:"kingston" ~oem:o ~generacion:g ~formato:Rdimm ?capacidad:(Option.map gb cap) ~velocidad:vel ?rangos ?anchura ?voltaje:(voltaje_jedec g) pn, toma + 1)
    | _ -> None)
  | _ -> None

let kingston ws i =
  let w = palabra ws i in
  if List.mem w [ "kth"; "ktd"; "ktl"; "ktm" ] then kingston_oem ws i w
  else if empieza w "ksm" && String.length w >= 7 then ksm ws i w
  else if empieza w "kvr" then kvr ws i w
  else if empieza w "kf" && String.length w >= 8 && es_cifra w.[2] then kf_hx ws i w ~fury:true
  else if empieza w "hx" && String.length w >= 8 && es_cifra w.[2] then kf_hx ws i w ~fury:false
  else if empieza w "kcp" && String.length w >= 8 then kcp ws i w
  else None

(* --- Corsair: CMK32GX4M2E3200C16 ---------------------------------------------------- *)

let lineas_corsair =
  [ ("k", "Vengeance LPX"); ("w", "Vengeance RGB Pro"); ("h", "Vengeance RGB"); ("t", "Dominator Platinum"); ("p", "Dominator Platinum");
    ("sx", "Vengeance"); ("so", "Vengeance"); ("z", "Vengeance"); ("r", "Vengeance RGB") ]

let corsair ws i =
  let w = palabra ws i in
  if String.length w < 14 || not (empieza w "cm") then None
  else
    let linea, j = letras_desde w 2 in
    let total, k = cifras_desde w j in
    let n = String.length w in
    if total = "" || k + 4 >= n || String.sub w k 2 <> "gx" then None
    else
      let gen = match w.[k + 2] with '3' -> Some Ddr3 | '4' -> Some Ddr4 | '5' -> Some Ddr5 | _ -> None in
      if gen = None || w.[k + 3] <> 'm' then None
      else
        let cuantos, m = cifras_desde w (k + 4) in
        let _, m = letras_desde w m in
        let v, m = cifras_desde w m in
        let cl = if m < n && w.[m] = 'c' then fst (cifras_desde w (m + 1)) else "" in
        match (entero total, entero cuantos) with
        | Some t, Some c when c >= 1 && t mod c = 0 ->
          Some
            ( mk ~fabricante:"corsair" ?linea:(List.assoc_opt linea lineas_corsair) ?generacion:gen
                ~formato:(if linea = "sx" || linea = "so" then Sodimm else Udimm)
                ~capacidad:(gb (t / c)) ~modulos:c ?velocidad:(entero v) ?cas:(entero cl) (String.uppercase_ascii w),
              1 )
        | _ -> None

(* --- G.Skill: F4-3200C16D-32GVK, F5-6000J3038F16GX2-TZ5RK ------------------------------- *)

let gskill ws i =
  let w = palabra ws i in
  let gen = match w with "f3" -> Some Ddr3 | "f4" -> Some Ddr4 | "f5" -> Some Ddr5 | _ -> None in
  match gen with
  | None -> None
  | Some g ->
    let s = palabra ws (i + 1) in
    let v, j = cifras_desde s 0 in
    if String.length v <> 4 || j >= String.length s then None
    else
      let _, k = letras_desde s j in
      let cl, k = cifras_desde s k in
      let n = String.length s in
      let cas = Option.bind (entero (if String.length cl >= 2 then String.sub cl 0 2 else cl)) (fun c -> if c >= 5 && c <= 60 then Some c else None) in
      let pn = String.uppercase_ascii (String.concat "-" (List.filter (( <> ) "") [ w; s; palabra ws (i + 2) ])) in
      if g = Ddr5 then
        (* …F16GX2: por módulo y cuántos. *)
        match String.index_opt s 'x' with
        | Some x when x > 2 && x + 1 < n && s.[x - 1] = 'g' ->
          let p = ref (x - 2) in
          while !p > 0 && es_cifra s.[!p - 1] do decr p done;
          let cap = entero (String.sub s !p (x - 1 - !p)) and cuantos = entero (resto s (x + 1)) in
          Some
            ( mk ~fabricante:"gskill" ~generacion:g ~formato:Udimm ?capacidad:(Option.map gb cap) ~modulos:(Option.value cuantos ~default:1)
                ?velocidad:(entero v) ?cas pn,
              3 )
        | _ -> Some (mk ~fabricante:"gskill" ~generacion:g ~formato:Udimm ?velocidad:(entero v) ?cas pn, 2)
      else
        let cuantos = if k < n then match s.[k] with 's' -> 1 | 'd' -> 2 | 'q' -> 4 | 'o' -> 8 | _ -> 1 else 1 in
        let t = palabra ws (i + 2) in
        let total, m = cifras_desde t 0 in
        let total = if total <> "" && m < String.length t && t.[m] = 'g' then entero total else None in
        let capacidad = match total with Some t when t mod cuantos = 0 -> Some (gb (t / cuantos)) | _ -> None in
        (* La línea: «RS», Ripjaws de portátil. *)
        let sodimm = empieza (resto t m) "grs" || empieza (resto t m) "gsx" in
        Some
          ( mk ~fabricante:"gskill" ~generacion:g ~formato:(if sodimm then Sodimm else Udimm) ?capacidad ~modulos:cuantos ?velocidad:(entero v)
              ?cas pn,
            if total <> None then 3 else 2 )

(* --- Synology, OWC ---------------------------------------------------------------------- *)

let synology ws i =
  let w = palabra ws i in
  let formato =
    if empieza w "d4ec" || empieza w "d4eu" then Some Ecc_udimm
    else if empieza w "d4rd" then Some Rdimm
    else if empieza w "d4es" then Some Ecc_sodimm
    else if empieza w "d4ns" then Some Sodimm
    else if empieza w "ramec" && String.length w > 9 then Some Ecc_udimm
    else None
  in
  match formato with
  | None -> None
  | Some f ->
    (* D4EC-2666-16G, D4ES02-8G, RAMEC2133DDR4-8G *)
    let vel = if empieza w "ramec" then entero (String.sub w 5 4) else entero (palabra ws (i + 1)) in
    let vel = match vel with Some v when List.mem v (velocidades Ddr4) -> Some v | _ -> None in
    let rec cap k = if k > i + 2 then None else let s = palabra ws k in
      let d, m = cifras_desde s 0 in
      if d <> "" && m = String.length s - 1 && s.[m] = 'g' then Some (k, entero d) else cap (k + 1) in
    let capacidad, toma = match cap (i + 1) with Some (k, c) -> (Option.map gb c, k - i + 1) | None -> (None, 1) in
    let pn = String.uppercase_ascii (String.concat "-" (List.init toma (fun d -> palabra ws (i + d)))) in
    Some (mk ~fabricante:"synology" ~oem:"synology" ~generacion:Ddr4 ~formato:f ?capacidad ?velocidad:vel ?voltaje:(voltaje_jedec Ddr4) pn, toma)

let owc ws i =
  (* OWC2666DDR4S32G *)
  let w = palabra ws i in
  if not (empieza w "owc" && String.length w >= 12) then None
  else
    let v, j = cifras_desde w 3 in
    if resto w j |> fun r -> not (empieza r "ddr4") then None
    else
      let r = resto w (j + 4) in
      let formato = if r <> "" && r.[0] = 's' then Some Sodimm else Some Udimm in
      let cap, _ = cifras_desde r 1 in
      Some (mk ~fabricante:"owc" ~generacion:Ddr4 ?formato ?capacidad:(Option.map gb (entero cap)) ?velocidad:(entero v) (String.uppercase_ascii w), 1)

(* --- etiquetas de OEM ------------------------------------------------------------------- *)

(* Las que se saben, con lo que llevan. Las claves, como quedan las palabras
   plegadas («P03053-0A1» → «p03053 0a1»). *)
let oem =
  let m ~oem ~gen ~fmt ?rangos ?anchura ?(equivalentes = []) ?velocidad ?voltaje clave pn cap =
    (clave, mk ~fabricante:oem ~oem ~equivalentes ~generacion:gen ~formato:fmt ~capacidad:(gb cap) ?velocidad ?rangos ?anchura
        ?voltaje:(match voltaje with Some v -> Some v | None -> voltaje_jedec gen) pn)
  in
  [ (* HPE *)
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Rdimm ~rangos:2 ~anchura:4 ~velocidad:3200 ~equivalentes:[ "HMAA8GR7AJR4N-XN" ] "p03053 0a1" "P03053-0A1" 64;
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Rdimm ~rangos:2 ~anchura:4 ~velocidad:3200 "p06035 b21" "P06035-B21" 64;
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Rdimm ~rangos:2 ~anchura:4 ~velocidad:3200 "p07650 b21" "P07650-B21" 64;
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Ecc_udimm ~rangos:2 ~anchura:8 ~velocidad:3200 "p06773 001" "P06773-001" 16;
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Rdimm ~rangos:2 ~anchura:4 ~velocidad:2400 "809083 091" "809083-091" 32;
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Rdimm ~velocidad:2400 "809082 091" "809082-091" 16;
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Ecc_udimm ~velocidad:2400 "862689 091" "862689-091" 8;
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Rdimm ~rangos:2 ~anchura:4 ~velocidad:2133 "752370 091" "752370-091" 32;
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Rdimm ~rangos:2 ~anchura:4 ~velocidad:2133 "752371 081" "752371-081" 16;
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Rdimm ~rangos:2 ~anchura:4 ~velocidad:2133 "752371 091" "752371-091" 16;
    m ~oem:"hpe" ~gen:Ddr4 ~fmt:Rdimm ~velocidad:2133 "752367 081" "752367-081" 4;
    m ~oem:"hpe" ~gen:Ddr3 ~fmt:Rdimm ~velocidad:1866 "712382 071" "712382-071" 8;
    m ~oem:"hpe" ~gen:Ddr3 ~fmt:Ecc_udimm ~velocidad:1333 "500209 561" "500209-561" 2;
    (* Lenovo *)
    m ~oem:"lenovo" ~gen:Ddr5 ~fmt:Rdimm "4x77a77031" "4X77A77031" 32;
    m ~oem:"lenovo" ~gen:Ddr5 ~fmt:Sodimm ~velocidad:5600 "5m30z71797" "5M30Z71797" 32;
    (* IBM *)
    m ~oem:"ibm" ~gen:Ddr3 ~fmt:Rdimm ~rangos:2 ~anchura:4 ~velocidad:1066 ~voltaje:1.35 "49y1418" "49Y1418" 16;
    m ~oem:"ibm" ~gen:Ddr3 ~fmt:Rdimm ~velocidad:1333 ~voltaje:1.35 "49y1415" "49Y1415" 8;
    m ~oem:"ibm" ~gen:Ddr3 ~fmt:Rdimm ~rangos:2 ~anchura:8 ~velocidad:1600 ~voltaje:1.35 "00d5038" "00D5038" 8 ]

let por_oem ws i =
  let uno = palabra ws i and dos = palabra ws i ^ " " ^ palabra ws (i + 1) in
  match List.assoc_opt dos oem with
  | Some x -> Some (x, 2)
  | None -> (match List.assoc_opt uno oem with Some x -> Some (x, 1) | None -> None)

(** El módulo que nombra la palabra [i] (y las que le siguen, si son su
    sufijo), con cuántas palabras ocupa. *)
let modulo_en ws i =
  List.find_map (fun f -> f ws i) [ por_oem; samsung; hynix; micron; crucial; ballistix; kingston; corsair; gskill; synology; owc ]

(** Una palabra que parece un part number (letras y cifras, larga) sin que
    ninguna regla la lea. *)
let parece_pn w =
  String.length w >= 8 && String.length w <= 22 && String.exists es_cifra w && String.exists es_letra w
  && (let cifras = String.fold_left (fun a c -> if es_cifra c then a + 1 else a) 0 w in cifras >= 3)
  && List.exists (fun p -> empieza w p) [ "m3"; "m4"; "hma"; "hmt"; "hmc"; "mta"; "mt"; "ct"; "cp"; "ksm"; "kvr"; "kf"; "hx"; "kcp"; "cmk"; "cmw"; "cmt"; "cmh"; "bl" ]

(* --- marcas --------------------------------------------------------------------------- *)

(* Las que se reconocen en un texto (plegadas), con su clave. *)
let marcas =
  [ ("samsung", "samsung"); ("sk hynix", "skhynix"); ("skhynix", "skhynix"); ("hynix", "skhynix"); ("micron", "micron");
    ("crucial", "crucial"); ("ballistix", "crucial"); ("kingston", "kingston"); ("hyperx", "kingston"); ("hyper x", "kingston");
    ("corsair", "corsair"); ("g skill", "gskill"); ("gskill", "gskill"); ("gskil", "gskill"); ("g skil", "gskill"); ("teamgroup", "teamgroup");
    ("team group", "teamgroup"); ("t force", "teamgroup"); ("tforce", "teamgroup"); ("patriot", "patriot"); ("adata", "adata");
    ("xpg", "adata"); ("lexar", "lexar"); ("pny", "pny"); ("mushkin", "mushkin"); ("goodram", "goodram"); ("apacer", "apacer");
    ("transcend", "transcend"); ("silicon power", "siliconpower"); ("timetec", "timetec"); ("klevv", "klevv"); ("netac", "netac");
    ("gigastone", "gigastone"); ("fanxiang", "fanxiang"); ("puskill", "puskill"); ("ramaxel", "ramaxel"); ("nanya", "nanya");
    ("elpida", "elpida"); ("qimonda", "qimonda"); ("infineon", "infineon"); ("atp", "atp"); ("netlist", "netlist"); ("dataram", "dataram");
    ("offtek", "offtek"); ("compuram", "compuram"); ("owc", "owc"); ("kllisre", "kllisre"); ("kamosen", "kamosen"); ("atermiter", "atermiter");
    ("oloy", "oloy"); ("v color", "vcolor"); ("thermaltake", "thermaltake"); ("gigabyte", "gigabyte"); ("aorus", "gigabyte"); ("msi", "msi");
    ("acer", "acer"); ("predator", "acer"); ("hiksemi", "hikvision"); ("kingbank", "kingbank"); ("elixir", "elixir"); ("vdata", "vdata");
    ("advantech", "advantech"); ("cxmt", "cxmt"); ("hpe", "hpe"); ("hp", "hpe"); ("dell", "dell"); ("lenovo", "lenovo"); ("ibm", "ibm");
    ("fujitsu", "fujitsu"); ("cisco", "cisco"); ("oracle", "oracle"); ("supermicro", "supermicro"); ("synology", "synology"); ("qnap", "qnap");
    ("apple", "apple"); ("eaget", "eaget"); ("motoeagle", "motoeagle") ]

(** Las marcas que ponen su etiqueta a módulos de otros. *)
let oems = [ "hpe"; "dell"; "lenovo"; "ibm"; "fujitsu"; "cisco"; "oracle"; "supermicro"; "synology"; "qnap"; "apple" ]

(* --- placas y servidores ------------------------------------------------------------------ *)

type ecc_placa = Si | No | Opcional

type placa = {
  clave : string;
  nombre : string;
  tipo : string;  (** «placa», «servidor» o «plataforma» (un zócalo o un chipset). *)
  generaciones : generacion list;
  formatos : formato list;
  ecc : ecc_placa;
  ranuras : int option;
  canales : int option;  (** Los de toda la placa (con dos zócalos, los de los dos). *)
  velocidad : int option;  (** La máxima, con un módulo por canal. *)
  maximo : int option;  (** GB. *)
  alias : string list;  (** Secuencias de palabras plegadas. *)
}

let ecc_placa_texto = function Si -> "si" | No -> "no" | Opcional -> "opcional"

let servidor_ddr4 = [ Rdimm; Lrdimm; Rdimm_3ds ]

let p ?ranuras ?canales ?velocidad ?maximo ~tipo ~gens ~fmts ~ecc clave nombre alias =
  { clave; nombre; tipo; generaciones = gens; formatos = fmts; ecc; ranuras; canales; velocidad; maximo; alias }

(* Pocas y sabidas: las de la flota, las placas de EPYC que salen en los
   portales y los servidores de los que más se desmonta. Lo demás, por su
   zócalo o su chipset. *)
let placas =
  [ p "asrockrack-rome2d16-2t" "ASRock Rack ROME2D16-2T" ~tipo:"placa" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~ranuras:16 ~canales:16
      ~velocidad:3200 ~maximo:4096 [ "rome2d16 2t"; "rome2d16" ];
    p "asrockrack-b565d4-v1l" "ASRock Rack B565D4-V1L" ~tipo:"placa" ~gens:[ Ddr4 ] ~fmts:[ Udimm; Ecc_udimm ] ~ecc:Opcional ~ranuras:4
      ~canales:2 ~velocidad:3200 ~maximo:128 [ "b565d4 v1l"; "b565d4" ];
    p "asrockrack-romed8-2t" "ASRock Rack ROMED8-2T" ~tipo:"placa" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~ranuras:8 ~canales:8
      ~velocidad:3200 ~maximo:2048 [ "romed8 2t"; "romed8" ];
    p "supermicro-h12ssl" "Supermicro H12SSL" ~tipo:"placa" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~ranuras:8 ~canales:8 ~velocidad:3200
      ~maximo:2048 [ "h12ssl" ];
    p "supermicro-h12dsi" "Supermicro H12DSi" ~tipo:"placa" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~ranuras:16 ~canales:16 ~velocidad:3200
      ~maximo:4096 [ "h12dsi" ];
    p "gigabyte-mz32-ar0" "Gigabyte MZ32-AR0" ~tipo:"placa" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~ranuras:16 ~canales:8 ~velocidad:3200
      ~maximo:4096 [ "mz32 ar0" ];
    p "tyan-s8030" "Tyan S8030" ~tipo:"placa" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~ranuras:8 ~canales:8 ~velocidad:3200 ~maximo:2048
      [ "s8030"; "s8030gm4ne"; "s8030gm2ne" ];
    p "dell-poweredge-r740" "Dell PowerEdge R740" ~tipo:"servidor" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~ranuras:24 ~canales:12
      ~velocidad:2933 ~maximo:3072 [ "r740"; "r740xd"; "poweredge r740" ];
    p "dell-poweredge-r640" "Dell PowerEdge R640" ~tipo:"servidor" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~ranuras:24 ~canales:12
      ~velocidad:2933 ~maximo:3072 [ "r640"; "poweredge r640" ];
    p "dell-poweredge-r630" "Dell PowerEdge R630" ~tipo:"servidor" ~gens:[ Ddr4 ] ~fmts:[ Rdimm; Lrdimm ] ~ecc:Si ~ranuras:24 ~canales:8
      ~velocidad:2400 [ "r630"; "poweredge r630" ];
    p "dell-poweredge-r730" "Dell PowerEdge R730" ~tipo:"servidor" ~gens:[ Ddr4 ] ~fmts:[ Rdimm; Lrdimm ] ~ecc:Si ~ranuras:24 ~canales:8
      ~velocidad:2400 [ "r730"; "r730xd"; "poweredge r730" ];
    p "hpe-proliant-dl380-gen10" "HPE ProLiant DL380 Gen10" ~tipo:"servidor" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~ranuras:24
      ~canales:12 ~velocidad:2933 ~maximo:3072 [ "dl380 gen10"; "dl380 g10" ];
    p "hpe-proliant-dl360-gen10" "HPE ProLiant DL360 Gen10" ~tipo:"servidor" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~ranuras:24
      ~canales:12 ~velocidad:2933 ~maximo:3072 [ "dl360 gen10"; "dl360 g10" ];
    (* Zócalos y chipsets. *)
    p "sp3" "AMD SP3 (EPYC 7001/7002/7003)" ~tipo:"plataforma" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~canales:8 ~velocidad:3200
      [ "sp3"; "epyc 7001"; "epyc 7002"; "epyc 7003"; "epyc rome"; "epyc milan" ];
    p "sp5" "AMD SP5 (EPYC 9004/9005)" ~tipo:"plataforma" ~gens:[ Ddr5 ] ~fmts:[ Rdimm; Rdimm_3ds ] ~ecc:Si ~canales:12
      [ "sp5"; "epyc 9004"; "epyc 9005"; "epyc genoa"; "epyc turin" ];
    p "wrx80" "AMD sWRX8 (WRX80)" ~tipo:"plataforma" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~canales:8 ~velocidad:3200 ~maximo:2048
      [ "wrx80"; "swrx8" ];
    p "trx40" "AMD sTRX4 (TRX40)" ~tipo:"plataforma" ~gens:[ Ddr4 ] ~fmts:[ Udimm; Ecc_udimm ] ~ecc:Opcional ~canales:4 ~maximo:256
      [ "trx40"; "strx4" ];
    p "wrx90" "AMD sTR5 (TRX50/WRX90)" ~tipo:"plataforma" ~gens:[ Ddr5 ] ~fmts:[ Rdimm ] ~ecc:Si [ "wrx90"; "trx50"; "str5" ];
    p "am4" "AMD AM4" ~tipo:"plataforma" ~gens:[ Ddr4 ] ~fmts:[ Udimm; Ecc_udimm ] ~ecc:Opcional ~canales:2 ~velocidad:3200 ~maximo:128
      [ "am4"; "a320"; "b350"; "x370"; "b450"; "x470"; "a520"; "b550"; "x570" ];
    p "am5" "AMD AM5" ~tipo:"plataforma" ~gens:[ Ddr5 ] ~fmts:[ Udimm; Ecc_udimm; Cudimm ] ~ecc:Opcional ~canales:2 ~maximo:256
      [ "am5"; "a620"; "b650"; "b650e"; "x670"; "x670e"; "b840"; "b850"; "x870"; "x870e" ];
    p "lga1700" "Intel LGA1700" ~tipo:"plataforma" ~gens:[ Ddr4; Ddr5 ] ~fmts:[ Udimm ] ~ecc:No ~canales:2
      [ "lga1700"; "lga 1700"; "z690"; "b660"; "h610"; "h670"; "z790"; "b760"; "h770" ];
    p "lga1851" "Intel LGA1851" ~tipo:"plataforma" ~gens:[ Ddr5 ] ~fmts:[ Udimm; Cudimm ] ~ecc:No ~canales:2
      [ "lga1851"; "lga 1851"; "z890"; "b860"; "h810" ];
    p "lga1200" "Intel LGA1200" ~tipo:"plataforma" ~gens:[ Ddr4 ] ~fmts:[ Udimm ] ~ecc:No ~canales:2 ~maximo:128
      [ "lga1200"; "lga 1200"; "z490"; "b460"; "h470"; "h410"; "z590"; "b560"; "h510"; "h570" ];
    p "lga1151" "Intel LGA1151" ~tipo:"plataforma" ~gens:[ Ddr4 ] ~fmts:[ Udimm ] ~ecc:No ~canales:2
      [ "lga1151"; "lga 1151"; "z170"; "b150"; "h170"; "h110"; "z270"; "b250"; "h270"; "z370"; "b360"; "h310"; "h370"; "z390"; "b365" ];
    p "lga2011-3" "Intel LGA2011-3 (X99)" ~tipo:"plataforma" ~gens:[ Ddr4 ] ~fmts:[ Udimm; Rdimm; Lrdimm ] ~ecc:Opcional ~canales:4
      [ "x99"; "lga2011 3"; "lga 2011 3"; "lga2011v3"; "lga2011 v3"; "c612" ];
    p "lga3647" "Intel LGA3647 (Xeon Scalable 1.ª y 2.ª)" ~tipo:"plataforma" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~canales:6
      ~velocidad:2933 [ "lga3647"; "lga 3647" ];
    p "lga4189" "Intel LGA4189 (Xeon Scalable 3.ª)" ~tipo:"plataforma" ~gens:[ Ddr4 ] ~fmts:servidor_ddr4 ~ecc:Si ~canales:8 ~velocidad:3200
      [ "lga4189"; "lga 4189" ];
    p "lga4677" "Intel LGA4677 (Xeon Scalable 4.ª y 5.ª)" ~tipo:"plataforma" ~gens:[ Ddr5 ] ~fmts:[ Rdimm; Rdimm_3ds ] ~ecc:Si ~canales:8
      [ "lga4677"; "lga 4677" ] ]
