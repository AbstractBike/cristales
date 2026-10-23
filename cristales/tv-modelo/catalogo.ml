(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Las series de televisores que se venden nuevas y de segunda mano en España
   y Europa: las de 2024, 2025 y 2026 de LG, Samsung, Sony, TCL, Hisense,
   Philips, Panasonic y Xiaomi, y las anteriores que más se revenden (de
   2019 en adelante). Una serie es la familia de un año («C6», «S95H»,
   «U7SE»); sus tamaños no se enumeran: el código de cada tele los lleva
   delante («OLED77C6», «75U7SE»), y la lectura los saca de ahí o del texto.

   Los datos son de las fichas de cada fabricante, de memoria del modelo que
   nucleó el cristal: lo que no sabía con seguridad va a [None] (el Hz de las
   series de 2026, la tecnología de alguna). [precio_lanzamiento] está vacío a
   propósito: no conocía el PVP europeo de lanzamiento de ninguna con
   seguridad. [precio_nuevo] es el precio de la tele nueva en idealo.es el
   2026-10-23, por tamaño (no el de lanzamiento). Una serie nueva es otra
   versión del cristal: sus códigos sin serie («nuevos») son la semilla. *)

type tecnologia = Oled | Qd_oled | Mini_led | Rgb_mini_led | Qled | Led
type gama = Alta | Media_alta | Media | Entrada
type sistema = Google_tv | Webos | Tizen | Vidaa | Fire_tv | Android_tv | Titan

let tecnologia_texto = function
  | Oled -> "oled" | Qd_oled -> "qd-oled" | Mini_led -> "mini-led" | Rgb_mini_led -> "rgb-mini-led" | Qled -> "qled" | Led -> "led"

let gama_texto = function Alta -> "alta" | Media_alta -> "media-alta" | Media -> "media" | Entrada -> "entrada"

let sistema_texto = function
  | Google_tv -> "google-tv" | Webos -> "webos" | Tizen -> "tizen" | Vidaa -> "vidaa" | Fire_tv -> "fire-tv"
  | Android_tv -> "android-tv" | Titan -> "titan"

type serie = {
  marca : string;  (** «lg», «samsung», «sony», «tcl», «hisense», «philips», «panasonic», «xiaomi». *)
  serie : string;  (** «C6», «S95H», «U7», «C8L», «BRAVIA 9 II», «OLED809», «Z95A», «S Mini LED». *)
  clave : string;  (** La familia plegada con que la nombran los códigos: «c6», «s95h», «u7se», «xr90». *)
  anio : int option;
  tecnologia : tecnologia option;
  gama : gama option;
  hz : int option;  (** El refresco nativo máximo del panel, si se sabe para la serie. *)
  hdmi21 : bool option;
  sistema : sistema option;
  ocho_k : bool;
  alias : string list;  (** Cómo se nombra sin código, en palabras plegadas: «c6», «oled evo c6», «bravia 9 ii». *)
  precio_nuevo : (int * float) list;  (** Pulgadas y euros, nueva, idealo.es 2026-10-23. *)
  precio_lanzamiento : (int * float) list;  (** Pulgadas y euros: vacío, ver arriba. *)
}

let s ?anio ?tec ?gama ?hz ?hdmi21 ?sistema ?(ocho_k = false) ?(alias = []) ?(precio_nuevo = []) marca serie clave =
  { marca; serie; clave; anio; tecnologia = tec; gama; hz; hdmi21; sistema; ocho_k; alias; precio_nuevo; precio_lanzamiento = [] }

(* --- LG ------------------------------------------------------------------ *)

(* El año de una OLED de LG es la cifra (o la x) detrás de la letra: C9, CX, C1… C6. *)
let anio_lg = function
  | '7' -> Some 2017 | '8' -> Some 2018 | '9' -> Some 2019 | 'x' -> Some 2020 | '1' -> Some 2021 | '2' -> Some 2022
  | '3' -> Some 2023 | '4' -> Some 2024 | '5' -> Some 2025 | '6' -> Some 2026 | _ -> None

let oled_lg letra gama hz_de =
  List.map
    (fun y ->
      let clave = Printf.sprintf "%c%c" letra y in
      let serie = String.uppercase_ascii clave in
      let anio = anio_lg y in
      let hz = hz_de anio in
      s "lg" serie clave ?anio ~tec:Oled ~gama ?hz ~hdmi21:(anio <> Some 2017 && anio <> Some 2018) ~sistema:Webos
        ~alias:[ clave; "oled " ^ clave; "oled evo " ^ clave; "evo " ^ clave ])
    [ '6'; '5'; '4'; '3'; '2'; '1'; 'x'; '9'; '8'; '7' ]

