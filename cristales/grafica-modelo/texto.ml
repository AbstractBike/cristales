(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Leer qué gráficas nombra un texto: «MSI GeForce RTX 3080 Ti Suprim X 12GB»,
   «rx6800xt», «Arc A770 16G», «PC Gaming Ryzen 7 5800X3D + RTX 3080». Lo
   difícil no es encontrar el número sino no confundirlo: 5800X3D, i5 10400F y
   Ryzen 5 5600 son procesadores; 1080p, una resolución; 650W, una fuente;
   2048SP, núcleos; 970 EVO, un disco. *)

(* --- plegado -------------------------------------------------------------- *)

(* Las letras con tilde de UTF-8 más comunes en es/de/en/it/pt, a ASCII. *)
let tildes =
  [ ("á", "a"); ("à", "a"); ("â", "a"); ("ä", "a"); ("ã", "a"); ("Á", "a"); ("À", "a"); ("Â", "a"); ("Ä", "a"); ("Ã", "a");
    ("é", "e"); ("è", "e"); ("ê", "e"); ("ë", "e"); ("É", "e"); ("È", "e"); ("Ê", "e");
    ("í", "i"); ("ì", "i"); ("î", "i"); ("ï", "i"); ("Í", "i");
    ("ó", "o"); ("ò", "o"); ("ô", "o"); ("ö", "o"); ("õ", "o"); ("Ó", "o"); ("Ö", "o"); ("Õ", "o");
    ("ú", "u"); ("ù", "u"); ("û", "u"); ("ü", "u"); ("Ú", "u"); ("Ü", "u");
    ("ñ", "n"); ("Ñ", "n"); ("ç", "c"); ("Ç", "c"); ("ß", "ss");
    ("º", ""); ("ª", ""); ("™", ""); ("®", "") ]

let reemplaza_todo patron por s =
  let lp = String.length patron in
  if lp = 0 then s
  else begin
    let b = Buffer.create (String.length s) in
    let i = ref 0 in
    let n = String.length s in
    while !i < n do
      if !i + lp <= n && String.sub s !i lp = patron then (Buffer.add_string b por; i := !i + lp)
      else (Buffer.add_char b s.[!i]; incr i)
    done;
    Buffer.contents b
  end

(** Minúsculas ASCII, sin tildes; lo que no es letra ni cifra, espacio. *)
let pliega s =
  let s = List.fold_left (fun acc (a, b) -> reemplaza_todo a b acc) s tildes in
  (* El «+» une («RTX 3080 + backplate»): se queda como palabra. *)
  let s = reemplaza_todo "+" " plus " s in
  String.map
    (fun c ->
      match c with
      | 'A' .. 'Z' -> Char.lowercase_ascii c
      | 'a' .. 'z' | '0' .. '9' -> c
      | _ -> ' ')
    s

(* --- piezas --------------------------------------------------------------- *)

(** Un trozo de letras o de cifras. [pegada]: sin separador con la anterior
    («rtx3080»: 3080 va pegada a rtx). [palabra]: el índice de la palabra. *)
type pieza = { t : string; cifras : bool; pegada : bool; palabra : int }

let es_cifra c = c >= '0' && c <= '9'

let piezas texto =
  let palabras = List.filter (( <> ) "") (String.split_on_char ' ' (pliega texto)) in
  List.concat
    (List.mapi
       (fun w palabra ->
         let n = String.length palabra in
         let rec trozos i acc =
           if i >= n then List.rev acc
           else
             let cifras = es_cifra palabra.[i] in
             let j = ref i in
             while !j < n && es_cifra palabra.[!j] = cifras do incr j done;
             trozos !j ({ t = String.sub palabra i (!j - i); cifras; pegada = i > 0; palabra = w } :: acc)
         in
         trozos 0 [])
       palabras)

(* --- menciones ------------------------------------------------------------ *)

