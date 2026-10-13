(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Leer qué memoria dice un texto: «2x 16GB DDR4-3200 CL16», «64GB ECC REG
   PC4-2933Y-RB3 2Rx4», «Kit 16GB RAM DDR3 1333Mhz ECC (2x8GB)», «4× Samsung
   64GB DDR4-3200 ECC REG RDIMM M393A8G40AB2-CWE». Lo difícil es contar:
   «2x32GB» son dos módulos de 32, no uno de 64; «64GB Kit» es un kit, no un
   módulo; «64GB (4x16GB)», cuatro de 16; «4 Stück verfügbar», unidades
   sueltas. Y no confundir: 3200 es una velocidad y 25600 su ancho de banda;
   512GB SSD es un disco; 3200G, un procesador. El plegado y las listas de
   palabras son los de grafica-modelo (Grafica_modelo.Texto). *)

open Catalogo
module G = Grafica_modelo.Texto

(* --- plegado ---------------------------------------------------------------- *)

(* «55€/ud»: el euro queda como palabra, para no leer «55 ud» como 55 unidades. *)
let tildes = ("×", "x") :: ("€", " eur ") :: ("–", " ") :: ("—", " ") :: ("„", " ") :: ("“", " ") :: ("”", " ") :: G.tildes

(** Minúsculas ASCII sin tildes; lo que no es letra ni cifra, espacio. El «+»
    no se lee como «plus» (a diferencia de grafica-modelo) y la coma decimal
    entre cifras se queda como «d». *)
let pliega s =
  let s = List.fold_left (fun acc (a, b) -> G.reemplaza_todo a b acc) s tildes in
  (* «2.5GB», «1,92 TB»: la coma decimal queda como «d» entre las cifras. *)
  let n = String.length s in
  let s = String.mapi (fun i c -> if (c = '.' || c = ',') && i > 0 && i + 1 < n && es_cifra s.[i - 1] && es_cifra s.[i + 1] then 'd' else c) s in
  String.map (fun c -> match c with 'A' .. 'Z' -> Char.lowercase_ascii c | 'a' .. 'z' | '0' .. '9' -> c | _ -> ' ') s

(* «8xM393A8G40AB2», «10xHynix»: la cuenta pegada a lo que cuenta va aparte («8x m393a8g40ab2»).
   «2x16gb» se queda como está: ahí la cuenta va con la capacidad. *)
let separa_cuenta w =
  let n = String.length w in
  let rec cifras i = if i < n && es_cifra w.[i] then cifras (i + 1) else i in
  let i = cifras 0 in
  if i >= 1 && i <= 2 && n - i - 1 >= 4 && w.[i] = 'x' && es_letra w.[i + 1] then [ String.sub w 0 (i + 1); String.sub w (i + 1) (n - i - 1) ] else [ w ]

let palabras texto = Array.of_list (List.concat_map separa_cuenta (List.filter (( <> ) "") (String.split_on_char ' ' (pliega texto))))

(** Los trozos de letras o de cifras de una palabra: «2rx4» → [2; rx; 4]. *)
let trozos w =
  let n = String.length w in
  let rec ir i acc =
    if i >= n then List.rev acc
    else
      let cifra = es_cifra w.[i] in
      let j = ref i in
      while !j < n && es_cifra w.[!j] = cifra do incr j done;
      ir !j (String.sub w i (!j - i) :: acc)
  in
  ir 0 []

let es_numero w = todo_cifras w
let num w = if es_numero w && String.length w <= 6 then int_of_string_opt w else None

(** ¿Está la secuencia de palabras [frase] («dual kit») en [ws] a partir de [i]? *)
let encaja_partes ws i partes =
  let k = Array.length partes in
  let rec ir j = j >= k || (ws.(i + j) = partes.(j) && ir (j + 1)) in
  i + k <= Array.length ws && ir 0

let partes frase = Array.of_list (String.split_on_char ' ' frase)
let encaja ws i frase = encaja_partes ws i (partes frase)

(** La posición de la primera de [frases] en [ws]. *)
let posicion ws frases =
  let n = Array.length ws in
  let frases = List.map partes frases in
  let rec busca i = if i >= n then None else if List.exists (encaja_partes ws i) frases then Some i else busca (i + 1) in
  busca 0

let hay ws frases = posicion ws frases <> None

(* --- generación ------------------------------------------------------------------ *)

(* El ancho de banda de las etiquetas (PC3-12800, PC4-25600) a MT/s y su generación. *)
let anchos_de_banda =
  [ (1600, (Ddr, 200)); (2100, (Ddr, 266)); (2700, (Ddr, 333)); (3200, (Ddr, 400)); (4200, (Ddr2, 533)); (4300, (Ddr2, 533));
    (5300, (Ddr2, 667)); (6400, (Ddr2, 800)); (8500, (Ddr3, 1066)); (10600, (Ddr3, 1333)); (10666, (Ddr3, 1333)); (12800, (Ddr3, 1600));
    (14900, (Ddr3, 1866)); (17000, (Ddr4, 2133)); (19200, (Ddr4, 2400)); (21300, (Ddr4, 2666)); (23400, (Ddr4, 2933)); (25600, (Ddr4, 3200));
    (38400, (Ddr5, 4800)); (41600, (Ddr5, 5200)); (44800, (Ddr5, 5600)); (51200, (Ddr5, 6400)) ]

