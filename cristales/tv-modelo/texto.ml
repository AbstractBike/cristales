(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Leer qué televisores nombra un texto: «LG OLED77C6ELB», «Hisense 75U7SE»,
   «Samsung GQ65S95BAT», «Sony XR-65A95K», «TCL 75C8L», «Sony BRAVIA 9 II
   75″», «Xiaomi TV S Mini LED 55», «una OLED de 77 o una mini-LED de 75».
   Las pulgadas salen de las unidades («75″», «75 pulgadas», «75 Zoll»,
   «75 pollici», «189 cm», «1,89 m»), del código del modelo (OLED77C6,
   75U7SE, TQ77S95H, KD-75X85L, 75PUS8909, TX-65Z95A) o, si se pide, de un
   número suelto de los tamaños que se fabrican («TV Samsung 55 4K»). Lo
   difícil es no confundir: 120 Hz, HDMI 2.1, 4K, 1500 € y «soporte hasta 75
   pulgadas» no son el tamaño de la tele. El plegado y las listas de
   palabras son los de grafica-modelo. *)

module G = Grafica_modelo.Texto
module C = Catalogo

(* --- plegado ------------------------------------------------------------------ *)

let es_cifra c = c >= '0' && c <= '9'
let es_letra c = c >= 'a' && c <= 'z'

(* Las comillas de pulgadas detrás de una cifra («75″», «55”», «65''», «32´´»): una palabra. *)
let comillas =
  [ "''"; "\xe2\x80\x99\xe2\x80\x99"; "\xc2\xb4\xc2\xb4"; "\xe2\x80\x98\xe2\x80\x98"; "\""; "\xe2\x80\x9d"; "\xe2\x80\x9c"; "\xe2\x80\xb3";
    "\xe2\x80\x99"; "'"; "\xc2\xb4" ]

let marca_pulgadas s =
  let n = String.length s in
  let b = Buffer.create (n + 16) in
  let tras_cifra i = (i > 0 && es_cifra s.[i - 1]) || (i > 1 && s.[i - 1] = ' ' && es_cifra s.[i - 2]) in
  let rec ir i =
    if i < n then
      match List.find_opt (fun m -> let l = String.length m in i + l <= n && String.sub s i l = m) comillas with
      | Some m when tras_cifra i ->
        Buffer.add_string b " pulgadas ";
        ir (i + String.length m)
      | _ ->
        Buffer.add_char b s.[i];
        ir (i + 1)
  in
  ir 0;
  Buffer.contents b

(** Las palabras plegadas de [texto], con las comillas de pulgadas como palabra. *)
let palabras texto = Array.of_list (G.palabras (marca_pulgadas texto))

(* Una palabra en trozos de letras y de cifras: «oled77c6elb» -> [oled; 77; c; 6; elb]. *)
type trozo = L of string | D of string

let trozos w =
  let n = String.length w in
  let rec ir i acc =
    if i >= n then List.rev acc
    else
      let c = es_cifra w.[i] in
      let j = ref i in
      while !j < n && es_cifra w.[!j] = c do incr j done;
      let t = String.sub w i (!j - i) in
      ir !j ((if c then D t else L t) :: acc)
  in
  ir 0 []

let empieza s p = String.length s >= String.length p && String.sub s 0 (String.length p) = p

(* --- pulgadas ------------------------------------------------------------- *)

(** Los tamaños que se fabrican: un número suelto solo es pulgadas si es uno de estos. *)
let tamanos =
  [ 19; 20; 21; 22; 24; 25; 26; 27; 28; 29; 32; 37; 39; 40; 42; 43; 46; 47; 48; 49; 50; 52; 55; 58; 60; 65; 70; 75; 77; 82; 83; 85; 86; 98; 100; 115; 116 ]

let unidades =
  [ "pulgadas"; "pulgada"; "pulg"; "pul"; "zoll"; "zol"; "zöll"; "inch"; "inches"; "inc"; "pollici"; "pollice"; "polegadas"; "polegada";
    "pol"; "pouces"; "pouce" ]

(* Lo que, delante de un tamaño, dice que no es el de la tele sino hasta dónde llega un soporte. *)
let hasta = [ "hasta"; "bis"; "upto"; "up"; "to"; "fino"; "ate"; "jusqu"; "max"; "maximo"; "para"; "fur"; "for"; "per"; "pour" ]

(* Lo que, delante de un número suelto, dice que es otra cosa: HDMI 2, PS 5, «serie 7». *)
let despues_de =
  [ "hdmi"; "usb"; "x"; "serie"; "series"; "nr"; "no"; "num"; "modelo"; "model"; "ab"; "from"; "von"; "desde"; "hasta"; "bis"; "ps";
    "windows"; "iphone"; "galaxy"; "playstation"; "xbox"; "gen"; "generacion"; "version"; "v" ]

