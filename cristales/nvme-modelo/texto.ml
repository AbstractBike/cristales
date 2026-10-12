(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Leer qué SSD nombra un texto: «WD_BLACK SN850X 2TB», «wd black sn 850 x»,
   «Samsung PM9A3 7,68TB U.2», «Micron/HP 7450 MAX U.3 6,4TB». Lo difícil es
   no confundir: 7300 MB/s es una velocidad, no una Micron 7300; 16GB RAM es
   la memoria de un PC, no un disco; 600TBW, la resistencia. El plegado y las
   listas de palabras son los de grafica-modelo (Grafica_modelo.Texto). *)

module G = Grafica_modelo.Texto

(* --- plegado y piezas --------------------------------------------------- *)

(** Minúsculas ASCII sin tildes; lo que no es letra ni cifra, espacio. A
    diferencia de grafica-modelo, el «+» no se lee como «plus»: «970 EVO +
    caja» no es una 970 EVO Plus. *)
let pliega s =
  let s = List.fold_left (fun acc (a, b) -> G.reemplaza_todo a b acc) s G.tildes in
  String.map (fun c -> match c with 'A' .. 'Z' -> Char.lowercase_ascii c | 'a' .. 'z' | '0' .. '9' -> c | _ -> ' ') s

type pieza = G.pieza = { t : string; cifras : bool; pegada : bool; palabra : int }

let piezas texto =
  let palabras = List.filter (( <> ) "") (String.split_on_char ' ' (pliega texto)) in
  List.concat
    (List.mapi
       (fun w palabra ->
         let n = String.length palabra in
         let rec trozos i acc =
           if i >= n then List.rev acc
           else
             let cifras = G.es_cifra palabra.[i] in
             let j = ref i in
             while !j < n && G.es_cifra palabra.[!j] = cifras do incr j done;
             trozos !j ({ t = String.sub palabra i (!j - i); cifras; pegada = i > 0; palabra = w } :: acc)
         in
         trozos 0 [])
       palabras)

(** «sn 850x» -> [sn; 850; x]: las piezas de un alias, sin palabras. *)
let piezas_de alias = List.map (fun p -> p.t) (piezas alias)

(* --- capacidades -------------------------------------------------------- *)

let es_digito c = c >= '0' && c <= '9'
let es_letra c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')

(* Lo que, detrás de una cantidad en GB, dice que es memoria de un PC. *)
let de_memoria = [ "ram"; "ddr"; "ddr3"; "ddr4"; "ddr5"; "lpddr4"; "lpddr5"; "vram"; "gddr6"; "gddr6x"; "memoria"; "arbeitsspeicher"; "dimm"; "sodimm" ]

let palabra_desde s i =
  let n = String.length s in
  let i = ref i in
  while !i < n && not (es_letra s.[!i] || es_digito s.[!i]) do incr i done;
  let j = ref !i in
  while !j < n && (es_letra s.[!j] || es_digito s.[!j]) do incr j done;
  String.lowercase_ascii (String.sub s !i (!j - !i))

let palabra_antes s i =
  let i = ref (i - 1) in
  while !i >= 0 && not (es_letra s.[!i] || es_digito s.[!i]) do decr i done;
  let j = ref !i in
  while !j >= 0 && (es_letra s.[!j] || es_digito s.[!j]) do decr j done;
  String.lowercase_ascii (String.sub s (!j + 1) (!i - !j))

(** Las capacidades que dice el texto, en GB y en orden: «2TB», «2 TB», «1,92 TB»,
    «7.68TB», «2000GB», «2048 GB», «2.000 GB», «2T». No cuenta la memoria («16GB
    RAM»), la resistencia («600TBW») ni lo menor de 100 GB. *)
let capacidades texto =
  let s = String.lowercase_ascii texto in
  let n = String.length s in
  let out = ref [] in
  let i = ref 0 in
  while !i < n do
    if es_digito s.[!i] && (!i = 0 || not (es_letra s.[!i - 1] || es_digito s.[!i - 1] || s.[!i - 1] = '.' || s.[!i - 1] = ',')) then begin
      let ini = !i in
      let j = ref !i in
      while !j < n && es_digito s.[!j] do incr j done;
      let entera = String.sub s ini (!j - ini) in
      let frac =
        if !j + 1 < n && (s.[!j] = '.' || s.[!j] = ',') && es_digito s.[!j + 1] then begin
          let k = ref (!j + 1) in
          while !k < n && es_digito s.[!k] do incr k done;
          let f = String.sub s (!j + 1) (!k - !j - 1) in
          j := !k;
          f
        end
        else ""
      in
      let k = ref !j in
      if !k < n && s.[!k] = ' ' then incr k;
      let unidad, fin =
        if !k + 1 < n && s.[!k] = 't' && s.[!k + 1] = 'b' then ("tb", !k + 2)
        else if !k + 1 < n && s.[!k] = 'g' && s.[!k + 1] = 'b' then ("gb", !k + 2)
        else if !k < n && s.[!k] = 't' then ("t", !k + 1)
        else ("", !k)
      in
      let sigue_letra = fin < n && es_letra s.[fin] in
      (if unidad <> "" && (not sigue_letra) && String.length entera <= 5 then
         let a = int_of_string entera in
         let gb =
           match unidad with
           | "gb" -> if String.length frac = 3 then (a * 1000) + int_of_string frac else a
           | _ ->
             let f = if frac = "" then 0 else int_of_string (String.sub (frac ^ "000") 0 3) in
             (a * 1000) + f
         in
         let despues = palabra_desde s fin and antes = palabra_antes s ini in
         let memoria = (List.mem despues de_memoria && gb <= 1000) || (List.mem antes [ "ram"; "ddr4"; "ddr5" ] && gb <= 256) in
         if gb >= 100 && gb <= 122880 && not memoria then out := gb :: !out);
      i := max (ini + 1) fin
    end
    else incr i
  done;
  List.rev !out