let gen_de_cifra = function "1" -> Some Ddr | "2" -> Some Ddr2 | "3" -> Some Ddr3 | "4" -> Some Ddr4 | "5" -> Some Ddr5 | _ -> None

type marca_gen = { gen : generacion; en : int; baja : bool; velocidad : int option }

(** Las generaciones que nombra el texto, en orden: «DDR4», «DDR 4», «DDR3L»,
    «PC4», «PC3L», «PC2», «PC5», «PC3200» (DDR), «PC133» (SDR); con la
    velocidad si va pegada («DDR42133», «PC21300»). LPDDR y GDDR no cuentan:
    van soldadas. *)
let generaciones ws =
  let out = ref [] in
  let n = Array.length ws in
  Array.iteri
    (fun i w ->
      let tr = trozos w in
      let add ?(baja = false) ?velocidad gen = out := { gen; en = i; baja; velocidad } :: !out in
      match tr with
      | "ddr" :: d :: resto when String.length d = 1 -> (
        match gen_de_cifra d with Some g -> add ~baja:(List.mem "l" resto) g | None -> ())
      | "ddr" :: d :: _ when String.length d = 5 -> (
        (* «DDR42133»: la generación y la velocidad pegadas. *)
        match gen_de_cifra (String.sub d 0 1) with
        | Some g ->
          let v = int_of_string (String.sub d 1 4) in
          add ?velocidad:(if List.mem v (velocidades g) then Some v else None) g
        | None -> ())
      | [ "ddr" ] -> (
        match if i + 1 < n then trozos ws.(i + 1) else [] with
        | [ d ] when String.length d = 1 -> Option.iter add (gen_de_cifra d)
        | [ d; "l" ] when String.length d = 1 -> Option.iter (add ~baja:true) (gen_de_cifra d)
        | d :: _ when List.mem d [ "266"; "333"; "400" ] -> add Ddr
        | _ -> ())
      | "pc" :: d :: resto when es_numero d -> (
        match String.length d with
        | 1 -> Option.iter (add ~baja:(List.mem "l" resto)) (gen_de_cifra d)
        | 3 when d = "100" || d = "133" || d = "66" -> add Sdr
        | 4 | 5 -> (
          match List.assoc_opt (int_of_string d) anchos_de_banda with
          | Some (g, v) when String.length d = 5 || g = Ddr -> add ~velocidad:v g
          | _ -> ())
        | _ -> ())
      | [ "pc" ] -> (
        match if i + 1 < n then trozos ws.(i + 1) else [] with
        | [ d ] when String.length d = 1 -> Option.iter add (gen_de_cifra d)
        | _ -> ())
      | _ -> ())
    ws;
  List.rev !out

(* --- velocidad ---------------------------------------------------------------------- *)

let unidades_velocidad = [ "mhz"; "mts"; "mt"; "hz"; "mhzs"; "mtps"; "er"; "mhz"; "mt s" ]

(* Las letras de grado de JEDEC detrás de la velocidad: 2133P, 2400T, 2666V, 2933Y, 3200AA, 4800B. *)
let grados = [ "p"; "r"; "t"; "u"; "v"; "w"; "y"; "aa"; "a"; "b"; "an"; "ab"; "ac"; "bb" ]

let cpu_palabras = [ "ryzen"; "r3"; "r5"; "r7"; "r9"; "i3"; "i5"; "i7"; "i9"; "xeon"; "core"; "athlon"; "epyc"; "threadripper"; "celeron"; "pentium" ]
let no_velocidad_detras = [ "gb"; "mb"; "w"; "eur"; "euro"; "euros"; "e"; "vb"; "mah"; "rpm"; "p"; "x"; "tb"; "kb" ]
let precio_palabras = [ "precio"; "preis"; "price"; "prezzo"; "preco"; "festpreis"; "eur"; "euro"; "euros"; "vb" ]

(** Las velocidades (MT/s) que dice el texto, en orden. [contexto]: si el
    texto habla de memoria (para leer un número suelto como velocidad). *)