(* Lo que, detrás de un número, dice que es otra cosa. *)
let no_tamano =
  [ "hz"; "hertz"; "w"; "watt"; "watts"; "cm"; "mm"; "m"; "gb"; "tb"; "mb"; "kg"; "g"; "eur"; "euro"; "euros"; "pct"; "x"; "mhz"; "ghz";
    "k"; "p"; "fps"; "min"; "h"; "horas"; "stunden"; "anos"; "ano"; "jahre"; "jahr"; "meses"; "monate"; "dias"; "tage"; "uds"; "unidades";
    "stuck"; "stk"; "pcs"; "v"; "bit"; "db"; "nits"; "nit"; "cd"; "gen"; "generacion"; "zonas"; "zones" ]

type fuente = Unidad | Cm | Codigo | Suelto

type medida = { valor : int; fuente : fuente; pos : int; compat : bool }

(* 75,4 pulgadas -> 75; 31,5 -> 32. *)
let redondea entero decima = if decima >= 5 then entero + 1 else entero

(* Lo que mide en cm la diagonal: la pulgada de los tamaños que se fabrican más cercana. *)
let de_cm cm =
  let p = float_of_int cm /. 2.54 in
  List.fold_left (fun acc t -> match acc with Some a when abs_float (float_of_int a -. p) <= abs_float (float_of_int t -. p) -> acc | _ -> if abs_float (float_of_int t -. p) <= 1.6 then Some t else acc) None tamanos

let numero s = if s <> "" && String.length s <= 4 && String.for_all es_cifra s then Some (int_of_string s) else None

(** Las medidas que dice [texto] con unidades, en cm (si [cm]) y, si [sueltas], los números sueltos
    de los tamaños que se fabrican: cada una con su posición (la palabra) y si va detrás de un
    «hasta», «bis», «para» (las de un soporte). «55, 65, 75 Zoll» son tres. *)
let medidas ?(cm = true) ?(sueltas = false) texto =
  let ws = palabras texto in
  let n = Array.length ws in
  let out = ref [] in
  let compat i = (i > 0 && List.mem ws.(i - 1) hasta) || (i > 1 && List.mem ws.(i - 2) [ "hasta"; "bis"; "fino"; "up"; "ate" ]) in
  let pon ?(pegado = false) valor fuente pos = if valor >= 13 && valor <= 120 then out := { valor; fuente; pos; compat = pegado || compat pos } :: !out in
  (* Las cifras sueltas de antes de una unidad: «55, 65, 75 Zoll», «43-55″». *)
  let rec cadena k =
    if k >= 0 then
      match numero ws.(k) with
      | Some v when List.mem v tamanos -> pon v Unidad k; cadena (k - 1)
      | _ -> ()
  in
  let anterior i = if i > 0 then numero ws.(i - 1) else None in
  (* «75 Zoll», y «31,5 Zoll» (dos palabras de cifras: la décima redondea). *)
  let con_unidad i d =
    match (numero d, anterior i) with
    | Some x, Some e when String.length d = 1 && e >= 13 && e <= 120 -> pon (redondea e x) Unidad (i - 1)
    | Some x, _ -> pon x Unidad i; cadena (i - 1)
    | None, _ -> ()
  in
  let en_cm i d = match numero d with Some x when x >= 40 && x <= 300 -> Option.iter (fun p -> pon p Cm i) (de_cm x) | _ -> () in
  let en_m i d =
    match (numero d, anterior i) with
    | Some x, Some e when String.length d = 2 && (e = 1 || e = 2) -> Option.iter (fun p -> pon p Cm (i - 1)) (de_cm ((e * 100) + x))
    | _ -> ()
  in
  let siguiente_es i ws_ = i + 1 < n && List.mem ws.(i + 1) ws_ in
  let suelto i d =
    match numero d with
    | Some x
      when List.mem x tamanos
           && (not (siguiente_es i no_tamano))
           && (not (i + 1 < n && match trozos ws.(i + 1) with L u :: _ -> String.length ws.(i + 1) <= 3 && List.mem u no_tamano | _ -> false))
           && not (i > 0 && List.mem ws.(i - 1) despues_de) ->
      pon x Suelto i
    | _ -> ()
  in
  for i = 0 to n - 1 do
    match trozos ws.(i) with
    | [ D d ] when siguiente_es i unidades -> con_unidad i d
    | [ D d; L u ] when List.mem u unidades -> con_unidad i d
    | [ L _; D d; L u ] when List.mem u unidades -> Option.iter (fun x -> pon x Unidad i) (numero d)
    | [ L l; D d ] when siguiente_es i unidades && List.mem l hasta -> Option.iter (fun x -> pon ~pegado:true x Unidad i) (numero d)
    | [ D d ] when cm && siguiente_es i [ "cm" ] -> en_cm i d
    | [ D d; L "cm" ] when cm -> en_cm i d
    | [ D d ] when cm && siguiente_es i [ "m" ] -> en_m i d
    | [ D d; L "m" ] when cm -> en_m i d
    | [ D d ] when sueltas -> suelto i d
    | _ -> ()
  done;
  List.rev !out