let lg =
  let c = function Some (2024 | 2025) -> Some 144 | Some (2019 | 2020 | 2021 | 2022 | 2023) -> Some 120 | _ -> None in
  let g = function Some 2025 -> Some 165 | Some 2024 -> Some 144 | Some (2019 | 2020 | 2021 | 2022 | 2023) -> Some 120 | _ -> None in
  let b = function Some (2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025) -> Some 120 | _ -> None in
  List.map
    (fun x ->
      match x.serie with
      | "C6" -> { x with precio_nuevo = [ (77, 2249.) ] }
      | "B6" -> { x with precio_nuevo = [ (77, 1499.) ] }
      | _ -> x)
    (oled_lg 'c' Alta c @ oled_lg 'g' Alta g @ oled_lg 'b' Media_alta b)
  @ [ s "lg" "Z3" "z3" ~anio:2023 ~tec:Oled ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Webos ~ocho_k:true ~alias:[ "z3" ];
      s "lg" "Z2" "z2" ~anio:2022 ~tec:Oled ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Webos ~ocho_k:true ~alias:[ "z2" ];
      s "lg" "Z1" "z1" ~anio:2021 ~tec:Oled ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Webos ~ocho_k:true;
      s "lg" "ZX" "zx" ~anio:2020 ~tec:Oled ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Webos ~ocho_k:true;
      s "lg" "Z9" "z9" ~anio:2019 ~tec:Oled ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Webos ~ocho_k:true;
      s "lg" "CS" "cs" ~tec:Oled ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Webos ~alias:[ "oled cs" ];
      s "lg" "A1" "a1" ~anio:2021 ~tec:Oled ~gama:Media ~hz:60 ~sistema:Webos;
      s "lg" "A2" "a2" ~anio:2022 ~tec:Oled ~gama:Media ~hz:60 ~sistema:Webos;
      s "lg" "E9" "e9" ~anio:2019 ~tec:Oled ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Webos;
      s "lg" "E8" "e8" ~anio:2018 ~tec:Oled ~gama:Alta ~hz:120 ~sistema:Webos;
      s "lg" "W9" "w9" ~anio:2019 ~tec:Oled ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Webos;
      s "lg" "M4" "m4" ~anio:2024 ~tec:Oled ~gama:Alta ~hz:144 ~hdmi21:true ~sistema:Webos;
      s "lg" "M5" "m5" ~anio:2025 ~tec:Oled ~gama:Alta ~hz:165 ~hdmi21:true ~sistema:Webos ]

(* --- Samsung ---------------------------------------------------------------- *)

(* La letra del año de Samsung: R 2019, T 2020, A 2021, B 2022, C 2023, D 2024, F 2025, H 2026
   (las de los Crystal UHD de antes, K 2016, M 2017, N 2018, delante). *)
let anio_samsung = function
  | 'k' -> Some 2016 | 'm' -> Some 2017 | 'n' -> Some 2018 | 'r' -> Some 2019 | 't' -> Some 2020 | 'a' -> Some 2021
  | 'b' -> Some 2022 | 'c' -> Some 2023 | 'd' -> Some 2024 | 'f' -> Some 2025 | 'h' -> Some 2026 | _ -> None

let samsung_serie ?tec ?gama ~hz ?(precio_nuevo = fun _ -> []) ?(ocho_k = false) base letras =
  List.map
    (fun l ->
      let clave = base ^ String.make 1 l in
      s "samsung" (String.uppercase_ascii clave) clave ?anio:(anio_samsung l) ?tec ?gama ~hz:(hz l) ~hdmi21:true ~sistema:Tizen ~ocho_k
        ~alias:[ clave ] ~precio_nuevo:(precio_nuevo l))
    letras
  |> List.map (fun x -> if x.hz = Some 0 then { x with hz = None } else x)