let velocidades_dichas ?(contexto = false) ws gens =
  let n = Array.length ws in
  let out = ref [] in
  let add i v = out := (v, i) :: !out in
  let tras_gen i v = List.exists (fun m -> (m.en = i - 1 || (m.en = i - 2 && String.length ws.(i - 1) <= 2)) && List.mem v (velocidades m.gen)) gens in
  (* Detrás de «PC2», «PC3» o «PC», el ancho de banda (PC3-12800, PC2-6400);
     detrás de «PC4» y «PC5», los MT/s (PC4-3200AA), o el ancho de banda si
     tiene cinco cifras (PC4-25600). *)
  let tras_pc i = i > 0 && (match trozos ws.(i - 1) with "pc" :: _ -> true | _ -> false) in
  let tras_pc_mts i = i > 0 && (match trozos ws.(i - 1) with [ "pc"; ("4" | "5") ] -> true | _ -> false) in
  let ancho i d = String.length d = 5 || (tras_pc i && not (tras_pc_mts i)) in
  let por_ancho i v = match List.assoc_opt v anchos_de_banda with Some (_, mt) -> add i mt | None -> () in
  Array.iteri
    (fun i w ->
      match trozos w with
      | [ d ] when es_numero d -> (
        match int_of_string_opt d with
        | Some v when ancho i d && List.mem_assoc v anchos_de_banda && (tras_pc i || contexto) -> por_ancho i v
        | Some v when List.mem v todas_las_velocidades ->
          let detras = if i + 1 < n then ws.(i + 1) else "" in
          let antes = if i > 0 then ws.(i - 1) else "" in
          let antes2 = if i > 1 then ws.(i - 2) else "" in
          if List.mem detras [ "mhz"; "mts"; "mt"; "hz" ] || tras_gen i v || (tras_pc i && (v >= 1600 || not (tras_pc_mts i))) then add i v
          else if
            contexto && v >= 1333
            && (not (List.mem detras no_velocidad_detras))
            && (not (List.mem antes cpu_palabras || List.mem antes2 cpu_palabras))
            && not (List.mem antes precio_palabras || List.mem detras precio_palabras)
          then add i v
        | _ -> ())
      | d :: suf :: resto when es_numero d -> (
        match int_of_string_opt d with
        | Some v when String.length suf = 1 && ancho i d && List.mem_assoc v anchos_de_banda ->
          (* 10600R, 12800E, PC2-5300F, PC2-3200U: el ancho de banda con la letra del formato. *)
          por_ancho i v
        | Some v when List.mem v todas_las_velocidades && (List.mem suf unidades_velocidad || List.mem suf grados) -> add i v
        | Some v when List.mem v todas_las_velocidades && suf = "c" && (match resto with c :: _ -> es_numero c | [] -> false) -> add i v
        | _ -> ())
      | _ -> ())
    ws;
  List.rev !out @ List.filter_map (fun m -> Option.map (fun v -> (v, m.en)) m.velocidad) gens

(* --- formato -------------------------------------------------------------------------- *)

let letra_formato = function
  | 'r' | 'p' -> Some Rdimm | 'l' -> Some Lrdimm | 'u' -> Some Udimm | 's' -> Some Sodimm | 'e' -> Some Ecc_udimm | 'f' -> Some Fbdimm
  | _ -> None

(** El formato de la etiqueta JEDEC: la letra tras la velocidad («PC3-10600R»,
    «PC2-5300F») o la primera del código de placa («PC4-2400T-RB1»,
    «3200AA-SA2», «PC5-4800B-RE0», «2133P-LDO»). *)
let formato_de_etiqueta ws =
  let n = Array.length ws in
  let es_grado w = match trozos w with [ d; g ] when es_numero d && List.mem g grados -> int_of_string_opt d |> Option.fold ~none:false ~some:(fun v -> List.mem v todas_las_velocidades) | _ -> false in
  (* «RB2», «SA2», «LD2», «R»; no «PC4» ni «DDR4» (otra etiqueta detrás: «3200AA PC4-25600»). *)
  let codigo w =
    String.length w >= 1 && String.length w <= 4 && es_letra w.[0] && (String.length w = 1 || es_letra w.[1] || es_cifra w.[1])
    && not (empieza w "pc" || empieza w "ddr")
  in
  let rec busca i =
    if i >= n then None
    else
      let w = ws.(i) in
      let r =
        match trozos w with
        | [ d; l ] | [ "pc"; d; l ]
          when es_numero d && String.length l = 1 && List.mem_assoc (int_of_string d) anchos_de_banda && String.length d >= 4 ->
          letra_formato l.[0]
        | [ d ] when es_numero d && i + 2 < n && List.mem ws.(i + 1) grados && codigo ws.(i + 2)
                     && List.mem (int_of_string d) todas_las_velocidades && es_cifra ws.(i + 2).[String.length ws.(i + 2) - 1] ->
          (* «PC4 3200 AA SE1 11» *)
          letra_formato ws.(i + 2).[0]
        | _ when es_grado w && i + 1 < n && codigo ws.(i + 1) ->
          let c = ws.(i + 1) in
          (* «RB2», «SA2», «LD2», «R»: el tipo y la tarjeta; no «rgb», «ram». *)
          if String.length c = 1 || (String.length c <= 4 && (es_cifra c.[String.length c - 1] || c.[String.length c - 1] = 'o')) then letra_formato c.[0]
          else None
        | _ -> None
      in
      match r with Some _ -> r | None -> busca (i + 1)
  in
  busca 0

(** El formato que el texto dice con palabras. *)
let formato_dicho ws =
  let tiene = hay ws in
  let dichos =
    List.filter_map
      (fun (frases, f) -> if tiene frases then Some f else None)
      [ ([ "cudimm"; "cu dimm" ], Cudimm);
        ([ "csodimm"; "cso dimm" ], Csodimm);
        ([ "camm2"; "camm"; "lpcamm2"; "lpcamm"; "lp camm2" ], Camm2);
        ([ "mrdimm"; "mr dimm" ], Mrdimm);
        ([ "fbdimm"; "fb dimm"; "fully buffered" ], Fbdimm);
        ([ "lrdimm"; "lr dimm"; "load reduced"; "lrdimms" ], Lrdimm);
        ([ "3ds" ], Rdimm_3ds);
        ([ "rdimm"; "r dimm"; "registered dimm"; "reg dimm"; "rdimms" ], Rdimm);
        ([ "sodimm"; "so dimm"; "sodim"; "so dim"; "sodimms"; "so dimms"; "s0dimm" ], Sodimm);
        ([ "udimm"; "u dimm"; "udimms"; "unbuffered dimm" ], Udimm) ]
  in
  let tres_d = Array.exists (fun w -> match trozos w with [ _; "s"; _; "rx"; _ ] -> true | _ -> false) ws in
  (* «L/RDIMM»: los dos. «3DS RDIMM», «2S2Rx4»: un 3DS. *)
  let dichos = if tiene [ "l rdimm" ] then Lrdimm :: Rdimm :: dichos else dichos in
  let dichos = if tres_d || List.mem Rdimm_3ds dichos then Rdimm_3ds :: List.filter (fun f -> f <> Rdimm && f <> Rdimm_3ds) dichos else dichos in
  (* Varios formatos (una tienda: «RDIMM / LRDIMM / UDIMM ECC»): ninguno. *)
  match List.sort_uniq compare dichos with [ f ] -> Some f | _ -> None