(* --- marcas ------------------------------------------------------------------- *)

(** Las marcas que nombra el texto, cada vez, con la palabra donde están. *)
let marcas_en texto =
  let ws = palabras texto in
  let n = Array.length ws in
  let encaja i frase =
    let ps = Array.of_list (String.split_on_char ' ' frase) in
    let k = Array.length ps in
    i + k <= n && Array.for_all Fun.id (Array.init k (fun j -> ws.(i + j) = ps.(j)))
  in
  let vistas = ref [] in
  for i = 0 to n - 1 do
    List.iter (fun (f, m) -> if encaja i f then vistas := (m, i) :: !vistas) C.marcas;
    (* «LG50», «lgoled»: la marca pegada. *)
    if empieza ws.(i) "lg" && String.length ws.(i) > 2 && (es_cifra ws.(i).[2] || empieza ws.(i) "lgoled") then vistas := ("lg", i) :: !vistas
  done;
  List.rev !vistas

(** Las marcas que nombra el texto, en el orden en que aparecen, sin repetir. *)
let marcas texto = List.fold_left (fun acc (m, _) -> if List.mem m acc then acc else acc @ [ m ]) [] (marcas_en texto)

(* --- códigos de modelo ----------------------------------------------------------- *)

(** Una familia leída de un código («OLED77C6ELB») o nombrada («BRAVIA 9 II»). *)
type familia = {
  marca : string;
  codigo : string;  (** El del modelo sin marca ni tamaño, como se compone el canónico: «C6», «S95H», «U7SE», «XR90». *)
  clave : string;  (** Plegada, para el catálogo: «c6», «s95h», «u7se», «xr90». *)
  entrada : C.serie option;  (** La serie del catálogo, si la tiene. *)
  anio : int option;  (** El del código, si lo dice. *)
  tecnologia : C.tecnologia option;  (** La que dice el código, si no está en el catálogo. *)
  ocho_k : bool;
  crystal : bool;  (** Un Crystal UHD de Samsung: su prefijo es UE, no TQ. *)
  generica : bool;  (** Nombrada por la familia, sin año («Hisense U7»): de la serie, solo lo común. *)
}

type mencion = { familia : familia; pulgadas : int option; pos : int }

let fam ?anio ?tecnologia ?(ocho_k = false) ?(crystal = false) ?codigo marca clave =
  let entrada = C.busca marca clave in
  let codigo = Option.value codigo ~default:(String.uppercase_ascii clave) in
  let anio = match entrada with Some { anio = Some a; _ } -> Some a | _ -> anio in
  let ocho_k = ocho_k || match entrada with Some e -> e.ocho_k | None -> false in
  { marca; codigo; clave; entrada; anio; tecnologia; ocho_k; crystal; generica = false }

let tamano d =
  match numero d with
  | Some x when (String.length d = 2 && x >= 13) || (String.length d = 3 && x >= 100 && x <= 116) -> Some x
  | _ -> None
let primera s = if s = "" then None else Some s.[0]
let ch c = String.make 1 c

(* LG OLED: «oled77c6elb», «oled55c97la», «oled77cs9la», «oled65gx9lb»; sin «oled», con la marca: «77c31la», «65g6». *)
let lg_oled ts =
  let serie = function
    | L "cs" :: _ -> Some "cs"
    | L l :: _ when String.length l = 2 && String.contains "bcgzwe" l.[0] && l.[1] = 'x' -> Some l
    | L l :: D d :: _ when String.length l = 1 && String.contains "bcgzweamr" l.[0] -> Some (l ^ ch d.[0])
    | [ L l; D d ] when String.length l = 1 && String.contains "bcgzwe" l.[0] -> Some (l ^ ch d.[0])
    | _ -> None
  in
  let con_tamano d resto =
    match (tamano d, serie resto) with
    | Some p, Some k -> Some (fam "lg" k ?anio:(C.anio_lg k.[1]) ~tecnologia:C.Oled ~ocho_k:(k.[0] = 'z'), Some p)
    | _ -> None
  in
  match ts with
  | L "oled" :: D d :: resto -> (con_tamano d resto, true)
  | D d :: (L _ :: D _ :: _ as resto) | D d :: ([ L _ ] as resto) -> (con_tamano d resto, false)
  | _ -> (None, false)