let samsung =
  samsung_serie "s95" [ 'h'; 'f'; 'd'; 'c'; 'b' ] ~tec:Qd_oled ~gama:Alta
    ~hz:(function 'f' -> 165 | 'c' | 'd' -> 144 | 'b' -> 120 | _ -> 0)
    ~precio_nuevo:(function 'h' -> [ (77, 2379.) ] | _ -> [])
  @ samsung_serie "s90" [ 'c' ] ~tec:Qd_oled ~gama:Alta ~hz:(fun _ -> 144)
  (* Las S90 de 2024 en adelante llevan panel QD-OLED o WOLED según el tamaño: OLED, sin más. *)
  @ samsung_serie "s90" [ 'h'; 'f'; 'd' ] ~tec:Oled ~gama:Alta ~hz:(function 'd' | 'f' -> 144 | _ -> 0)
  @ samsung_serie "s85" [ 'h'; 'f'; 'd'; 'c' ] ~tec:Oled ~gama:Media_alta ~hz:(function 'c' | 'd' | 'f' -> 120 | _ -> 0)
  @ samsung_serie "qn95" [ 'd'; 'c'; 'b'; 'a' ] ~tec:Mini_led ~gama:Alta ~hz:(function 'c' | 'd' -> 144 | 'a' -> 120 | _ -> 0)
  @ samsung_serie "qn90" [ 'h'; 'f'; 'd'; 'c'; 'b'; 'a' ] ~tec:Mini_led ~gama:Alta ~hz:(function 'f' -> 165 | 'c' | 'd' -> 144 | 'a' -> 120 | _ -> 0)
  @ samsung_serie "qn85" [ 'f'; 'd'; 'c'; 'b'; 'a' ] ~tec:Mini_led ~gama:Media_alta ~hz:(function 'a' | 'b' | 'c' | 'd' -> 120 | _ -> 0)
  @ samsung_serie "qn80" [ 'f'; 'd'; 'c' ] ~tec:Mini_led ~gama:Media_alta ~hz:(fun _ -> 0)
  @ samsung_serie "qn70" [ 'f' ] ~tec:Mini_led ~gama:Media ~hz:(fun _ -> 0)
  @ samsung_serie "qn900" [ 'f'; 'd'; 'c'; 'b'; 'a' ] ~tec:Mini_led ~gama:Alta ~ocho_k:true ~hz:(fun _ -> 0)
  @ samsung_serie "qn990" [ 'f' ] ~tec:Mini_led ~gama:Alta ~ocho_k:true ~hz:(fun _ -> 0)
  @ samsung_serie "qn800" [ 'd'; 'c'; 'b'; 'a' ] ~tec:Mini_led ~gama:Alta ~ocho_k:true ~hz:(fun _ -> 0)
  @ samsung_serie "qn700" [ 'c'; 'b' ] ~tec:Mini_led ~gama:Media_alta ~ocho_k:true ~hz:(fun _ -> 0)
  @ samsung_serie "q80" [ 'd'; 'c'; 'b'; 'a'; 't'; 'r' ] ~tec:Qled ~gama:Media_alta ~hz:(fun _ -> 0)
  @ samsung_serie "q70" [ 'd'; 'c'; 'b'; 'a'; 't'; 'r' ] ~tec:Qled ~gama:Media ~hz:(fun _ -> 0)
  @ samsung_serie "q60" [ 'd'; 'c'; 'b'; 'a'; 't'; 'r' ] ~tec:Qled ~gama:Entrada ~hz:(fun _ -> 60)
  @ samsung_serie "q8" [ 'h'; 'f' ] ~tec:Qled ~gama:Media ~hz:(fun _ -> 0)
  @ samsung_serie "q7" [ 'h'; 'f' ] ~tec:Qled ~gama:Media ~hz:(fun _ -> 0)
  @ samsung_serie "q6" [ 'h'; 'f' ] ~tec:Qled ~gama:Entrada ~hz:(fun _ -> 60)
  (* Las Mini LED que no son Neo QLED, de 2026. *)
  @ samsung_serie "m80" [ 'h' ] ~tec:Mini_led ~gama:Media ~hz:(fun _ -> 0)
  @ samsung_serie "m70" [ 'h' ] ~tec:Mini_led ~gama:Media ~hz:(fun _ -> 0)
  @ List.map
      (fun (l, a) ->
        s "samsung" ("The Frame LS03" ^ String.make 1 (Char.uppercase_ascii l)) ("ls03" ^ String.make 1 l) ~anio:a ~tec:Qled ~gama:Media_alta
          ~sistema:Tizen ~alias:(if l = 'h' then [ "the frame" ] else []))
      [ ('h', 2026); ('f', 2025); ('d', 2024); ('c', 2023); ('b', 2022); ('a', 2021) ]
  (* Crystal UHD: LED de entrada, la letra delante de la U («DU7100», «CU8000»), y las U7/U8 de 2025. *)
  @ List.concat_map
      (fun (l, a) ->
        List.map
          (fun d ->
            let clave = Printf.sprintf "%cu%d000" l d in
            s "samsung" (String.uppercase_ascii clave) clave ~anio:a ~tec:Led ~gama:Entrada ~sistema:Tizen)
          [ 7; 8; 9 ])
      [ ('d', 2024); ('c', 2023); ('b', 2022); ('a', 2021); ('t', 2020); ('r', 2019); ('n', 2018); ('m', 2017); ('k', 2016) ]
  @ [ s "samsung" "U8000F" "u8000f" ~anio:2025 ~tec:Led ~gama:Entrada ~sistema:Tizen ~alias:[ "u8000f" ];
      s "samsung" "U7000F" "u7000f" ~anio:2025 ~tec:Led ~gama:Entrada ~sistema:Tizen ~alias:[ "u7000f" ] ]

(* --- Sony -------------------------------------------------------------------- *)