(** Pistas de formato: un portátil es SO-DIMM; un sobremesa, DIMM sin registro. *)
let de_portatil = [ "portatil"; "portatiles"; "laptop"; "notebook"; "portatile"; "notebooks"; "laptops"; "260pin"; "260 pin"; "204pin"; "204 pin"; "262pin"; "262 pin"; "200pin"; "mac mini"; "imac"; "nuc"; "mini pc" ]
let de_sobremesa = [ "desktop"; "sobremesa"; "torre"; "computer"; "288pin"; "288 pin"; "240pin"; "240 pin"; "dimm"; "per computer"; "para pc"; "fur pc"; "pc ram"; "desktop pc" ]

(* --- ECC y registro ------------------------------------------------------------------------ *)

let negaciones = [ "non"; "no"; "sin"; "ohne"; "kein"; "keine"; "without"; "senza"; "sem"; "nicht"; "not" ]

(** ¿ECC? «non-ECC», «sin ECC», «ohne ECC» es que no; «DDR4ECC» también cuenta. *)
let ecc ws =
  let n = Array.length ws in
  (* Cada «ECC», afirmado o negado («non-ECC», «sin ECC», «nonecc»); el
     «on-die ECC» de DDR5 no cuenta: no es ECC de módulo. *)
  let dichos =
    List.filter_map
      (fun i ->
        let w = ws.(i) in
        let negado = List.exists (fun d -> i - d >= 0 && List.mem ws.(i - d) negaciones) [ 1; 2 ] in
        (* «ECC: Nein», «ECC: No», «ECC: No disponible»: la negación detrás (no «ECC no registrada»: es ECC). *)
        let sig_ k = if i + k < n then ws.(i + k) else "" in
        let negado =
          negado
          || List.mem (sig_ 1) [ "nein"; "nao"; "kein"; "keine" ]
          || (sig_ 1 = "no" && not (List.mem (sig_ 2) [ "reg"; "registrada"; "registrado"; "registradas"; "registrados"; "registered"; "buffered"; "bufferizada" ]))
        in
        let on_die = i >= 2 && ws.(i - 2) = "on" && ws.(i - 1) = "die" in
        if w = "nonecc" || w = "noecc" then Some false
        else if on_die then None
        else if w = "ecc" || (List.mem "ecc" (trozos w) && not (empieza w "non")) then Some (not negado)
        else None)
      (List.init n Fun.id)
  in
  (* Las dos cosas (las etiquetas de una tienda: «ECC, non-ECC»): no se sabe. *)
  match List.sort_uniq compare dichos with [ b ] -> Some b | _ -> None

let registrada_si =
  [ "reg"; "registered"; "registrada"; "registrado"; "registradas"; "registrados"; "registriert"; "registrierte"; "registrad"; "registerd";
    "registada"; "registadas"; "registrata"; "registrate"; "registrati"; "buffered"; "regist" ]

let registrada_no =
  [ "unbuffered"; "ungepuffert"; "unbuffer"; "non reg"; "nonreg"; "unregistered"; "unregistriert"; "unreg"; "non registered";
    "non registrada"; "no registrada"; "unregistrierte" ]

let registrada ws = if hay ws registrada_no then Some false else if hay ws registrada_si then Some true else None

(* --- rangos, CAS y voltaje ---------------------------------------------------------------------- *)

(** Rangos y anchura: «2Rx4», «2R×8», «1Rx16», «4DRx4», «2S2Rx4», «dual rank». *)
let rangos ws =
  let de_palabra w =
    match trozos w with
    | [ r; ("rx" | "drx" | "r"); a ] when es_numero r && es_numero a -> Some (int_of_string_opt r, int_of_string_opt a)
    | [ s; "s"; r; "rx"; a ] when es_numero s && es_numero r && es_numero a ->
      Some (Option.map (fun x -> x * int_of_string s) (int_of_string_opt r), int_of_string_opt a)
    | _ -> None
  in
  let ok (r, a) = (match r with Some r -> r >= 1 && r <= 8 | None -> true) && match a with Some a -> List.mem a [ 4; 8; 16 ] | None -> true in
  match List.find_map (fun w -> match de_palabra w with Some x when ok x -> Some x | _ -> None) (Array.to_list ws) with
  | Some x -> x
  | None ->
    if hay ws [ "dual rank"; "dualrank"; "dual ranked"; "doble rango" ] then (Some 2, None)
    else if hay ws [ "single rank"; "singlerank"; "single ranked" ] then (Some 1, None)
    else if hay ws [ "quad rank"; "quadrank" ] then (Some 4, None)
    else (None, None)