(** La capacidad nominal: 1024 GB es 1 TB y 2048 GB, 2 TB; 1920 GB sigue siendo 1,92 TB. *)
let nominal gb =
  if gb < 1000 then gb
  else
    let r = (gb + 500) / 1000 * 1000 in
    if abs (gb - r) * 1000 <= r * 25 then r else gb

(** ¿Son la misma capacidad? A un 5 %: los enterprise de 3,84 TB se anuncian como de 4 TB. *)
let casi a b = abs (a - b) * 100 <= 5 * max a b

(* --- interfaz y formato --------------------------------------------------- *)

type interfaz_leida = { pcie : int option; sata : bool; sas : bool; nvme : bool }

let interfaz texto =
  let ps = Array.of_list (piezas texto) in
  let n = Array.length ps in
  let pcie = ref None in
  for i = 0 to n - 1 do
    let p = ps.(i) in
    if (not p.cifras) && List.mem p.t [ "pcie"; "gen"; "pci" ] && !pcie = None then begin
      let k = ref (i + 1) in
      while !k < n && (not ps.(!k).cifras) && List.mem ps.(!k).t [ "e"; "express"; "gen" ] do incr k done;
      if !k < n && ps.(!k).cifras && List.mem ps.(!k).t [ "3"; "4"; "5" ] then pcie := Some (int_of_string ps.(!k).t)
    end
  done;
  let hay w = Array.exists (fun p -> (not p.cifras) && p.t = w) ps in
  { pcie = !pcie; sata = hay "sata" || hay "sataiii"; sas = hay "sas"; nvme = hay "nvme" || hay "nvm" || hay "mvme" || hay "nmve" || hay "pcie" }

(** El formato que dice el texto: m2-2280, m2-2230, m2-22110…, «m2» (sin más), u2, u3, e1s, e1l, e3s. *)
let formato texto =
  let ps = Array.of_list (piezas texto) in
  let n = Array.length ps in
  let ultimo_de_su_palabra i = i + 1 >= n || ps.(i + 1).palabra <> ps.(i).palabra in
  let res = ref None and m2 = ref false in
  for i = 0 to n - 1 do
    let p = ps.(i) in
    if !res = None then begin
      if p.cifras && List.mem p.t [ "2230"; "2242"; "2260"; "2280"; "22110" ] then res := Some ("m2-" ^ p.t)
      else if (not p.cifras) && p.t = "u" && (not p.pegada) && i + 1 < n && ps.(i + 1).cifras && List.mem ps.(i + 1).t [ "2"; "3" ]
              && ultimo_de_su_palabra (i + 1) then res := Some ("u" ^ ps.(i + 1).t)
      else if (not p.cifras) && p.t = "e" && (not p.pegada) && i + 2 < n && ps.(i + 1).cifras && List.mem ps.(i + 1).t [ "1"; "3" ]
              && (not ps.(i + 2).cifras) && List.mem ps.(i + 2).t [ "s"; "l" ] then res := Some ("e" ^ ps.(i + 1).t ^ ps.(i + 2).t)
      else if (not p.cifras) && p.t = "m" && i + 1 < n && ps.(i + 1).t = "2" then m2 := true
    end
  done;
  match !res with Some f -> Some f | None -> if !m2 then Some "m2" else None

(* --- modelos ---------------------------------------------------------------- *)

type mencion = { modelos : Catalogo.modelo list; primera : int; largo : int }

(* Lo que, detrás de un número suelto, dice que es una velocidad, una potencia o una capacidad. *)
let unidades = [ "mb"; "mbs"; "mbps"; "gb"; "gbs"; "tb"; "w"; "mhz"; "rpm"; "iops"; "k"; "s" ]

let alias_compilados =
  List.concat_map (fun (x : Catalogo.modelo) -> List.map (fun a -> (Array.of_list (piezas_de a), x)) x.alias) Catalogo.modelos

let palabras_plegadas texto = List.filter (( <> ) "") (String.split_on_char ' ' (pliega texto))