let anio_sony = function
  | 'd' -> Some 2016 | 'e' -> Some 2017 | 'f' -> Some 2018 | 'g' -> Some 2019 | 'h' -> Some 2020 | 'j' -> Some 2021
  | 'k' -> Some 2022 | 'l' -> Some 2023 | _ -> None

let sony =
  [ s "sony" "BRAVIA 9 II" "xr9m2" ~anio:2026 ~gama:Alta ~hdmi21:true ~sistema:Google_tv ~alias:[ "bravia 9 ii"; "bravia 9 2"; "bravia ix ii" ]
      ~precio_nuevo:[ (75, 3499.) ];
    s "sony" "BRAVIA 8 II" "xr8m2" ~anio:2025 ~tec:Qd_oled ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Google_tv
      ~alias:[ "bravia 8 ii"; "bravia 8 2"; "bravia viii ii" ];
    s "sony" "BRAVIA 9" "xr90" ~anio:2024 ~tec:Mini_led ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Google_tv ~alias:[ "bravia 9" ];
    s "sony" "BRAVIA 8" "xr80" ~anio:2024 ~tec:Oled ~gama:Alta ~hz:120 ~hdmi21:true ~sistema:Google_tv ~alias:[ "bravia 8" ];
    s "sony" "BRAVIA 7" "xr70" ~anio:2024 ~tec:Mini_led ~gama:Media_alta ~hz:120 ~hdmi21:true ~sistema:Google_tv ~alias:[ "bravia 7" ];
    s "sony" "BRAVIA 5" "xr50" ~anio:2025 ~gama:Media ~hdmi21:true ~sistema:Google_tv ~alias:[ "bravia 5" ];
    s "sony" "BRAVIA 3" "s30" ~anio:2024 ~tec:Led ~gama:Entrada ~hz:60 ~sistema:Google_tv ~alias:[ "bravia 3" ] ]
  @ List.map
      (fun (clave, tec, gama, hz) ->
        let anio = anio_sony clave.[String.length clave - 1] in
        s "sony" (String.uppercase_ascii clave) clave ?anio ~tec ~gama ?hz ~hdmi21:(anio >= Some 2021)
          ~sistema:(if anio >= Some 2021 then Google_tv else Android_tv) ~alias:[ clave ])
      [ ("a95l", Qd_oled, Alta, Some 120); ("a95k", Qd_oled, Alta, Some 120); ("a90k", Oled, Alta, Some 120); ("a90j", Oled, Alta, Some 120);
        ("a80l", Oled, Media_alta, Some 120); ("a80k", Oled, Media_alta, Some 120); ("a80j", Oled, Media_alta, Some 120);
        ("a75l", Oled, Media_alta, Some 120); ("a75k", Oled, Media_alta, Some 120);
        ("x95l", Mini_led, Alta, Some 120); ("x95k", Mini_led, Alta, Some 120); ("x95j", Led, Alta, Some 120);
        ("x93l", Mini_led, Media_alta, Some 120); ("x90l", Led, Media_alta, Some 120); ("x90k", Led, Media_alta, Some 120);
        ("x90j", Led, Media_alta, Some 120); ("x85l", Led, Media, Some 120); ("x85k", Led, Media, Some 120); ("x85j", Led, Media, Some 120);
        ("x80l", Led, Entrada, Some 60); ("x80k", Led, Entrada, Some 60); ("x80j", Led, Entrada, Some 60); ("x75wl", Led, Entrada, Some 60);
        ("x75l", Led, Entrada, Some 60); ("x75k", Led, Entrada, Some 60) ]
  (* Las de antes de 2021: «AF8», «AG9», «XH90», «XG85», «XE70». *)
  @ List.map
      (fun (clave, tec, gama) ->
        s "sony" (String.uppercase_ascii clave) clave ?anio:(anio_sony clave.[1]) ~tec ~gama ~sistema:Android_tv ~alias:[ clave ])
      [ ("ah8", Oled, Alta); ("ag9", Oled, Alta); ("ag8", Oled, Alta); ("af9", Oled, Alta); ("af8", Oled, Alta); ("xh95", Led, Media_alta);
        ("xh90", Led, Media_alta); ("xh85", Led, Media); ("xh80", Led, Entrada); ("xg95", Led, Media_alta); ("xg90", Led, Media_alta);
        ("xg85", Led, Media); ("xg80", Led, Entrada); ("xf90", Led, Media_alta); ("xf85", Led, Media); ("xe90", Led, Media_alta);
        ("xe85", Led, Media); ("xe70", Led, Entrada) ]

(* --- TCL ------------------------------------------------------------------- *)