(** La latencia CAS: «CL16», «CL 16», «CAS 22», «C30», «16-18-18-38». *)
let cas ws =
  let n = Array.length ws in
  let valido c = c >= 4 && c <= 60 in
  let rec busca i =
    if i >= n then None
    else
      let r =
        match trozos ws.(i) with
        | [ ("cl" | "cas" | "c"); c ] when es_numero c -> Option.bind (int_of_string_opt c) (fun c -> if valido c then Some c else None)
        | [ ("cl" | "cas") ] when i + 1 < n && es_numero ws.(i + 1) -> Option.bind (num ws.(i + 1)) (fun c -> if valido c then Some c else None)
        | [ d; "c"; c ] when es_numero d && es_numero c && List.mem (int_of_string d) todas_las_velocidades ->
          Option.bind (int_of_string_opt c) (fun c -> if valido c then Some c else None)
        | [ c ] when es_numero c && String.length c = 2 && i + 3 < n && List.for_all (fun k -> es_numero ws.(i + k) && String.length ws.(i + k) = 2) [ 1; 2; 3 ] ->
          Option.bind (int_of_string_opt c) (fun c -> if valido c then Some c else None)
        | _ -> None
      in
      match r with Some _ -> r | None -> busca (i + 1)
  in
  busca 0

(** El voltaje: «1.2V», «1,35 V», «1,2Volt»; DDR3L y PC3L son 1,35. *)
let voltaje texto gens =
  let s = String.lowercase_ascii texto in
  let n = String.length s in
  let validos = [ 1.1; 1.2; 1.25; 1.35; 1.4; 1.45; 1.5; 1.55; 1.6; 1.65; 1.8; 2.5 ] in
  let r = ref None in
  for i = 0 to n - 3 do
    if !r = None && es_cifra s.[i] && (i = 0 || not (es_cifra s.[i - 1] || s.[i - 1] = '.' || s.[i - 1] = ',')) && (s.[i + 1] = '.' || s.[i + 1] = ',') && es_cifra s.[i + 2] then begin
      let j = ref (i + 2) in
      while !j < n && es_cifra s.[!j] do incr j done;
      let k = if !j < n && s.[!j] = ' ' then !j + 1 else !j in
      if k < n && s.[k] = 'v' && (k + 1 >= n || not (es_letra s.[k + 1]) || (k + 3 < n && String.sub s k 4 = "volt")) then
        match float_of_string_opt (String.sub s i 1 ^ "." ^ String.sub s (i + 2) (!j - i - 2)) with
        | Some v when List.mem v validos -> r := Some v
        | _ -> ()
    end
  done;
  match !r with Some v -> Some v | None -> if List.exists (fun m -> m.baja) gens then Some 1.35 else None

(* --- capacidades ---------------------------------------------------------------------------------- *)

let unidades_gb = [ "gb"; "g"; "gib"; "gig"; "giga"; "gigas"; "gbyte"; "gbytes"; "gigabyte"; "gigabytes"; "gbs" ]
let unidades_mb = [ "mb"; "mib"; "mbyte"; "mbytes"; "megas" ]

(* Lo que, detrás de una cantidad, dice que no es memoria: un disco, la VRAM de una gráfica. *)
let de_disco =
  [ "ssd"; "hdd"; "nvme"; "emmc"; "sata"; "flash"; "vram"; "gddr5"; "gddr6"; "gddr6x"; "gddr5x"; "gddr7"; "speicherplatz"; "festplatte";
    "disco"; "sd"; "microsd"; "usb"; "almacenamiento"; "rom"; "storage"; "ssds"; "m2"; "hd"; "sas"; "nas" ]

let tras_numero = [ "cada"; "each"; "jeweils"; "je"; "pro"; "cada una"; "cada uno"; "ciascuna"; "ciascuno"; "por modulo" ]
let totales = [ "total"; "gesamt"; "insgesamt"; "totales"; "totale"; "zusammen"; "in total" ]

let nombres_de_unidad =
  [ "modulos"; "modulo"; "moduli"; "modul"; "module"; "modules"; "memorias"; "memoria"; "riegel"; "stuck"; "stk"; "unidades"; "uds";
    "ud"; "units"; "unit"; "pcs"; "piezas"; "banchi"; "schede"; "sticks"; "stick"; "dimms"; "rams"; "ram"; "arbeitsspeicher";
    "ramriegel"; "speicherriegel"; "pezzi"; "pz"; "unita"; "unidade"; "memorie"; "x"; "modulen"; "memory" ]

let sueltas = [ "verfugbar"; "vorhanden"; "disponibles"; "disponible"; "available"; "stock"; "lager"; "in stock"; "en stock"; "auf lager" ]

type cantidad = { mb : int; en : int; total : bool; cada : bool }
type producto = { n : int; c : int; en_p : int }

type cuenta = {
  modulos : int option;
  capacidad : int option;  (** MB por módulo. *)
  total_mb : int option;
  iguales : bool option;
  disponibles : int option;
  varias : int list;  (** Capacidades sueltas que no casan: varias ofertas en un anuncio. *)
  kit : bool;  (** Dice kit, dual, pareja… *)
}

(** Las capacidades de un módulo (MB): lo demás («12GB», «20GB», «6GB») es el total de varios. *)
let estandar mb = List.mem mb [ 32; 64; 128; 256; 512; 1024; 2048; 4096; 8192; 16384; 24576; 32768; 49152; 65536; 98304; 131072; 196608; 262144 ]