(* LG LCD: «55up77», «55uj620v», «65qned86a6», «55nano86», «55lf5800». *)
let lg_lcd ts =
  match ts with
  | D d :: L l :: D n :: resto when tamano d <> None ->
    let p = tamano d in
    let n2 = if String.length n > 2 then String.sub n 0 2 else n in
    if l = "qned" || l = "nano" then
      let anio = match resto with L r :: _ -> (match r.[0] with 'r' -> Some 2023 | 't' -> Some 2024 | 'a' -> Some 2025 | _ -> None) | _ -> None in
      Some (fam "lg" (l ^ n2) ?anio ~tecnologia:(if l = "qned" then C.Qled else C.Led), p)
    else if String.length l = 2 && (l.[0] = 'u' || l.[0] = 'l') then
      let anio =
        if l.[0] = 'u' then
          match l.[1] with
          | 'j' -> Some 2017 | 'k' -> Some 2018 | 'm' -> Some 2019 | 'n' -> Some 2020 | 'p' -> Some 2021 | 'q' -> Some 2022 | 'r' -> Some 2023
          | 't' -> Some 2024 | 'a' -> Some 2025 | _ -> None
        else None
      in
      Some (fam "lg" (l ^ n2) ?anio ~tecnologia:C.Led, p)
    else None
  | _ -> None

let normaliza_s dd = match dd with "92" | "93" | "94" -> "90" | _ -> dd

(* Samsung, detrás del tamaño (o sin él): «s95b», «qn85c», «qn800c», «q60d», «q67d», «q7f», «au9005», «u7000f», «ls03d», «m70h». *)
let samsung_serie resto =
  match resto with
  | L "s" :: D dd :: L l :: _ when String.length dd = 2 ->
    let dd = normaliza_s dd in
    let tec = if dd = "95" then C.Qd_oled else C.Oled in
    Some (fam "samsung" ("s" ^ dd ^ ch l.[0]) ?anio:(C.anio_samsung l.[0]) ~tecnologia:tec)
  | L "qn" :: D n :: L l :: _ when String.length n = 2 || String.length n = 3 ->
    Some (fam "samsung" ("qn" ^ n ^ ch l.[0]) ?anio:(C.anio_samsung l.[0]) ~tecnologia:C.Mini_led ~ocho_k:(String.length n = 3))
  | L "q" :: D n :: L l :: _ when String.length n = 2 ->
    Some (fam "samsung" ("q" ^ ch n.[0] ^ "0" ^ ch l.[0]) ?anio:(C.anio_samsung l.[0]) ~tecnologia:C.Qled)
  | L "q" :: D n :: L l :: _ when String.length n = 1 && String.contains "fh" l.[0] && not (String.length l = 2 && l.[1] = 'n') ->
    Some (fam "samsung" ("q" ^ n ^ ch l.[0]) ?anio:(C.anio_samsung l.[0]) ~tecnologia:C.Qled)
  | L l :: D n :: _ when String.length l = 2 && l.[1] = 'u' && String.length n = 4 && String.contains "kmnrtabcd" l.[0] ->
    Some (fam "samsung" (l ^ ch n.[0] ^ "000") ?anio:(C.anio_samsung l.[0]) ~tecnologia:C.Led ~crystal:true)
  | L "u" :: D n :: L l :: _ when String.length n = 4 ->
    Some (fam "samsung" ("u" ^ n ^ ch l.[0]) ?anio:(C.anio_samsung l.[0]) ~tecnologia:C.Led ~crystal:true)
  | L "ls" :: D "03" :: L l :: _ ->
    Some (fam "samsung" ("ls03" ^ ch l.[0]) ?anio:(C.anio_samsung l.[0]) ~tecnologia:C.Qled ~codigo:("LS03" ^ String.uppercase_ascii (ch l.[0])))
  | L "m" :: D n :: L l :: _ when String.length n = 2 && l.[0] = 'h' ->
    Some (fam "samsung" ("m" ^ n ^ ch l.[0]) ?anio:(C.anio_samsung l.[0]) ~tecnologia:C.Mini_led)
  | _ -> None

let prefijos_samsung = [ "tq"; "qe"; "gq"; "ue"; "gu"; "un"; "qn"; "ua" ]

(* Con el prefijo de un mercado (TQ, QE, GQ, UE…) el código es de Samsung aunque no lo diga; sin él,
   solo si nombra la marca. «QN85C» no es un prefijo QN y un tamaño 85: si con el prefijo no sale
   una serie, se lee entero. *)
let con_o_sin_prefijo prefijos serie ts ~marca =
  let con =
    match ts with
    | L pre :: D d :: resto when List.mem pre prefijos && tamano d <> None -> Option.map (fun f -> (f, tamano d)) (serie resto)
    | _ -> None
  in
  match con with
  | Some _ -> con
  | None when not marca -> None
  | None -> (
    match ts with
    | D d :: resto when tamano d <> None -> Option.map (fun f -> (f, tamano d)) (serie resto)
    | _ -> Option.map (fun f -> (f, None)) (serie ts))

let samsung = con_o_sin_prefijo prefijos_samsung samsung_serie