let nombra_marca texto ws = ws = [] || G.contiene texto ws || List.exists (fun w -> List.mem w (palabras_plegadas texto)) ws

(** Las menciones de modelos del catálogo, en orden: la más larga en cada sitio. *)
let menciones texto =
  let ps = Array.of_list (piezas texto) in
  let n = Array.length ps in
  let encaja i a =
    let k = Array.length a in
    i + k <= n
    && (let ok = ref true in
        for j = 0 to k - 1 do if ps.(i + j).t <> a.(j) then ok := false done;
        !ok)
    (* El alias empieza donde empieza una palabra: «CT4000P3PSSD8» no es una P3. *)
    && not ps.(i).pegada
  in
  let suelto_valido i a =
    (* Un alias de un solo número («7450», «980») no es una velocidad ni una capacidad. *)
    Array.length a <> 1 || (not ps.(i).cifras)
    || (i + 1 >= n || not (List.mem ps.(i + 1).t unidades))
       && (i = 0 || not (List.mem ps.(i - 1).t [ "bis"; "hasta"; "up"; "to"; "zu"; "ca" ]))
  in
  let salida = ref [] in
  let i = ref 0 in
  while !i < n do
    let candidatos =
      List.filter (fun (a, (x : Catalogo.modelo)) -> encaja !i a && suelto_valido !i a && nombra_marca texto x.requiere) alias_compilados
    in
    match candidatos with
    | [] -> incr i
    | _ ->
      let largo = List.fold_left (fun m (a, _) -> max m (Array.length a)) 0 candidatos in
      (* En el orden del catálogo: entre PRO y MAX, sin capacidad que decida, el PRO. *)
      let largos = List.filter_map (fun (a, x) -> if Array.length a = largo then Some x else None) candidatos in
      let modelos = List.filter (fun (m : Catalogo.modelo) -> List.memq m largos) Catalogo.modelos in
      salida := { modelos; primera = !i; largo } :: !salida;
      i := !i + largo
  done;
  List.rev !salida

(** Las marcas que nombra el texto, sin repetir. *)
let marcas texto =
  List.sort_uniq compare (List.filter_map (fun (w, m) -> if G.contiene texto [ w ] then Some m else None) Catalogo.marcas)

(* Lo que va detrás de una marca y parece un modelo: letras y cifras juntas («FX991», «NM620», «GM7»). *)
let relleno =
  [ "black"; "blue"; "red"; "green"; "gold"; "platinum"; "ssd"; "nvme"; "m"; "intern"; "interne"; "internal"; "pc"; "dc"; "spatium";
    "exceria"; "legend"; "rocket"; "firecuda"; "opal"; "nitro"; "fury" ]

let desconocidos texto =
  let ws = Array.of_list (palabras_plegadas texto) in
  let n = Array.length ws in
  let es_marca w = List.exists (fun (m, _) -> m = w) Catalogo.marcas in
  let parece_modelo w =
    String.exists G.es_cifra w && String.exists (fun c -> c >= 'a' && c <= 'z') w
    && capacidades w = []
    && not (List.exists (fun p -> String.length w >= String.length p && String.sub w 0 (String.length p) = p) [ "gen"; "pcie"; "x4"; "m2"; "u2"; "u3"; "e1"; "ps5"; "ps4" ])
  in
  let out = ref [] in
  Array.iteri
    (fun i w ->
      if es_marca w && not (i > 0 && es_marca ws.(i - 1)) then begin
        let rec mira k saltos =
          if k < n && saltos <= 2 then
            if parece_modelo ws.(k) then out := (w ^ " " ^ ws.(k)) :: !out
            else if List.mem ws.(k) relleno || es_marca ws.(k) then mira (k + 1) (saltos + 1)
        in
        mira (i + 1) 0
      end)
    ws;
  List.sort_uniq compare !out

(** ¿Habla de un disco de servidor? *)
let enterprise texto =
  G.contiene texto [ "enterprise"; "datacenter"; "data center"; "rechenzentrum"; "server ssd"; "plp"; "power loss"; "power loss protection" ]

(** El índice de palabra (del plegado de aquí) de la primera de [frases] en [texto], si está. *)
let posicion texto frases =
  let ws = Array.of_list (palabras_plegadas texto) in
  let n = Array.length ws in
  let encaja i w =
    let partes = Array.of_list (List.filter (( <> ) "") (String.split_on_char ' ' w)) in
    let k = Array.length partes in
    k > 0 && i + k <= n && Array.for_all Fun.id (Array.init k (fun j -> ws.(i + j) = partes.(j)))
  in
  let rec busca i = if i >= n then None else if List.exists (encaja i) frases then Some i else busca (i + 1) in
  busca 0

(** La palabra donde empieza la primera mención de un modelo del catálogo. *)
let primer_modelo texto =
  let ps = Array.of_list (piezas texto) in
  match menciones texto with m :: _ -> Some ps.(m.primera).palabra | [] -> None