let a_mb unidad c = if List.mem unidad unidades_mb then Some c else if List.mem unidad unidades_gb then Some (gb c) else if unidad = "tb" then Some (gb (c * 1024)) else None

let leer_tokens ws =
  let n = Array.length ws in
  let cantidades = ref [] and productos = ref [] and cuentas = ref [] and disponibles = ref None in
  let marcada_total i = (i > 0 && List.mem ws.(i - 1) [ "insgesamt"; "total"; "gesamt" ]) || (i + 1 < n && List.mem ws.(i + 1) totales) in
  let es_disco i = (i + 1 < n && List.mem ws.(i + 1) de_disco) || (i + 2 < n && List.mem ws.(i + 2) [ "ssd"; "hdd"; "nvme" ]) || (i > 0 && List.mem ws.(i - 1) [ "ssd"; "hdd"; "nvme"; "vram" ]) in
  let ram_cerca i = List.exists (fun k -> k < n && List.mem ws.(k) [ "ram"; "arbeitsspeicher"; "memoria"; "speicher"; "ddr4"; "ddr3"; "ddr5" ]) [ i + 1; i + 2; i + 3 ] in
  let cantidad ?(total = false) ?(cada = false) i mb = if mb >= 32 && mb <= gb 4096 then cantidades := { mb; en = i; total = total || marcada_total i; cada } :: !cantidades in
  (* [c] negativo: sin unidad («2x512», «(16x4)»), se decide luego. *)
  let producto i n c = if n >= 1 && n <= 128 && c <> 0 then productos := { n; c; en_p = i } :: !productos in
  let codigo w = match trozos w with [ l; d ] -> String.length l <= 3 && es_letra l.[0] && es_numero d && String.length d <= 2 | _ -> false in
  let cuenta i k =
    (* «4 Stück verfügbar», «bis zu 4 Stück»: unidades sueltas, no un lote.
       No cuenta el «4» de «DDR 4» ni el «11» de «PC4-3200AA-SA2-11». *)
    let sigue = List.filter_map (fun d -> if i + d < n then Some ws.(i + d) else None) [ 1; 2; 3 ] in
    let antes = if i > 1 then ws.(i - 2) ^ " " ^ ws.(i - 1) else "" in
    let previa = if i > 0 then ws.(i - 1) else "" in
    if List.mem previa [ "ddr"; "pc" ] || codigo previa || (i > 0 && List.mem previa grados) then ()
    else if List.exists (fun w -> List.mem w sueltas) sigue || List.mem antes [ "bis zu"; "hasta"; "up to" ] then disponibles := Some k
    else if k >= 1 && k <= 128 then cuentas := (k, i) :: !cuentas
  in
  for i = 0 to n - 1 do
    let w = ws.(i) in
    let sig_ = if i + 1 < n then ws.(i + 1) else "" in
    let sig2 = if i + 2 < n then ws.(i + 2) else "" in
    match trozos w with
    (* 2x16gb, 4x16g, 2x16 gb, 2x512, 16x4 *)
    | [ a; "x"; b; u ] when es_numero a && es_numero b -> (
      match (num a, num b, a_mb u 1) with
      | Some a, Some b, Some _ -> producto i a (Option.get (a_mb u b))
      | _ -> ())
    | [ a; "x"; b ] when es_numero a && es_numero b -> (
      match (num a, num b) with
      | Some a, Some b when b <= 1024 -> (
        match a_mb sig_ b with Some mb -> producto i a mb | None -> producto i a (-b) (* sin unidad: se decide luego *))
      | _ -> ())
    (* 16gbx2, 8gbx2 *)
    (* No «2Gx4», «4Gx8», «8Gx16»: la organización de los chips. *)
    | [ c; u; k ] when es_numero c && es_numero k && String.length u > 1 && u.[String.length u - 1] = 'x' && not (u = "gx" && List.mem k [ "4"; "8"; "16" ]) -> (
      match (num c, num k, a_mb (String.sub u 0 (String.length u - 1)) 1) with
      | Some c, Some k, Some _ -> producto i k (Option.get (a_mb (String.sub u 0 (String.length u - 1)) c))
      | _ -> ())
    (* 2.5GB, 1,5 TB: con la coma decimal («d») *)
    | [ a; "d"; b; u ] when es_numero a && es_numero b && String.length b <= 2 && (List.mem u unidades_gb || u = "tb") ->
      let mb = (int_of_string a * 1024) + (int_of_string b * 1024 / if String.length b = 1 then 10 else 100) in
      cantidad i (if u = "tb" then mb * 1024 else mb)
    | [ a; "d"; b ] when es_numero a && es_numero b && String.length b <= 2 && List.mem sig_ unidades_gb ->
      cantidad i ((int_of_string a * 1024) + (int_of_string b * 1024 / if String.length b = 1 then 10 else 100))
    (* 16gb, 512mb, 1tb; «16gb x 2», «16gb (x2)» *)
    | [ c; u ] when es_numero c && (List.mem u unidades_gb || List.mem u unidades_mb || u = "tb") -> (
      match num c with
      | Some c when not (es_disco i) ->
        let mb = Option.get (a_mb u c) in
        if u = "tb" && not (ram_cerca i) then ()
        else if sig_ = "x2" || sig_ = "x4" || sig_ = "x3" || sig_ = "x8" then producto i (int_of_string (String.sub sig_ 1 1)) mb
        else if sig_ = "x" && num sig2 <> None then producto i (Option.get (num sig2)) mb
        else cantidad i mb ~cada:(List.mem sig_ tras_numero || (i > 0 && List.mem ws.(i - 1) [ "je"; "jeweils"; "cada"; "each" ]))
      | _ -> ())
    (* 2x, 10x, 10xhynix: cuántos *)
    | [ a; x ] when es_numero a && x <> "" && x.[0] = 'x' && (x = "x" || String.length x > 2) -> (
      match (num a, trozos sig_) with
      | Some k, [ c; u ] when x = "x" && es_numero c && (List.mem u unidades_gb || List.mem u unidades_mb) ->
        producto i k (Option.get (a_mb u (int_of_string c)))
      | Some k, [ c ] when x = "x" && es_numero c && List.mem sig2 unidades_gb -> producto i k (gb (int_of_string c))
      | Some k, [ c ] when x = "x" && es_numero c -> producto i k (- int_of_string c)
      | Some k, _ -> cuenta i k
      | None, _ -> ())
    | [ x; k ] when x = "x" && es_numero k -> (match num k with Some k when k <= 64 -> cuenta i k | _ -> ())
    | [ a ] when es_numero a -> (
      match num a with
      | Some k ->
        let tr = trozos sig_ in
        if sig_ = "x" then (
          (* «2 x 16GB», «2 x 16 GB», «1 x Memoria» *)
          match trozos sig2 with
          | [ c; u ] when es_numero c && (List.mem u unidades_gb || List.mem u unidades_mb) -> producto i k (Option.get (a_mb u (int_of_string c)))
          | [ c ] when es_numero c && i + 3 < n && List.mem ws.(i + 3) unidades_gb -> producto i k (gb (int_of_string c))
          | _ -> cuenta i k)
        else if List.mem sig_ unidades_gb || List.mem sig_ unidades_mb || sig_ = "tb" then (
          if not (es_disco (i + 1)) then
            let mb = Option.get (a_mb sig_ k) in
            if sig_ = "tb" && not (ram_cerca (i + 1)) then () else cantidad i mb ~cada:(List.mem sig2 tras_numero || (i > 0 && List.mem ws.(i - 1) [ "je"; "jeweils"; "cada"; "each" ])))
        else if k >= 2 && k <= 16 && (match tr with [ c; u ] -> es_numero c && List.mem u unidades_gb | _ -> false)
                && not (i > 0 && List.mem ws.(i - 1) (cpu_palabras @ [ "ddr"; "pc"; "gen"; "ultra"; "core"; "serie"; "series"; "v"; "x"; "gb"; "aegis"; "viper"; "pi"; "elite"; "vulcan"; "ares" ])) then
          (* «(2 * 32GB)»: el asterisco se ha ido al plegar. *)
          producto i k (gb (int_of_string (List.hd tr)))
        else if List.mem sig_ tras_numero && k <= 512 && i > 0 then cantidad i (gb k) ~cada:true
        else if List.mem sig_ nombres_de_unidad || (match tr with ("ddr" | "pc") :: _ -> k <= 64 | _ -> false) then cuenta i k
        else if List.mem sig_ [ "kits"; "sets"; "packs" ] then cuentas := (-k, i) :: !cuentas
        else if List.mem sig_ sueltas then disponibles := Some k
      | None -> ())
    | _ -> ()
  done;
  (List.rev !cantidades, List.rev !productos, List.rev !cuentas, !disponibles)