let tcl =
  let t ?anio ?tec ?gama ?hz ?(precio_nuevo = []) clave =
    s "tcl" (String.uppercase_ascii clave) clave ?anio ?tec ?gama ?hz ~hdmi21:(gama <> Some Entrada) ~sistema:Google_tv ~alias:[ clave ] ~precio_nuevo
  in
  [ t "c8l" ~anio:2026 ~tec:Mini_led ~gama:Alta ~precio_nuevo:[ (75, 1739.) ];
    t "c7l" ~anio:2026 ~tec:Mini_led ~gama:Media_alta ~precio_nuevo:[ (75, 1139.) ];
    t "c6l" ~anio:2026 ~tec:Mini_led ~gama:Media;
    t "qm8l" ~anio:2026 ~tec:Mini_led ~gama:Alta;
    t "qm7l" ~anio:2026 ~tec:Mini_led ~gama:Media_alta;
    t "qm6l" ~anio:2026 ~tec:Mini_led ~gama:Media;
    t "p8l" ~anio:2026 ~gama:Entrada ~precio_nuevo:[ (75, 708.) ];
    t "p7l" ~anio:2026 ~gama:Entrada;
    t "x11l" ~anio:2026 ~tec:Mini_led ~gama:Alta;
    t "c8k" ~anio:2025 ~tec:Mini_led ~gama:Alta ~hz:144;
    t "c7k" ~anio:2025 ~tec:Mini_led ~gama:Media_alta ~hz:144;
    t "c6k" ~anio:2025 ~tec:Mini_led ~gama:Media;
    t "qm9k" ~anio:2025 ~tec:Mini_led ~gama:Alta ~hz:144;
    t "qm8k" ~anio:2025 ~tec:Mini_led ~gama:Alta ~hz:144;
    t "qm7k" ~anio:2025 ~tec:Mini_led ~gama:Media_alta ~hz:144;
    t "qm6k" ~anio:2025 ~tec:Mini_led ~gama:Media;
    t "x11k" ~anio:2025 ~tec:Mini_led ~gama:Alta;
    t "p8k" ~anio:2025 ~gama:Entrada;
    t "p7k" ~anio:2025 ~gama:Entrada;
    t "p6k" ~anio:2025 ~tec:Led ~gama:Entrada;
    t "t69" ~anio:2025 ~tec:Qled ~gama:Entrada;
    t "qm8b" ~anio:2024 ~tec:Mini_led ~gama:Alta ~hz:144;
    t "t8b" ~anio:2024 ~tec:Qled ~gama:Media;
    t "c855" ~anio:2024 ~tec:Mini_led ~gama:Alta ~hz:144;
    t "c805" ~anio:2023 ~tec:Mini_led ~gama:Media_alta ~hz:144;
    t "c845" ~anio:2023 ~tec:Mini_led ~gama:Alta ~hz:144;
    t "c765" ~anio:2024 ~tec:Qled ~gama:Media;
    t "c745" ~anio:2023 ~tec:Qled ~gama:Media ~hz:144;
    t "c655" ~anio:2024 ~tec:Qled ~gama:Entrada;
    t "c645" ~anio:2023 ~tec:Qled ~gama:Entrada;
    t "p755" ~anio:2024 ~tec:Led ~gama:Entrada;
    t "p745" ~anio:2023 ~tec:Led ~gama:Entrada;
    t "p635" ~anio:2022 ~tec:Led ~gama:Entrada ]

(* --- Hisense ------------------------------------------------------------- *)

(* La letra del año de Hisense: G 2021, H 2022, K 2023, N 2024, Q 2025, S 2026 (y la «Q» final de
   Europa: 55U7KQ es la U7K). La serie es la familia («U7»); la variante, el código entero. *)
let anio_hisense = function
  | 'g' -> Some 2021 | 'h' -> Some 2022 | 'k' -> Some 2023 | 'n' -> Some 2024 | 'q' -> Some 2025 | 's' -> Some 2026 | _ -> None