(* Sony, detrás del tamaño: «a95k», «x85l», «xr90», «xr8m2», «xr80m2», «s30», «af8», «xh9096». *)
let sony_serie resto =
  match resto with
  | L "xr" :: D d :: L "m" :: D "2" :: _ -> Some (fam "sony" ("xr" ^ ch d.[0] ^ "m2"))
  | L "xr" :: D (("90" | "80" | "70" | "50") as d) :: _ -> Some (fam "sony" ("xr" ^ d))
  | L "s" :: D (("30" | "25") as d) :: _ -> Some (fam "sony" ("s" ^ d) ~tecnologia:C.Led)
  | L "a" :: D dd :: L l :: _ when String.length dd = 2 -> Some (fam "sony" ("a" ^ dd ^ ch l.[0]) ?anio:(C.anio_sony l.[0]) ~tecnologia:C.Oled)
  | L "x" :: D dd :: L l :: _ when String.length dd = 2 ->
    let k = if empieza l "wl" then "wl" else ch l.[0] in
    Some (fam "sony" ("x" ^ dd ^ k) ?anio:(C.anio_sony l.[0]) ~tecnologia:C.Led)
  | L l :: D d :: _ when String.length l = 2 && (l.[0] = 'a' || l.[0] = 'x') && C.anio_sony l.[1] <> None ->
    let n = if String.length d >= 2 then String.sub d 0 2 else d in
    Some (fam "sony" (l ^ n) ?anio:(C.anio_sony l.[1]) ~tecnologia:(if l.[0] = 'a' then C.Oled else C.Led))
  | _ -> None

let prefijos_sony = [ "kd"; "xr"; "ke"; "k"; "kdl"; "fw"; "fwd" ]

let sony = con_o_sin_prefijo prefijos_sony sony_serie

(* Panasonic: «tx65z95a», «tx42mz800e», «tx40hxw804», «txl39e6e»; con la marca, «mz2000», «z95b». *)
let panasonic_serie resto =
  match resto with
  | L x :: D n :: resto2 when String.length x <= 3 ->
    let k =
      match (x, resto2) with
      | ("z" | "w"), L l :: _ when l.[0] = 'a' || l.[0] = 'b' -> x ^ n ^ ch l.[0]
      | _ -> x ^ n
    in
    let tec =
      if x = "z" || (String.length x = 2 && x.[1] = 'z') then Some C.Oled
      else if x = "w" then Some (match numero n with Some v when v >= 93 -> C.Mini_led | _ -> C.Led)
      else Some C.Led
    in
    Some (fam "panasonic" k ?tecnologia:tec)
  | _ -> None

let panasonic ts ~marca =
  match ts with
  | L "tx" :: D d :: resto when tamano d <> None -> Option.map (fun f -> (f, tamano d)) (panasonic_serie resto)
  | (L x :: D _ :: _ as resto) when marca && String.length x = 2 && String.contains "efghjlm" x.[0] && (x.[1] = 'z' || x.[1] = 'x') ->
    Option.map (fun f -> (f, None)) (panasonic_serie resto)
  | (L ("z" | "w") :: D n :: L _ :: _ as resto) when marca && String.length n = 2 -> Option.map (fun f -> (f, None)) (panasonic_serie resto)
  | _ -> None

(* Philips: «65oled856», «50pus7805», «55pml9059», «42pfl6007h»; con la marca, «oled811», «pus8909». *)
let familias_philips = [ "oled"; "pus"; "pml"; "pfl"; "pfh"; "pfs"; "pos"; "pud"; "put"; "pht" ]

let philips_serie x n =
  let tec = match x with "oled" | "pos" -> C.Oled | "pml" -> C.Mini_led | _ -> C.Led in
  let anio = if (x = "oled" || x = "pus" || x = "pml" || x = "pos") && String.length n >= 3 then C.anio_philips n.[String.length n - 1] else None in
  fam "philips" (x ^ n) ?anio ~tecnologia:tec

let philips ts ~marca =
  match ts with
  | D d :: L x :: D n :: _ when List.mem x familias_philips && tamano d <> None && String.length n >= 3 -> Some (philips_serie x n, tamano d)
  | L x :: D n :: _ when marca && List.mem x familias_philips && String.length n >= 3 -> Some (philips_serie x n, None)
  | _ -> None