type mencion = {
  modelo : Catalogo.modelo option;  (** None: parece una gráfica pero no está en el catálogo. *)
  leido : string;  (** Como se leyó, plegado: «rtx 4060 super». *)
  antigua : bool;  (** De antes del catálogo (Radeon HD, GeForce FX, GTX 580…). *)
  profesional : bool;  (** Quadro, Radeon Pro, FirePro, Tesla, RTX A4000…: no son de juegos. *)
  primera : int;  (** Índice de la primera pieza. *)
  palabra : int;  (** Palabra donde empieza. *)
}

let cpu_palabras =
  [ "ryzen"; "xeon"; "core"; "celeron"; "pentium"; "athlon"; "threadripper"; "epyc"; "ultra"; "apu" ]

(* Sufijos pegados que dicen que el número no es una gráfica. *)
let sufijos_cpu = [ "x3d"; "k"; "kf"; "ks"; "f"; "g"; "ge"; "t"; "hx"; "hs"; "h"; "u"; "x" ]
let sufijos_no = [ "p"; "w"; "hz"; "mhz"; "mm"; "sp"; "mah"; "v"; "cm"; "fps"; "km"; "rpm"; "mb"; "tb" ]

let numeros_rtx = Catalogo.numeros_de Catalogo.Rtx
let numeros_gtx = Catalogo.numeros_de Catalogo.Gtx
let numeros_rx = Catalogo.numeros_de Catalogo.Rx

(* Los de la GTX que se leen sin prefijo: los de cuatro cifras y la serie 900. *)
let gtx_sueltos = List.filter (fun n -> n >= 900) numeros_gtx

let sufijo_de ps i =
  (* Lo que va justo detrás del número [i]: pegado o en las palabras siguientes. *)
  let n = Array.length ps in
  let sig_ k = if k < n then Some ps.(k) else None in
  let pegado = match sig_ (i + 1) with Some p when p.pegada && not p.cifras -> Some p.t | _ -> None in
  let primero, k =
    match pegado with
    | Some s -> (Some s, i + 2)
    | None -> (match sig_ (i + 1) with Some p when not p.cifras -> (Some p.t, i + 2) | _ -> (None, i + 1))
  in
  let segundo = match sig_ k with Some p when not p.cifras -> Some p.t | _ -> None in
  (pegado, primero, segundo)

let leer_sufijo primero segundo =
  match (primero, segundo) with
  | Some "ti", Some "super" -> ("ti super", 2)
  | Some "tis", _ -> ("ti super", 1)
  | Some "ti", _ -> ("ti", 1)
  | Some ("super" | "s"), _ -> ("super", 1)
  | Some "xtx", _ -> ("xtx", 1)
  | Some "xt", _ -> ("xt", 1)
  | Some "gre", _ -> ("gre", 1)
  | _ -> ("", 0)

let familia_de_prefijo = function
  | "rtx" -> Some Catalogo.Rtx
  | "gtx" | "gts" -> Some Catalogo.Gtx
  | "gt" -> Some Catalogo.Gt
  | "rx" -> Some Catalogo.Rx
  | _ -> None

let profesional_palabras = [ "quadro"; "tesla"; "firepro"; "radeonpro"; "instinct" ]