let hisense =
  let h ?anio ?tec ?gama ?hz ?(alias = []) ?(precio_nuevo = []) serie clave =
    s "hisense" serie clave ?anio ?tec ?gama ?hz ~hdmi21:(gama <> Some Entrada) ~sistema:Vidaa ~alias:(clave :: alias) ~precio_nuevo
  in
  [ h "U7" "u7se" ~anio:2026 ~tec:Mini_led ~gama:Media_alta ~precio_nuevo:[ (75, 999.) ];
    h "U7" "u7spro" ~anio:2026 ~tec:Mini_led ~gama:Media_alta ~alias:[ "u7s pro" ] ~precio_nuevo:[ (75, 1161.) ];
    h "U7" "u7s" ~anio:2026 ~tec:Mini_led ~gama:Media_alta;
    h "U7" "u7sg" ~anio:2026 ~tec:Mini_led ~gama:Media_alta;
    h "U8" "u8s" ~anio:2026 ~tec:Mini_led ~gama:Alta;
    h "U6" "u6s" ~anio:2026 ~tec:Mini_led ~gama:Media ~alias:[ "u6sf"; "u6sf pro" ];
    h "U7" "u7q" ~anio:2025 ~tec:Mini_led ~gama:Media_alta ~alias:[ "u7q pro" ];
    h "U8" "u8q" ~anio:2025 ~tec:Mini_led ~gama:Alta;
    h "U6" "u6q" ~anio:2025 ~tec:Mini_led ~gama:Media;
    h "UX" "uxq" ~anio:2025 ~tec:Mini_led ~gama:Alta;
    h "E7" "e7q" ~anio:2025 ~tec:Qled ~gama:Media ~alias:[ "e77q"; "e7q pro" ];
    h "U7" "u7n" ~anio:2024 ~tec:Mini_led ~gama:Media_alta ~hz:144;
    h "U8" "u8n" ~anio:2024 ~tec:Mini_led ~gama:Alta ~hz:144;
    h "U6" "u6n" ~anio:2024 ~tec:Mini_led ~gama:Media;
    h "UX" "uxn" ~anio:2024 ~tec:Mini_led ~gama:Alta;
    h "E7" "e7n" ~anio:2024 ~tec:Qled ~gama:Media ~alias:[ "e77n"; "e7n pro" ];
    h "A85" "a85n" ~anio:2024 ~tec:Oled ~gama:Alta ~hz:144;
    h "U7" "u7k" ~anio:2023 ~tec:Mini_led ~gama:Media_alta ~hz:144;
    h "U8" "u8k" ~anio:2023 ~tec:Mini_led ~gama:Alta ~hz:144;
    h "U6" "u6k" ~anio:2023 ~tec:Mini_led ~gama:Media;
    h "UX" "uxk" ~anio:2023 ~tec:Mini_led ~gama:Alta;
    h "E7" "e7k" ~anio:2023 ~tec:Qled ~gama:Media ~alias:[ "e77k" ];
    h "A85" "a85k" ~anio:2023 ~tec:Oled ~gama:Alta;
    h "U7" "u7h" ~anio:2022 ~tec:Qled ~gama:Media ~alias:[ "u77h" ];
    h "U8" "u8h" ~anio:2022 ~tec:Mini_led ~gama:Media_alta;
    h "A85" "a85h" ~anio:2022 ~tec:Oled ~gama:Alta;
    h "A9" "a9g" ~anio:2021 ~tec:Oled ~gama:Alta ]

(* --- Philips ------------------------------------------------------------------ *)

(* El año de una Philips es su última cifra: OLED806 2021, 807 2022, 808 2023, 809 2024,
   810 2025, 811 2026; PUS7805 2020, PUS8909 2024; PUS8000 2025. *)
let anio_philips c = match c with '5' .. '9' -> Some (2015 + Char.code c - Char.code '0') | '0' .. '4' -> Some (2025 + Char.code c - Char.code '0') | _ -> None

let philips =
  let p ?tec ?gama ?hz clave =
    let anio = anio_philips clave.[String.length clave - 1] in
    s "philips" (String.uppercase_ascii clave) clave ?anio ?tec ?gama ?hz ~hdmi21:(gama <> Some Entrada) ~alias:[ clave ]
  in
  List.map (fun c -> p ("oled" ^ c) ~tec:Oled ~gama:Alta ~hz:(if c = "809" || c = "909" then 144 else 120))
    [ "811"; "810"; "809"; "808"; "807"; "806"; "911"; "910"; "909"; "908"; "907"; "959"; "950"; "936"; "935" ]
  |> List.map (fun x -> if x.anio >= Some 2025 then { x with hz = None } else x)
  |> fun l ->
  l
  @ List.map (fun c -> p ("oled" ^ c) ~tec:Oled ~gama:Media_alta) [ "771"; "770"; "760"; "759"; "718"; "708"; "707"; "706"; "705" ]
  @ List.map (fun c -> p ("pml" ^ c) ~tec:Mini_led ~gama:Media_alta ~hz:144) [ "9009"; "9059"; "9019" ]
  @ List.map (fun c -> p ("pml" ^ c) ~tec:Mini_led ~gama:Media_alta) [ "9010"; "8000"; "8900"; "9000" ]

(* --- Panasonic ---------------------------------------------------------------- *)