(* Hisense, con la marca: «75u7se», «85u7q» (+ «pro»), «55u7kq», «65a85n», «65e77q», «65u77hq», «85uxkq». *)
let hisense ts ~marca ~pro =
  if not marca then None
  else
    let decide d codigo =
      let familia, anio =
        match trozos codigo with
        | L x :: D n :: L l :: _ when x = "a" -> (x ^ n, C.anio_hisense l.[0])
        | L x :: D n :: L l :: _ -> (x ^ ch n.[0], C.anio_hisense l.[0])
        | L x :: D n :: _ -> ((if x = "a" then x ^ n else x ^ ch n.[0]), None)
        | [ L x ] when empieza x "ux" -> ("ux", if String.length x > 2 then C.anio_hisense x.[2] else None)
        | _ -> ("", None)
      in
      if familia = "" then None
      else
        let anyo_l = match anio with Some a -> List.find_opt (fun (_, y) -> y = a) [ ('g', 2021); ('h', 2022); ('k', 2023); ('n', 2024); ('q', 2025); ('s', 2026) ] | None -> None in
        let corta = match anyo_l with Some (l, _) -> familia ^ ch l | None -> familia in
        let pro_s = if pro then "pro" else "" in
        let entrada = match C.busca "hisense" (codigo ^ pro_s) with Some e -> Some e | None -> (match C.busca "hisense" codigo with Some e -> Some e | None -> C.busca "hisense" corta) in
        let tec = if familia.[0] = 'a' && String.length familia >= 3 && familia.[1] >= '8' then Some C.Oled else if familia.[0] = 'a' then Some C.Led else if familia.[0] = 'e' then Some C.Qled else if familia = "ux" then Some C.Mini_led else None in
        let codigo_s = String.uppercase_ascii codigo ^ if pro then " PRO" else "" in
        let f = { (fam "hisense" corta ?anio ?tecnologia:tec ~codigo:codigo_s) with entrada } in
        let f = match entrada with Some { anio = Some a; _ } -> { f with anio = Some a } | _ -> f in
        Some (f, tamano d)
    in
    match ts with
    | D d :: (L x :: _ as resto) when tamano d <> None && (String.contains "uae" x.[0]) && String.length x <= 4 ->
      let codigo = String.concat "" (List.map (function L s | D s -> s) resto) in
      decide d codigo
    | _ -> None

(* TCL, con la marca: «75c8l», «55c7k», «98c805», «50q7c», «65t8b», «32s5200», «55qm8b». *)
let tcl_serie x n resto =
  let l = match resto with L l :: _ -> Some l.[0] | _ -> None in
  let corta = String.length n <= 2 in
  let k = match l with Some c when corta && String.contains "klbc" c -> x ^ n ^ ch c | _ -> x ^ n in
  let anio = match l with Some 'l' when corta -> Some 2026 | Some 'k' when corta -> Some 2025 | Some 'b' when corta -> Some 2024 | _ -> None in
  let tec = match x with ("c" | "qm" | "x") when corta -> Some C.Mini_led | "q" | "t" -> Some C.Qled | "p" | "v" | "s" -> Some C.Led | _ -> None in
  fam "tcl" k ?anio ?tecnologia:tec

let tcl ts ~marca =
  if not marca then None
  else
    match ts with
    | D d :: L x :: D n :: resto when tamano d <> None && List.mem x [ "c"; "p"; "qm"; "q"; "t"; "v"; "s"; "x"; "z"; "ep"; "rp"; "dp"; "rc"; "qd" ] ->
      Some (tcl_serie x n resto, tamano d)
    | L x :: D n :: resto when List.mem x [ "c"; "qm"; "x"; "p" ] && (String.length n = 1 || (String.length n = 2 && x = "x") || String.length n = 3) && (resto <> [] || String.length n = 3) ->
      Some (tcl_serie x n resto, None)
    | _ -> None

(* Cualquier marca: un prefijo corto, el tamaño y una letra («h65m80fux», «k24dlx10h», «l55ma»): solo el tamaño. *)
let generico ts =
  match ts with
  | L pre :: D d :: L _ :: _ when String.length pre <= 3 && String.length d = 2 -> (match tamano d with Some p when List.mem p tamanos -> Some p | _ -> None)
  | D d :: L l :: resto
    when String.length d = 2 && String.length l <= 4
         && not ((resto = [] && (List.mem l unidades || List.mem l no_tamano)) || l = "hd" || l = "uhd" || l = "fhd" || l = "k" || l = "p") ->
    (match tamano d with Some p when List.mem p tamanos -> Some p | _ -> None)
  | _ -> None

let pegables = [ "oled"; "xr"; "kd"; "ke"; "k"; "kdl"; "tx"; "tq"; "qe"; "gq"; "ue"; "gu"; "un"; "qn"; "l" ]

type codigo = { mencion : mencion option; solo_pulgadas : (int * int) option }

(** Los códigos de modelo del texto, en orden: las familias que dicen (con su tamaño, si lo
    llevan) y los tamaños que dicen los códigos sin familia («H65M80FUX»). *)