let menciones texto =
  let ps = Array.of_list (piezas texto) in
  let n = Array.length ps in
  let ant k = if k >= 0 && k < n then Some ps.(k) else None in
  let palabra_antes i = (* la palabra anterior a la del número, entera *)
    let w = ps.(i).palabra - 1 in
    String.concat "" (List.filter_map (fun (p : pieza) -> if p.palabra = w then Some p.t else None) (Array.to_list ps))
  in
  let palabra_de i = (* la palabra entera de la pieza [i] *)
    let w = ps.(i).palabra in
    String.concat "" (List.filter_map (fun (p : pieza) -> if p.palabra = w then Some p.t else None) (Array.to_list ps))
  in
  let hay_antes i ws = (* alguna de [ws] en las dos palabras anteriores *)
    let w0 = ps.(i).palabra in
    Array.exists (fun (p : pieza) -> p.palabra < w0 && p.palabra >= w0 - 2 && List.mem p.t ws) ps
  in
  let salida = ref [] in
  let i = ref 0 in
  while !i < n do
    let p = ps.(!i) in
    (if p.cifras && String.length p.t <= 5 then begin
       let numero = int_of_string p.t in
       (* El prefijo: pegado («rtx3080», «a770», «i5») o la palabra de antes. *)
       let pegado_antes = if p.pegada then Option.map (fun q -> q.t) (ant (!i - 1)) else None in
       let prefijo = match pegado_antes with Some s -> Some s | None -> Some (palabra_antes !i) in
       let pegado, primero, segundo = sufijo_de ps !i in
       let sufijo, _ = leer_sufijo primero segundo in
       let cpu =
         (match pegado_antes with Some ("i" | "e" | "r" | "m") -> true | _ -> false)
         || hay_antes !i cpu_palabras
         || (match prefijo with Some ("i3" | "i5" | "i7" | "i9" | "r3" | "r5" | "r7") -> true | Some "r9" -> numero >= 1000 | _ -> false)
       in
       let familia_explicita =
         match pegado_antes with
         | Some s -> familia_de_prefijo s
         | None -> Option.bind prefijo familia_de_prefijo
       in
       let r9 =
         (* «R9 270X»: «r9» es una palabra (r + 9) y el número va detrás. *)
         prefijo = Some "r9" && numero < 1000
       in
       let arc =
         match pegado_antes with
         | Some "a" when List.mem numero (Catalogo.numeros_de Catalogo.Arc_a) -> Some Catalogo.Arc_a
         | Some "b" when List.mem numero (Catalogo.numeros_de Catalogo.Arc_b) -> Some Catalogo.Arc_b
         | _ -> None
       in
       (* «Arc B770», «Arc C580»: una Arc que el catálogo aún no tiene. *)
       let arc_nueva =
         arc = None && numero >= 100 && numero < 1000
         && (match pegado_antes with Some ("a" | "b" | "c" | "d" | "e") -> true | _ -> false)
         && palabra_antes !i = "arc"
       in
       let antigua_prefijo =
         match (pegado_antes, prefijo) with
         | Some ("hd" | "fx" | "gf"), _ | _, Some ("hd" | "fx" | "r7" | "gts") -> true
         | _ -> false
       in
       let profesional = hay_antes !i profesional_palabras in
       let junk =
         (match pegado with Some s -> List.mem s sufijos_no | None -> false)
         (* «Samsung 970 EVO», «980 PRO»: discos, no gráficas. *)
         || (match primero with Some ("evo" | "pro" | "plus" | "qvo") -> pegado = None | _ -> false)
         (* Otra letra pegada delante que no es una familia (X570, Z790, B450, KA272): placas, monitores. *)
         || (match pegado_antes with Some s -> familia_de_prefijo s = None && not (List.mem s [ "hd"; "fx"; "gf" ]) | None -> false)
       in
       let cpu_sufijo = match pegado with Some s -> List.mem s sufijos_cpu && sufijo = "" | None -> false in
       let leido fam = String.trim (fam ^ " " ^ p.t ^ if sufijo = "" then "" else " " ^ sufijo) in
       let anota ?(antigua = false) ?(profesional = false) modelo leido =
         salida := { modelo; leido; antigua; profesional; primera = !i; palabra = p.palabra } :: !salida
       in
       if arc_nueva then anota None ("arc " ^ Option.get pegado_antes ^ p.t)
       else if arc <> None then begin
         let f = Option.get arc in
         match Catalogo.con_numero ~familia:f numero "" with
         | x :: _ -> anota (Some x) (leido (match f with Catalogo.Arc_a -> "arc a" | _ -> "arc b"))
         | [] -> ()
       end
       else if r9 then begin
         let suf = match pegado with Some "x" -> "x" | _ -> (match primero with Some "x" -> "x" | _ -> "") in
         match Catalogo.con_numero ~familia:Catalogo.R9 numero suf with
         | x :: _ -> anota (Some x) ("r9 " ^ p.t ^ suf)
         | [] -> anota ~antigua:true None ("r9 " ^ p.t ^ suf)
       end
       else if profesional then anota ~profesional:true None (String.trim (palabra_antes !i ^ " " ^ palabra_de !i))
       else if antigua_prefijo && not cpu then anota ~antigua:true None (String.trim (Option.value prefijo ~default:"" ^ " " ^ p.t))
       else if cpu || (familia_explicita = None && (junk || cpu_sufijo)) then ()
       else begin
         let familia =
           match familia_explicita with
           | Some f -> Some f
           | None ->
             if List.mem numero numeros_rtx then Some Catalogo.Rtx
             else if List.mem numero gtx_sueltos then Some Catalogo.Gtx
             else if numero = 1030 then Some Catalogo.Gt
             else if List.mem numero numeros_rx && (numero >= 1000 || numero >= 460) then Some Catalogo.Rx
             else None
         in
         match familia with
         | None -> ()
         | Some f ->
           let fam = match f with Catalogo.Rx -> "rx" | Catalogo.Gt -> "gt" | Catalogo.Gtx -> "gtx" | _ -> "rtx" in
           (match Catalogo.con_numero ~familia:f numero sufijo with
            | x :: _ -> anota (Some x) (leido fam)
            | [] ->
              (* Sin sufijo y con una sola variante (la «RX 5600» es la XT): esa. *)
              let variantes = List.filter (fun x -> x.Catalogo.numero = numero && (Catalogo.es_nvidia x.Catalogo.familia = Catalogo.es_nvidia f)) Catalogo.modelos in
              (match (sufijo, variantes) with
               | "", [ x ] -> anota (Some x) (leido fam)
               | _ ->
                 let viejo =
                   Catalogo.es_nvidia f && familia_explicita <> None && (numero < 750 || (numero >= 8000 && numero < 10000))
                   || (f = Catalogo.Rx && numero < 460)
                 in
                 if viejo then anota ~antigua:true None (leido fam)
                 else if familia_explicita <> None || variantes <> [] then anota None (leido fam)))
       end
     end
     else if (not p.cifras) && p.t = "radeon" then
       (match ant (!i + 1) with
        | Some q when q.t = "vii" -> salida := { modelo = Catalogo.buscar "radeon-vii"; leido = "radeon vii"; antigua = false; profesional = false; primera = !i; palabra = p.palabra } :: !salida
        | _ -> ())
     else if (not p.cifras) && p.t = "vega" then
       (match ant (!i + 1) with
        | Some q when q.cifras && (q.t = "56" || q.t = "64") ->
          salida := { modelo = Catalogo.buscar ("rx-vega-" ^ q.t); leido = "vega " ^ q.t; antigua = false; profesional = false; primera = !i; palabra = p.palabra } :: !salida;
          incr i
        | _ -> ()));
    incr i
  done;
  List.rev !salida