let panasonic =
  let p ?anio ?tec ?gama ?hz ?sistema clave =
    s "panasonic" (String.uppercase_ascii clave) clave ?anio ?tec ?gama ?hz ~hdmi21:(gama <> Some Entrada) ?sistema ~alias:[ clave ]
  in
  [ p "z95b" ~anio:2025 ~tec:Oled ~gama:Alta ~hz:144 ~sistema:Fire_tv;
    p "z90b" ~anio:2025 ~tec:Oled ~gama:Alta ~hz:144 ~sistema:Fire_tv;
    p "z85b" ~anio:2025 ~tec:Oled ~gama:Media_alta ~sistema:Fire_tv;
    p "z80b" ~anio:2025 ~tec:Oled ~gama:Media_alta ~sistema:Fire_tv;
    p "w95b" ~anio:2025 ~tec:Mini_led ~gama:Media_alta ~sistema:Fire_tv;
    p "z95a" ~anio:2024 ~tec:Oled ~gama:Alta ~hz:144 ~sistema:Fire_tv;
    p "z90a" ~anio:2024 ~tec:Oled ~gama:Alta ~hz:144 ~sistema:Fire_tv;
    p "z85a" ~anio:2024 ~tec:Oled ~gama:Media_alta ~sistema:Fire_tv;
    p "z80a" ~anio:2024 ~tec:Oled ~gama:Media_alta ~sistema:Fire_tv;
    p "w95a" ~anio:2024 ~tec:Mini_led ~gama:Media_alta ~sistema:Fire_tv;
    p "w93a" ~anio:2024 ~tec:Mini_led ~gama:Media ~sistema:Fire_tv;
    p "w90a" ~anio:2024 ~tec:Led ~gama:Media ~sistema:Fire_tv;
    p "w80a" ~anio:2024 ~tec:Led ~gama:Entrada ~sistema:Fire_tv;
    p "mz2000" ~anio:2023 ~tec:Oled ~gama:Alta ~hz:120;
    p "mz1500" ~anio:2023 ~tec:Oled ~gama:Alta ~hz:120;
    p "mz980" ~anio:2023 ~tec:Oled ~gama:Media_alta ~hz:120;
    p "mz800" ~anio:2023 ~tec:Oled ~gama:Media_alta ~hz:120;
    p "mx950" ~anio:2023 ~tec:Mini_led ~gama:Media_alta;
    p "lz2000" ~anio:2022 ~tec:Oled ~gama:Alta ~hz:120;
    p "lz1500" ~anio:2022 ~tec:Oled ~gama:Alta ~hz:120;
    p "lz1000" ~anio:2022 ~tec:Oled ~gama:Media_alta ~hz:120;
    p "lz980" ~anio:2022 ~tec:Oled ~gama:Media_alta ~hz:120;
    p "jz2000" ~anio:2021 ~tec:Oled ~gama:Alta ~hz:120;
    p "jz1500" ~anio:2021 ~tec:Oled ~gama:Alta ~hz:120;
    p "jz1000" ~anio:2021 ~tec:Oled ~gama:Media_alta ~hz:120;
    p "hz2000" ~anio:2020 ~tec:Oled ~gama:Alta;
    p "hz1500" ~anio:2020 ~tec:Oled ~gama:Alta;
    p "hz1000" ~anio:2020 ~tec:Oled ~gama:Media_alta;
    p "gz2000" ~anio:2019 ~tec:Oled ~gama:Alta;
    p "gz1500" ~anio:2019 ~tec:Oled ~gama:Alta;
    p "gz1000" ~anio:2019 ~tec:Oled ~gama:Media_alta ]

(* --- Xiaomi ---------------------------------------------------------------- *)

(* Xiaomi no pone el año en el nombre: «TV A Pro 65 (2026)». La serie es el nombre. *)
let xiaomi =
  let x ?anio ?tec ?gama ?hz ?hdmi21 ?sistema ?precio_nuevo serie clave alias = s "xiaomi" serie clave ?anio ?tec ?gama ?hz ?hdmi21 ?sistema ?precio_nuevo ~alias in
  [ x "S Pro Mini LED" "spro" [ "s pro mini led"; "tv s pro"; "s pro"; "spro" ] ~anio:2026 ~tec:Mini_led ~gama:Alta ~sistema:Google_tv;
    (* La S Mini LED de 2025 (55, 65 y 75; L75MA-SME): QD-Mini LED, 144 Hz nativos, dos HDMI 2.1, Google TV. *)
    x "S Mini LED" "smini" [ "s mini led"; "tv s mini"; "s mini"; "s miniled" ] ~anio:2025 ~tec:Mini_led ~gama:Media_alta ~hz:144 ~hdmi21:true
      ~sistema:Google_tv ~precio_nuevo:[ (75, 689.) ];
    x "A Pro" "apro" [ "tv a pro"; "a pro" ] ~tec:Qled ~gama:Entrada ~sistema:Google_tv;
    x "F Pro" "fpro" [ "tv f pro"; "f pro" ] ~tec:Qled ~gama:Entrada ~sistema:Fire_tv;
    x "Max" "max" [ "tv max" ] ~tec:Qled ~gama:Media;
    x "F2" "f2" [ "f2" ] ~tec:Led ~gama:Entrada ~sistema:Fire_tv;
    x "F" "f" [ "tv f" ] ~gama:Entrada ~sistema:Fire_tv;
    x "A" "a" [ "tv a" ] ~tec:Led ~gama:Entrada ~sistema:Google_tv;
    x "A2" "a2" [ "a2" ] ~tec:Led ~gama:Entrada ~sistema:Android_tv;
    x "Q2" "q2" [ "q2" ] ~tec:Qled ~gama:Entrada ~sistema:Google_tv;
    x "Q1E" "q1e" [ "q1e" ] ~tec:Qled ~gama:Media ~sistema:Android_tv;
    x "P1E" "p1e" [ "p1e" ] ~tec:Led ~gama:Entrada ~sistema:Android_tv;
    x "P1" "p1" [ "p1" ] ~tec:Led ~gama:Entrada ~sistema:Android_tv ]

