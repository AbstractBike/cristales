(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type tablas = { l0 : string; l1 : string }

let literal s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '\'';
  String.iter
    (function
      | '\'' -> Buffer.add_string b "''"
      | '\\' -> ()
      | c when Char.code c < 0x20 || Char.code c = 0x7f -> Buffer.add_char b ' '
      | c -> Buffer.add_char b c)
    s;
  Buffer.add_char b '\'';
  Buffer.contents b

(* Latin-1 en UTF-8: [C3 80]–[C3 9E] son las mayúsculas (menos × en [C3 97]);
   su minúscula está 0x20 más arriba. *)
let minusculas s =
  let b = Bytes.of_string (String.lowercase_ascii s) in
  for i = 0 to Bytes.length b - 2 do
    let c = Char.code (Bytes.get b (i + 1)) in
    if Bytes.get b i = '\xC3' && c >= 0x80 && c <= 0x9E && c <> 0x97 then
      Bytes.set b (i + 1) (Char.chr (c + 0x20))
  done;
  Bytes.to_string b

(* Letras y dígitos ASCII y las letras de Latin-1 (dos bytes, [C3 xx]); lo
   demás (puntuación, símbolos, otros alfabetos) separa. *)
let terminos consulta =
  let s = minusculas consulta in
  let n = String.length s in
  let actual = Buffer.create 16 and salida = ref [] in
  let cerrar () =
    let t = Buffer.contents actual in
    Buffer.clear actual;
    if String.length t >= 2 && not (List.mem t !salida) then salida := t :: !salida
  in
  let rec ir i =
    if i < n then
      match s.[i] with
      | 'a' .. 'z' | '0' .. '9' ->
          Buffer.add_char actual s.[i];
          ir (i + 1)
      | '\xC3' when i + 1 < n && Char.code s.[i + 1] land 0xC0 = 0x80 && s.[i + 1] <> '\x97' && s.[i + 1] <> '\xB7' ->
          Buffer.add_string actual (String.sub s i 2);
          ir (i + 2)
      | _ ->
          cerrar ();
          ir (i + 1)
  in
  ir 0;
  cerrar ();
  List.filteri (fun i _ -> i < 12) (List.rev !salida)

let digitos s = s <> "" && String.for_all (function '0' .. '9' -> true | _ -> false) s

let fecha s =
  let s = String.trim s in
  let error = Error (s ^ ": fecha como AAAA-MM-DD o AAAA-MM-DD HH:MM") in
  let dia d =
    match String.split_on_char '-' d with
    | [ a; m; d ] when String.length a = 4 && String.length m = 2 && String.length d = 2
                       && digitos a && digitos m && digitos d -> Some d
    | _ -> None
  in
  let hora h =
    match String.split_on_char ':' h with
    | [ h; m ] when String.length h = 2 && String.length m = 2 && digitos h && digitos m -> Some (h ^ ":" ^ m ^ ":00")
    | [ h; m; x ] when String.length h = 2 && String.length m = 2 && String.length x = 2
                       && digitos h && digitos m && digitos x -> Some (h ^ ":" ^ m ^ ":" ^ x)
    | _ -> None
  in
  let d, h =
    match String.index_from_opt s 0 'T', String.index_from_opt s 0 ' ' with
    | Some i, _ | None, Some i -> (String.sub s 0 i, Some (String.sub s (i + 1) (String.length s - i - 1)))
    | None, None -> (s, None)
  in
  match dia d, h with
  | Some _, None -> Ok (d ^ " 00:00:00")
  | Some _, Some h -> ( match hora h with Some h -> Ok (d ^ " " ^ h) | None -> error)
  | None, _ -> error

let tipos = [ "persona"; "regla"; "hecho"; "metodo"; "episodio" ]

(* GreptimeDB evalúa [matches] distinguiendo mayúsculas aunque el índice no
   lo haga: se busca sobre [lower(columna)] con los términos en minúsculas.
   Los términos separados por espacios son un O; cada uno va entre comillas
   dobles para que «or», «and» o «not» no se lean como operadores. *)
let casa columna terminos =
  Printf.sprintf "matches(lower(%s), %s)" columna
    (literal (String.concat " " (List.map (fun t -> "\"" ^ t ^ "\"") terminos)))

let y condiciones = String.concat " AND " condiciones
let de_proyecto = Option.map (fun p -> Printf.sprintf "strpos(proyecto, %s) > 0" (literal p))
let tope = 200

let atomos t ~terminos ?tipo ?proyecto () =
  Printf.sprintf
    "SELECT ts, \"id\", \"version\", tipo, prioridad, escena, contenido, proyecto, fechas FROM %s WHERE %s \
     ORDER BY ts DESC LIMIT %d"
    t.l1
    (y
       (List.filter_map Fun.id
          [ Some "vigente = true";
            Some (casa "contenido" terminos);
            Option.map (fun x -> "tipo = " ^ literal x) tipo;
            de_proyecto proyecto ]))
    tope

let ultimas t ids =
  Printf.sprintf "SELECT \"id\", max(\"version\") FROM %s WHERE \"id\" IN (%s) GROUP BY \"id\"" t.l1
    (String.concat ", " (List.map literal ids))

let mensajes t ~terminos ?proyecto ?desde () =
  Printf.sprintf "SELECT ts, sesion, proyecto, rol, texto FROM %s WHERE %s ORDER BY ts DESC LIMIT %d" t.l0
    (y
       (List.filter_map Fun.id
          [ Some (casa "texto" terminos);
            de_proyecto proyecto;
            Option.map (fun d -> "ts >= " ^ literal d) desde ]))
    tope

let contiene texto t =
  let n = String.length t and m = String.length texto in
  let rec ir i = i + n <= m && (String.sub texto i n = t || ir (i + 1)) in
  ir 0

let aciertos terminos texto =
  let texto = minusculas texto in
  List.length (List.filter (contiene texto) terminos)

let posicion texto t =
  let n = String.length t and m = String.length texto in
  let rec ir i = if i + n > m then None else if String.sub texto i n = t then Some i else ir (i + 1) in
  ir 0

let extracto ?(ancho = 320) terminos texto =
  let texto = String.concat " " (String.split_on_char '\n' texto) in
  let bajo = minusculas texto in
  let m = String.length texto in
  if m <= ancho then texto
  else
    let centro = List.filter_map (posicion bajo) terminos |> List.fold_left min m in
    let centro = if centro = m then 0 else centro in
    let desde = max 0 (centro - (ancho / 3)) in
    (* Sin partir caracteres UTF-8 por ninguno de los dos lados. *)
    let rec inicio i = if i > 0 && i < m && Char.code texto.[i] land 0xC0 = 0x80 then inicio (i - 1) else i in
    let desde = inicio desde in
    let hasta = inicio (min m (desde + ancho)) in
    (if desde > 0 then "…" else "") ^ String.sub texto desde (hasta - desde) ^ if hasta < m then "…" else ""