(** Las memorias que dice el texto en GB («12GB», «8 GB», «16G»), en orden. *)
let memorias texto =
  let ps = Array.of_list (piezas texto) in
  let n = Array.length ps in
  let out = ref [] in
  for i = 0 to n - 2 do
    let p = ps.(i) and q = ps.(i + 1) in
    if p.cifras && String.length p.t <= 2 && (not q.cifras) && List.mem q.t [ "gb"; "g"; "gig"; "giga"; "gigas"; "gddr5"; "gddr6"; "gddr6x"; "gddr7" ]
       && (q.pegada || q.t = "gb" || q.t = "g" || q.t = "gigas")
    then out := int_of_string p.t :: !out
  done;
  List.rev !out

(** La memoria de [m] que dice el texto, si es una de las suyas; si no, la de por defecto. *)
let memoria_de (m : Catalogo.modelo) texto =
  match List.find_opt (fun g -> List.mem g m.vram) (memorias texto) with
  | Some g -> g
  | None -> List.hd m.vram

(** ¿Aparece alguna de [palabras] (plegadas, una o varias seguidas) en [texto]? *)
let contiene texto palabras =
  let t = " " ^ String.concat " " (List.filter (( <> ) "") (String.split_on_char ' ' (pliega texto))) ^ " " in
  List.exists
    (fun w ->
      let w = " " ^ w ^ " " in
      let lw = String.length w and lt = String.length t in
      let rec busca i = i + lw <= lt && (String.sub t i lw = w || busca (i + 1)) in
      busca 0)
    palabras