let series = lg @ samsung @ sony @ tcl @ hisense @ philips @ panasonic @ xiaomi

(* --- marcas ----------------------------------------------------------------- *)

(** Las marcas de televisores, como se escriben (plegadas) y su clave. *)
let marcas =
  [ ("lg", "lg"); ("samsung", "samsung"); ("sony", "sony"); ("bravia", "sony"); ("tcl", "tcl"); ("hisense", "hisense");
    ("philips", "philips"); ("philipps", "philips"); ("ambilight", "philips"); ("panasonic", "panasonic"); ("viera", "panasonic");
    ("xiaomi", "xiaomi"); ("redmi", "xiaomi"); ("toshiba", "toshiba"); ("grundig", "grundig"); ("telefunken", "telefunken");
    ("metz", "metz"); ("loewe", "loewe"); ("thomson", "thomson"); ("haier", "haier"); ("sharp", "sharp"); ("aquos", "sharp");
    ("td systems", "td-systems"); ("nilait", "nilait"); ("inves", "inves"); ("daewoo", "daewoo"); ("selecline", "selecline");
    ("polaroid", "polaroid"); ("bang olufsen", "bang-olufsen"); ("b o", "bang-olufsen"); ("beovision", "bang-olufsen");
    ("hitachi", "hitachi"); ("jvc", "jvc"); ("medion", "medion"); ("blaupunkt", "blaupunkt"); ("vestel", "vestel");
    ("kiano", "kiano"); ("infiniton", "infiniton"); ("engel", "engel"); ("nokia", "nokia"); ("strong", "strong");
    ("silvercrest", "silvercrest"); ("lenco", "lenco"); ("sunstech", "sunstech"); ("cecotec", "cecotec"); ("skyworth", "skyworth");
    ("vizio", "vizio"); ("chiq", "chiq"); ("changhong", "changhong"); ("akai", "akai"); ("aiwa", "aiwa"); ("schneider", "schneider");
    ("saba", "saba"); ("finlux", "finlux"); ("hyundai", "hyundai"); ("dyon", "dyon"); ("reflexion", "reflexion");
    ("continental edison", "continental-edison"); ("qilive", "qilive"); ("hanseatic", "hanseatic"); ("peaq", "peaq");
    ("orima", "orima"); ("roku", "roku"); ("tesla", "tesla"); ("onn", "onn"); ("insignia", "insignia"); ("bush", "bush") ]

let nombre_marca = function
  | "lg" -> "LG" | "tcl" -> "TCL" | "jvc" -> "JVC" | "td-systems" -> "TD Systems" | "bang-olufsen" -> "Bang & Olufsen"
  | "chiq" -> "CHiQ" | "continental-edison" -> "Continental Edison"
  | m -> String.capitalize_ascii m

let de_marca m = List.filter (fun x -> x.marca = m) series

(** La serie de [marca] que nombra [clave] (plegada): la de su clave o la de un alias. *)
let busca marca clave =
  match List.find_opt (fun x -> x.marca = marca && x.clave = clave) series with
  | Some x -> Some x
  | None -> List.find_opt (fun x -> x.marca = marca && List.mem clave x.alias) series

(** La gama de un código que el catálogo no tiene, cuando la dice el propio código: las Philips por
    su primera cifra (PUS7xxx de entrada, PUS8xxx media, PUS9xxx media-alta; OLED8xx y 9xx alta),
    los Crystal UHD de Samsung y las UHD de LG, de entrada. *)
let gama_deducida marca clave =
  let empieza p = String.length clave > String.length p && String.sub clave 0 (String.length p) = p in
  let tras p = clave.[String.length p] in
  match marca with
  | "philips" when empieza "pus" -> (match tras "pus" with '9' -> Some Media_alta | '8' -> Some Media | _ -> Some Entrada)
  | "philips" when empieza "oled" -> (match tras "oled" with '8' | '9' -> Some Alta | _ -> Some Media_alta)
  | "philips" when empieza "pml" -> Some Media_alta
  | "samsung" when String.length clave >= 2 && clave.[1] = 'u' -> Some Entrada
  | "lg" when empieza "u" -> Some Entrada
  | _ -> None