let codigos texto =
  let ws = palabras texto in
  let n = Array.length ws in
  let ms = marcas texto in
  let hay m = List.mem m ms in
  let tv_marca = ms <> [] in
  let out = ref [] in
  let i = ref 0 in
  while !i < n do
    let w = ws.(!i) in
    let pegado = !i + 1 < n && List.mem w pegables && ws.(!i + 1) <> "" && es_cifra ws.(!i + 1).[0] in
    let cand = if pegado then w ^ ws.(!i + 1) else w in
    let ts = trozos cand in
    let pro = !i + (if pegado then 2 else 1) < n && ws.(!i + if pegado then 2 else 1) = "pro" in
    let unicos =
      [ (fun () -> match lg_oled ts with Some x, true -> Some x | Some x, false when hay "lg" -> Some x | _ -> None);
        (fun () -> samsung ts ~marca:(hay "samsung"));
        (fun () -> sony ts ~marca:(hay "sony"));
        (fun () -> panasonic ts ~marca:(hay "panasonic"));
        (fun () -> philips ts ~marca:(hay "philips"));
        (fun () -> hisense ts ~marca:(hay "hisense") ~pro);
        (fun () -> tcl ts ~marca:(hay "tcl"));
        (* Xiaomi: «L75MA-SME» es la S Mini LED de 75. *)
        (fun () ->
          match ts with
          | [ L "l"; D d; L "ma" ] when !i + 1 < n && (ws.(!i + 1) = "sme" || ws.(!i + 1) = "sm") -> Some (fam "xiaomi" "smini" ~codigo:"S Mini LED", tamano d)
          | _ -> None);
        (fun () -> if hay "lg" then lg_lcd ts else None) ]
    in
    (* Con varias marcas, la que se nombra antes manda: se prueban en el orden de [ms]. *)
    let orden = function
      | 0 -> "lg" | 1 -> "samsung" | 2 -> "sony" | 3 -> "panasonic" | 4 -> "philips" | 5 -> "hisense" | 6 -> "tcl" | _ -> "lg"
    in
    let rango m = match List.find_index (( = ) m) ms with Some k -> k | None -> 99 in
    let probados = List.mapi (fun k f -> (k, f)) unicos |> List.sort (fun (a, _) (b, _) -> compare (rango (orden a)) (rango (orden b))) in
    let hallado = List.find_map (fun (_, f) -> f ()) probados in
    (match hallado with
     | Some (familia, pulgadas) -> out := { mencion = Some { familia; pulgadas; pos = !i }; solo_pulgadas = None } :: !out
     | None -> (
       (* «E77Q» es una serie de Hisense, no un tamaño de 77. *)
       let es_serie = List.exists (fun (x : C.serie) -> List.mem x.marca ms && (x.clave = cand || List.mem cand x.alias)) C.series in
       match if tv_marca && not es_serie then generico ts else None with
       | Some p -> out := { mencion = None; solo_pulgadas = Some (p, !i) } :: !out
       | None -> ()));
    i := !i + if pegado && hallado <> None then 2 else 1
  done;
  List.rev !out

(* --- series nombradas sin código ------------------------------------------------- *)

(* Las frases (en palabras plegadas) con que se nombra cada serie: sus alias, su clave y su nombre. *)
let frases =
  List.concat_map
    (fun (x : C.serie) ->
      (* La clave y el nombre, si llevan cifra («c6», «bravia 9»): «max» o «a» solos serían palabras. *)
      let con_cifra f = String.exists es_cifra f in
      let propias = List.filter con_cifra [ x.clave; String.concat " " (G.palabras x.serie) ] @ x.alias in
      List.sort_uniq compare (List.filter (fun f -> String.length f > 1) propias)
      |> List.map (fun f -> (Array.of_list (String.split_on_char ' ' f), x)))
    C.series

(** Las series que el texto nombra sin código («LG C5», «Sony BRAVIA 8 II», «Xiaomi TV S Mini LED»), con
    su marca nombrada: la frase más larga en cada sitio; la primera serie del catálogo (la más nueva) si
    una frase es de varias («U7»). *)
let series texto =
  let ws = palabras texto in
  let n = Array.length ws in
  let en = marcas_en texto in
  let encaja i a = let k = Array.length a in i + k <= n && Array.for_all Fun.id (Array.init k (fun j -> ws.(i + j) = a.(j))) in
  let out = ref [] in
  let i = ref 0 in
  while !i < n do
    (* La marca de la frase: la nombrada antes más cerca; si no hay, la primera de después. *)
    let suya =
      match List.rev (List.filter (fun (_, p) -> p < !i) en) with
      | (m, _) :: _ -> Some m
      | [] -> (match List.find_opt (fun (_, p) -> p >= !i) en with Some (m, _) -> Some m | None -> None)
    in
    let cs = List.filter (fun (a, (x : C.serie)) -> Some x.marca = suya && encaja !i a) frases in
    match cs with
    | [] -> incr i
    | _ ->
      let largo = List.fold_left (fun m (a, _) -> max m (Array.length a)) 0 cs in
      (* La del catálogo que va antes entre las de esa frase: las series van de la más nueva a la más vieja. *)
      let x = List.find (fun (y : C.serie) -> List.exists (fun (a, z) -> z == y && Array.length a = largo) cs) C.series in
      (* Una frase de varias series («U7»: U7SE, U7S PRO, U7Q, U7N…) nombra la familia, sin año. *)
      let generica = List.exists (fun (a, (z : C.serie)) -> Array.length a = largo && z.clave <> x.clave) cs in
      let f = fam x.marca x.clave ~codigo:(String.uppercase_ascii x.clave) in
      let f = if generica then { f with codigo = x.serie; anio = None; generica } else f in
      out := { familia = f; pulgadas = None; pos = !i } :: !out;
      i := !i + largo
  done;
  List.rev !out