(** Cuántos módulos, de cuánto y cuánto en total; con [gen] y [servidor] para
    saber si una capacidad es de un módulo o de un kit (no hay DDR4 UDIMM de
    64 GB: «64GB DDR4 3200» es un kit). *)
let contar ?gen ?formato ?(servidor = false) ?(consumo = false) ws =
  let cantidades, productos, cuentas, disponibles = leer_tokens ws in
  let maximo = match gen with Some g -> capacidad_maxima ?formato ~consumo g servidor | None -> if servidor then gb 128 else gb 48 in
  (* Lo más grande que puede ser un módulo, sea lo que sea. *)
  let tope = match gen with Some g -> capacidad_maxima ?formato g true | None -> gb 256 in
  let kit_palabras = hay ws [ "kit"; "dual kit"; "dual channel"; "coppia"; "pareja"; "par"; "pair"; "2er set"; "2er kit"; "set"; "paar"; "dualkit"; "doppelpack" ] in
  (* «dual» suelto no: «Dual Rank» es un módulo de dos rangos, no un kit de dos. *)
  let dual = hay ws [ "dual kit"; "dual channel"; "coppia"; "pareja"; "pair"; "2er set"; "2er kit"; "dualkit"; "paar"; "doppelpack" ] in
  let multiplicador = match List.find_opt (fun (k, _) -> k < 0) cuentas with Some (k, _) -> -k | None -> 1 in
  let cuentas = List.filter (fun (k, _) -> k > 0) cuentas in
  let valores = List.sort_uniq compare (List.map (fun c -> c.mb) (List.filter (fun c -> not c.total) cantidades)) in
  let totales_mb = List.sort_uniq compare (List.map (fun c -> c.mb) (List.filter (fun c -> c.total) cantidades)) in
  let cada = List.find_map (fun c -> if c.cada then Some c.mb else None) cantidades in
  let vacia = { modulos = None; capacidad = None; total_mb = None; iguales = None; disponibles; varias = []; kit = kit_palabras } in
  (* Los productos sin unidad («2x512», «16x4»): la que casa con las cantidades. *)
  let productos =
    List.filter_map
      (fun p ->
        if p.c > 0 then Some p
        else
          let c = -p.c in
          let en_gb = gb c and en_mb = c in
          let casa t = List.exists (fun x -> x = t) (valores @ totales_mb) in
          (* «(16x4)» junto a «16GB»: cuatro de 16, no dieciséis de 4. *)
          if List.mem en_gb valores then Some { p with c = en_gb }
          else if List.mem (gb p.n) valores && c <= 16 then Some { n = c; c = gb p.n; en_p = p.en_p }
          (* «32GB (16x2)»: dos de 16, no dieciséis de 2. *)
          else if c <= 2 && p.n > c && casa (c * gb p.n) then Some { n = c; c = gb p.n; en_p = p.en_p }
          else if casa (p.n * en_gb) then Some { p with c = en_gb }
          else if casa (p.n * en_mb) then Some { p with c = en_mb }
          else if c >= 128 then Some { p with c = en_mb }
          else if c <= 256 then Some { p with c = en_gb }
          else None)
      productos
  in
  let productos = List.sort_uniq (fun a b -> compare (a.n, a.c) (b.n, b.c)) productos in
  let valida mb = mb >= 64 && mb <= maximo in
  match productos with
  | _ :: _ ->
    let modulos = multiplicador * List.fold_left (fun a p -> a + p.n) 0 productos in
    let caps = List.sort_uniq compare (List.map (fun p -> p.c) productos) in
    let total = multiplicador * List.fold_left (fun a p -> a + (p.n * p.c)) 0 productos in
    (match caps with
     | [ c ] -> { vacia with modulos = Some modulos; capacidad = Some c; total_mb = Some total; iguales = Some true }
     | _ -> { vacia with modulos = Some modulos; total_mb = Some total; iguales = Some false })
  | [] -> (
    let total_dicho = match totales_mb with [ t ] -> Some t | _ -> None in
    match (cuentas, valores) with
    | (k, en_k) :: _, _ -> (
      let k = k * multiplicador in
      (* «32GB (2 módulos)»: la cuenta detrás de la capacidad dice en cuántos va. *)
      let detras c = List.exists (fun x -> x.mb = c && x.en < en_k) cantidades in
      match (cada, valores) with
      | Some c, _ -> { vacia with modulos = Some k; capacidad = Some c; total_mb = Some (k * c); iguales = Some true }
      | None, [ c ] ->
        if (c > maximo || total_dicho = Some c || detras c) && c mod k = 0 && valida (c / k) then
          { vacia with modulos = Some k; capacidad = Some (c / k); total_mb = Some c; iguales = Some true }
        else if total_dicho <> None && Option.get total_dicho = k * c then { vacia with modulos = Some k; capacidad = Some c; total_mb = total_dicho; iguales = Some true }
        (* «6x RAM DDR1 2.5GB»: más que ningún módulo y sin repartir a partes iguales: un lote mezclado. *)
        else if c > tope || not (estandar c) then { vacia with modulos = Some k; total_mb = Some c; iguales = Some false }
        else { vacia with modulos = Some k; capacidad = Some c; total_mb = Some (k * c); iguales = Some true }
      | None, [ a; b ] when b = k * a -> { vacia with modulos = Some k; capacidad = Some a; total_mb = Some b; iguales = Some true }
      | None, [] -> (
        match total_dicho with
        | Some t when t mod k = 0 -> { vacia with modulos = Some k; capacidad = Some (t / k); total_mb = Some t; iguales = Some true }
        | _ -> { vacia with modulos = Some k })
      | None, _ ->
        (* Varias capacidades en un lote: mezclado. *)
        { vacia with modulos = Some k; iguales = Some false; total_mb = total_dicho })
    | [], [] -> (
      match total_dicho with
      | Some t -> { vacia with total_mb = Some t; modulos = (if dual then Some 2 else None); capacidad = (if dual && t mod 2 = 0 then Some (t / 2) else None) }
      | None -> vacia)
    | [], [ c ] -> (
      match (cada, total_dicho) with
      | Some e, _ when e < c && c mod e = 0 -> { vacia with modulos = Some (c / e); capacidad = Some e; total_mb = Some c; iguales = Some true }
      | _, Some t when t > c && t mod c = 0 -> { vacia with modulos = Some (t / c); capacidad = Some c; total_mb = Some t; iguales = Some true }
      | _ ->
        if dual && c mod 2 = 0 then { vacia with modulos = Some 2; capacidad = Some (c / 2); total_mb = Some c; iguales = Some true }
        else if c > maximo || (not (estandar c)) || hay ws [ "kit"; "set"; "dualkit"; "kit ram" ] then { vacia with total_mb = Some c }
        (* Un módulo, salvo que diga cuántos: lo decide quien lee. *)
        else { vacia with capacidad = Some c })
    | [], [ a; b ] when b mod a = 0 && b / a >= 2 && b / a <= 16 ->
      { vacia with modulos = Some (b / a); capacidad = Some a; total_mb = Some b; iguales = Some true }
    | [], vs -> { vacia with varias = vs })