(** El índice de palabra de la primera de [palabras] en [texto], si está. *)
let posicion texto palabras =
  let ws = Array.of_list (List.filter (( <> ) "") (String.split_on_char ' ' (pliega texto))) in
  let n = Array.length ws in
  let encaja i w =
    let partes = Array.of_list (String.split_on_char ' ' w) in
    let k = Array.length partes in
    i + k <= n && Array.for_all Fun.id (Array.init k (fun j -> ws.(i + j) = partes.(j)))
  in
  let rec busca i = if i >= n then None else if List.exists (encaja i) palabras then Some i else busca (i + 1) in
  busca 0

(** ¿Nombra un procesador? («Ryzen 7», «i5 10400F», «5800X3D», «13700K», «Core Ultra 7»). *)
let menciona_cpu texto =
  let ps = Array.of_list (piezas texto) in
  let n = Array.length ps in
  let rec mira i =
    if i >= n then false
    else
      let p = ps.(i) in
      let siguiente = if i + 1 < n then Some ps.(i + 1) else None in
      let es =
        (not p.cifras && List.mem p.t [ "ryzen"; "xeon"; "celeron"; "pentium"; "athlon"; "threadripper" ])
        || (not p.cifras && p.t = "i" && match siguiente with Some q -> q.cifras && q.pegada && List.mem q.t [ "3"; "5"; "7"; "9" ] | None -> false)
        || (p.cifras && String.length p.t >= 4
            && match siguiente with Some q -> q.pegada && (not q.cifras) && List.mem q.t [ "x3d"; "x"; "k"; "kf"; "ks"; "f"; "hx"; "hs"; "h"; "u" ] | None -> false)
      in
      es || mira (i + 1)
  in
  mira 0

(** ¿Nombra un procesador de portátil? («i9-14900HX», «Ryzen 7 7840HS», «i7-1165G7»). *)
let menciona_cpu_portatil texto =
  let ps = Array.of_list (piezas texto) in
  let n = Array.length ps in
  let rec mira i =
    i < n - 1
    && ((ps.(i).cifras && String.length ps.(i).t >= 4 && ps.(i + 1).pegada && List.mem ps.(i + 1).t [ "hx"; "hs"; "h"; "u" ])
        || mira (i + 1))
  in
  mira 0

(** Las palabras de [texto], plegadas. *)
let palabras texto = List.filter (( <> ) "") (String.split_on_char ' ' (pliega texto))

(** Sí, no o no lo dice: [palabras] con una negación delante ([negaciones], en las dos anteriores) es un no. *)
type dicho = Si | No | No_dice

let dice ?(negaciones = []) texto frases =
  let ws = Array.of_list (palabras texto) in
  let n = Array.length ws in
  let encaja i w =
    let partes = Array.of_list (String.split_on_char ' ' w) in
    let k = Array.length partes in
    i + k <= n && Array.for_all Fun.id (Array.init k (fun j -> ws.(i + j) = partes.(j)))
  in
  let negada i = List.exists (fun d -> d >= 1 && i - d >= 0 && List.mem ws.(i - d) negaciones) [ 1; 2 ] in
  let resultado = ref No_dice in
  for i = 0 to n - 1 do
    if List.exists (encaja i) frases then
      resultado := (match (!resultado, negada i) with Si, _ -> Si | _, false -> Si | _, true -> No)
  done;
  !resultado

(** Las memorias en GB con la palabra donde van: para saber de qué modelo es cada una. *)
let memorias_en texto =
  let ps = Array.of_list (piezas texto) in
  let n = Array.length ps in
  let out = ref [] in
  for i = 0 to n - 2 do
    let p = ps.(i) and q = ps.(i + 1) in
    if p.cifras && String.length p.t <= 2 && (not q.cifras) && List.mem q.t [ "gb"; "g"; "gig"; "giga"; "gigas"; "gddr5"; "gddr6"; "gddr6x"; "gddr7" ]
       && (q.pegada || q.t = "gb" || q.t = "g" || q.t = "gigas")
    then out := (p.palabra, int_of_string p.t) :: !out
  done;
  List.rev !out