(* --- lo demás que dice el texto ------------------------------------------------------ *)

let tecnologias_frases =
  [ ([ "qd"; "oled" ], C.Qd_oled); ([ "qdoled" ], C.Qd_oled); ([ "rgb"; "mini"; "led" ], C.Rgb_mini_led); ([ "rgb"; "miniled" ], C.Rgb_mini_led);
    ([ "micro"; "rgb" ], C.Rgb_mini_led); ([ "rgb"; "mini" ], C.Rgb_mini_led); ([ "rgb"; "led" ], C.Rgb_mini_led);
    ([ "qd"; "mini"; "led" ], C.Mini_led); ([ "qd"; "miniled" ], C.Mini_led); ([ "mini"; "led" ], C.Mini_led); ([ "miniled" ], C.Mini_led);
    ([ "neo"; "qled" ], C.Mini_led); ([ "neoqled" ], C.Mini_led); ([ "mled" ], C.Mini_led); ([ "oled" ], C.Oled); ([ "woled" ], C.Oled);
    ([ "qled" ], C.Qled); ([ "hi"; "qled" ], C.Qled); ([ "qned" ], C.Qled); ([ "quantum"; "dot" ], C.Qled); ([ "nanocell" ], C.Led);
    ([ "crystal"; "uhd" ], C.Led); ([ "led" ], C.Led); ([ "lcd" ], C.Led) ]

(** Las tecnologías que nombra el texto, cada vez que las nombra, con la palabra donde están:
    «QD-OLED» es una sola, no también OLED; «Neo QLED», mini-LED. *)
let tecnologias_en texto =
  let ws = palabras texto in
  let n = Array.length ws in
  let encaja i ps = let k = List.length ps in i + k <= n && List.for_all Fun.id (List.mapi (fun j p -> ws.(i + j) = p) ps) in
  let out = ref [] in
  let i = ref 0 in
  while !i < n do
    match List.find_opt (fun (ps, _) -> encaja !i ps) tecnologias_frases with
    | Some (ps, t) -> out := (t, !i) :: !out; i := !i + List.length ps
    | None -> incr i
  done;
  List.rev !out

(** Las tecnologías que nombra el texto, en orden y sin repetir. *)
let tecnologias texto = List.fold_left (fun acc (t, _) -> if List.mem t acc then acc else acc @ [ t ]) [] (tecnologias_en texto)

let prioridad = [ C.Qd_oled; C.Rgb_mini_led; C.Mini_led; C.Oled; C.Qled; C.Led ]

(** La tecnología que manda entre las que dice. *)
let tecnologia texto = let ts = tecnologias texto in List.find_opt (fun t -> List.mem t ts) prioridad

let resolucion texto =
  if G.contiene texto [ "8k"; "8 k"; "4320p" ] then Some "8k"
  else if G.contiene texto [ "4k"; "4 k"; "uhd"; "ultra hd"; "ultrahd"; "2160p"; "4k2k"; "ultra alta definicion" ] then Some "4k"
  else if G.contiene texto [ "full hd"; "fullhd"; "fhd"; "1080p"; "1080"; "1920x1080"; "full h d" ] then Some "fhd"
  else if G.contiene texto [ "hd ready"; "hd"; "720p"; "1366x768"; "hdready" ] then Some "hd"
  else None

(** Los Hz que dice («120Hz», «144 Hz», «120 hertz»): el mayor. *)
let hz texto =
  let ws = palabras texto in
  let n = Array.length ws in
  let mejor = ref None in
  let pon v = if v >= 50 && v <= 500 then mejor := Some (match !mejor with Some m -> max m v | None -> v) in
  for i = 0 to n - 1 do
    match trozos ws.(i) with
    | [ D d; L ("hz" | "hertz") ] -> Option.iter pon (numero d)
    | [ D d ] when i + 1 < n && (ws.(i + 1) = "hz" || ws.(i + 1) = "hertz") -> Option.iter pon (numero d)
    | _ -> ()
  done;
  !mejor

let hdmi21 texto = if G.contiene texto [ "hdmi 2 1"; "hdmi2 1"; "hdmi 21"; "hdmi2 1a" ] then Some true else None

let sistema texto =
  if G.contiene texto [ "google tv"; "googletv" ] then Some C.Google_tv
  else if G.contiene texto [ "webos"; "web os" ] then Some C.Webos
  else if G.contiene texto [ "tizen" ] then Some C.Tizen
  else if G.contiene texto [ "vidaa" ] then Some C.Vidaa
  else if G.contiene texto [ "titan os"; "titanos" ] then Some C.Titan
  else if G.contiene texto [ "fire tv"; "fireos"; "fire os"; "firetv" ] && not (G.contiene texto [ "fire tv stick"; "fire stick"; "firestick"; "fire tv cube"; "firetv stick" ])
  then Some C.Fire_tv
  else if G.contiene texto [ "android tv"; "androidtv"; "android" ] then Some C.Android_tv
  else None
