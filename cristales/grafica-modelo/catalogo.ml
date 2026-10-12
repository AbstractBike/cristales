(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Las gráficas de sobremesa que se venden de segunda mano, de la GTX 750 Ti
   (2014) a la RTX 5090 y la RX 9070 XT (2025). Una por modelo; las variantes
   de memoria van en [vram] (la primera, la más común).

   [pvp]: el precio de lanzamiento en dólares, como lo anunció el fabricante.
   [rendimiento]: índice ORIENTATIVO de rendimiento en juegos a 1440p, RTX 4090
   = 100, de memoria del modelo que nucleó el cristal sobre las tablas
   comparativas habituales; sirve para «una 3070 o mejor» y para el euro por
   rendimiento, no para decimales. Un modelo nuevo es otra versión del
   cristal: sus defectos («modelo desconocido») son la semilla. *)

type fabricante = Nvidia | Amd | Intel

(* La familia por la que se nombra: el prefijo del número. *)
type familia = Rtx | Gtx | Gt | Rx | R9 | Vega | Arc_a | Arc_b | Radeon_vii

type modelo = {
  clave : string;  (** «rtx-3080»: la del archivo y la de las búsquedas. *)
  nombre : string;  (** «GeForce RTX 3080». *)
  fabricante : fabricante;
  familia : familia;
  numero : int;
  sufijo : string;  (** "", "ti", "super", "ti super", "xt", "xtx", "gre". *)
  anyo : int;
  vram : int list;
  pvp : int option;
  rendimiento : int;
}

let m ?(sufijo = "") ?pvp fabricante familia numero nombre anyo vram rendimiento =
  let fam =
    match familia with
    | Rtx -> "rtx" | Gtx -> "gtx" | Gt -> "gt" | Rx -> "rx" | R9 -> "r9"
    | Vega -> "rx-vega" | Arc_a -> "arc-a" | Arc_b -> "arc-b" | Radeon_vii -> "radeon-vii"
  in
  let num = match familia with Radeon_vii -> "" | _ -> string_of_int numero in
  let partes =
    match familia with
    | Arc_a | Arc_b -> [ fam ^ num ]
    | Radeon_vii -> [ fam ]
    | R9 -> [ fam; num ^ sufijo ]
    | _ -> (fam :: [ num ]) @ (if sufijo = "" then [] else String.split_on_char ' ' sufijo)
  in
  { clave = String.concat "-" partes; nombre; fabricante; familia; numero; sufijo; anyo; vram; pvp; rendimiento }

let nv = Nvidia
let amd = Amd
let intel = Intel

let modelos =
  [ (* NVIDIA, Kepler y Maxwell *)
    m nv Gtx 750 ~sufijo:"ti" "GeForce GTX 750 Ti" 2014 [ 2 ] 3 ~pvp:149;
    m nv Gtx 760 "GeForce GTX 760" 2013 [ 2 ] 5 ~pvp:249;
    m nv Gtx 770 "GeForce GTX 770" 2013 [ 2; 4 ] 6 ~pvp:399;
    m nv Gtx 780 "GeForce GTX 780" 2013 [ 3 ] 8 ~pvp:649;
    m nv Gtx 780 ~sufijo:"ti" "GeForce GTX 780 Ti" 2013 [ 3 ] 9 ~pvp:699;
    m nv Gtx 950 "GeForce GTX 950" 2015 [ 2 ] 5 ~pvp:159;
    m nv Gtx 960 "GeForce GTX 960" 2015 [ 2; 4 ] 6 ~pvp:199;
    m nv Gtx 970 "GeForce GTX 970" 2014 [ 4 ] 9 ~pvp:329;
    m nv Gtx 980 "GeForce GTX 980" 2014 [ 4 ] 10 ~pvp:549;
    m nv Gtx 980 ~sufijo:"ti" "GeForce GTX 980 Ti" 2015 [ 6 ] 13 ~pvp:649;
    (* Pascal *)
    m nv Gt 710 "GeForce GT 710" 2014 [ 2; 1 ] 1;
    m nv Gt 730 "GeForce GT 730" 2014 [ 2; 4 ] 1;
    m nv Gt 1030 "GeForce GT 1030" 2017 [ 2 ] 2 ~pvp:79;
    m nv Gtx 1050 "GeForce GTX 1050" 2016 [ 2; 3 ] 4 ~pvp:109;
    m nv Gtx 1050 ~sufijo:"ti" "GeForce GTX 1050 Ti" 2016 [ 4 ] 5 ~pvp:139;
    m nv Gtx 1060 "GeForce GTX 1060" 2016 [ 6; 3 ] 11 ~pvp:249;
    m nv Gtx 1070 "GeForce GTX 1070" 2016 [ 8 ] 15 ~pvp:379;
    m nv Gtx 1070 ~sufijo:"ti" "GeForce GTX 1070 Ti" 2017 [ 8 ] 17 ~pvp:449;
    m nv Gtx 1080 "GeForce GTX 1080" 2016 [ 8 ] 18 ~pvp:599;
    m nv Gtx 1080 ~sufijo:"ti" "GeForce GTX 1080 Ti" 2017 [ 11 ] 23 ~pvp:699;
    (* Turing *)
    m nv Gtx 1630 "GeForce GTX 1630" 2022 [ 4 ] 3;
    m nv Gtx 1650 "GeForce GTX 1650" 2019 [ 4 ] 7 ~pvp:149;
    m nv Gtx 1650 ~sufijo:"super" "GeForce GTX 1650 Super" 2019 [ 4 ] 9 ~pvp:159;
    m nv Gtx 1660 "GeForce GTX 1660" 2019 [ 6 ] 12 ~pvp:219;
    m nv Gtx 1660 ~sufijo:"super" "GeForce GTX 1660 Super" 2019 [ 6 ] 14 ~pvp:229;
    m nv Gtx 1660 ~sufijo:"ti" "GeForce GTX 1660 Ti" 2019 [ 6 ] 14 ~pvp:279;
    m nv Rtx 2060 "GeForce RTX 2060" 2019 [ 6; 12 ] 19 ~pvp:349;
    m nv Rtx 2060 ~sufijo:"super" "GeForce RTX 2060 Super" 2019 [ 8 ] 22 ~pvp:399;
    m nv Rtx 2070 "GeForce RTX 2070" 2018 [ 8 ] 23 ~pvp:499;
    m nv Rtx 2070 ~sufijo:"super" "GeForce RTX 2070 Super" 2019 [ 8 ] 26 ~pvp:499;
    m nv Rtx 2080 "GeForce RTX 2080" 2018 [ 8 ] 28 ~pvp:699;
    m nv Rtx 2080 ~sufijo:"super" "GeForce RTX 2080 Super" 2019 [ 8 ] 30 ~pvp:699;
    m nv Rtx 2080 ~sufijo:"ti" "GeForce RTX 2080 Ti" 2018 [ 11 ] 36 ~pvp:999;
    (* Ampere *)
    m nv Rtx 3050 "GeForce RTX 3050" 2022 [ 8; 6 ] 15 ~pvp:249;
    m nv Rtx 3060 "GeForce RTX 3060" 2021 [ 12; 8 ] 23 ~pvp:329;
    m nv Rtx 3060 ~sufijo:"ti" "GeForce RTX 3060 Ti" 2020 [ 8 ] 31 ~pvp:399;
    m nv Rtx 3070 "GeForce RTX 3070" 2020 [ 8 ] 37 ~pvp:499;
    m nv Rtx 3070 ~sufijo:"ti" "GeForce RTX 3070 Ti" 2021 [ 8 ] 40 ~pvp:599;
    m nv Rtx 3080 "GeForce RTX 3080" 2020 [ 10; 12 ] 50 ~pvp:699;
    m nv Rtx 3080 ~sufijo:"ti" "GeForce RTX 3080 Ti" 2021 [ 12 ] 55 ~pvp:1199;
    m nv Rtx 3090 "GeForce RTX 3090" 2020 [ 24 ] 56 ~pvp:1499;
    m nv Rtx 3090 ~sufijo:"ti" "GeForce RTX 3090 Ti" 2022 [ 24 ] 61 ~pvp:1999;
    (* Ada *)
    m nv Rtx 4060 "GeForce RTX 4060" 2023 [ 8 ] 26 ~pvp:299;
    m nv Rtx 4060 ~sufijo:"ti" "GeForce RTX 4060 Ti" 2023 [ 8; 16 ] 34 ~pvp:399;
    m nv Rtx 4070 "GeForce RTX 4070" 2023 [ 12 ] 47 ~pvp:599;
    m nv Rtx 4070 ~sufijo:"super" "GeForce RTX 4070 Super" 2024 [ 12 ] 54 ~pvp:599;
    m nv Rtx 4070 ~sufijo:"ti" "GeForce RTX 4070 Ti" 2023 [ 12 ] 58 ~pvp:799;
    m nv Rtx 4070 ~sufijo:"ti super" "GeForce RTX 4070 Ti Super" 2024 [ 16 ] 64 ~pvp:799;
    m nv Rtx 4080 "GeForce RTX 4080" 2022 [ 16 ] 75 ~pvp:1199;
    m nv Rtx 4080 ~sufijo:"super" "GeForce RTX 4080 Super" 2024 [ 16 ] 77 ~pvp:999;
    m nv Rtx 4090 "GeForce RTX 4090" 2022 [ 24 ] 100 ~pvp:1599;
    (* Blackwell *)
    m nv Rtx 5050 "GeForce RTX 5050" 2025 [ 8 ] 21 ~pvp:249;
    m nv Rtx 5060 "GeForce RTX 5060" 2025 [ 8 ] 31 ~pvp:299;
    m nv Rtx 5060 ~sufijo:"ti" "GeForce RTX 5060 Ti" 2025 [ 16; 8 ] 39 ~pvp:379;
    m nv Rtx 5070 "GeForce RTX 5070" 2025 [ 12 ] 57 ~pvp:549;
    m nv Rtx 5070 ~sufijo:"ti" "GeForce RTX 5070 Ti" 2025 [ 16 ] 71 ~pvp:749;
    m nv Rtx 5080 "GeForce RTX 5080" 2025 [ 16 ] 84 ~pvp:999;
    m nv Rtx 5090 "GeForce RTX 5090" 2025 [ 32 ] 128 ~pvp:1999;
    (* AMD: GCN *)
    m amd R9 270 ~sufijo:"x" "Radeon R9 270X" 2013 [ 2; 4 ] 5 ~pvp:199;
    m amd R9 280 ~sufijo:"x" "Radeon R9 280X" 2013 [ 3 ] 6 ~pvp:299;
    m amd R9 290 "Radeon R9 290" 2013 [ 4 ] 8 ~pvp:399;
    m amd R9 290 ~sufijo:"x" "Radeon R9 290X" 2013 [ 4; 8 ] 9 ~pvp:549;
    m amd R9 380 "Radeon R9 380" 2015 [ 4; 2 ] 6 ~pvp:199;
    m amd R9 390 "Radeon R9 390" 2015 [ 8 ] 9 ~pvp:329;
    m amd R9 390 ~sufijo:"x" "Radeon R9 390X" 2015 [ 8 ] 10 ~pvp:429;
    m amd Rx 460 "Radeon RX 460" 2016 [ 4; 2 ] 3 ~pvp:109;
    m amd Rx 470 "Radeon RX 470" 2016 [ 4; 8 ] 8 ~pvp:179;
    m amd Rx 480 "Radeon RX 480" 2016 [ 8; 4 ] 10 ~pvp:239;
    m amd Rx 550 "Radeon RX 550" 2017 [ 4; 2 ] 3 ~pvp:79;
    m amd Rx 560 "Radeon RX 560" 2017 [ 4; 2 ] 4 ~pvp:99;
    m amd Rx 570 "Radeon RX 570" 2017 [ 4; 8 ] 9 ~pvp:169;
    m amd Rx 580 "Radeon RX 580" 2017 [ 8; 4 ] 10 ~pvp:229;
    m amd Rx 590 "Radeon RX 590" 2018 [ 8 ] 11 ~pvp:279;
    m amd Vega 56 "Radeon RX Vega 56" 2017 [ 8 ] 15 ~pvp:399;
    m amd Vega 64 "Radeon RX Vega 64" 2017 [ 8 ] 17 ~pvp:499;
    m amd Radeon_vii 7 "Radeon VII" 2019 [ 16 ] 22 ~pvp:699;
    (* RDNA *)
    m amd Rx 5500 ~sufijo:"xt" "Radeon RX 5500 XT" 2019 [ 8; 4 ] 10 ~pvp:169;
    m amd Rx 5600 ~sufijo:"xt" "Radeon RX 5600 XT" 2020 [ 6 ] 18 ~pvp:279;
    m amd Rx 5700 "Radeon RX 5700" 2019 [ 8 ] 20 ~pvp:349;
    m amd Rx 5700 ~sufijo:"xt" "Radeon RX 5700 XT" 2019 [ 8 ] 23 ~pvp:399;
    (* RDNA 2 *)
    m amd Rx 6400 "Radeon RX 6400" 2022 [ 4 ] 6 ~pvp:159;
    m amd Rx 6500 ~sufijo:"xt" "Radeon RX 6500 XT" 2022 [ 4; 8 ] 9 ~pvp:199;
    m amd Rx 6600 "Radeon RX 6600" 2021 [ 8 ] 22 ~pvp:329;
    m amd Rx 6600 ~sufijo:"xt" "Radeon RX 6600 XT" 2021 [ 8 ] 25 ~pvp:379;
    m amd Rx 6650 ~sufijo:"xt" "Radeon RX 6650 XT" 2022 [ 8 ] 26 ~pvp:399;
    m amd Rx 6700 "Radeon RX 6700" 2022 [ 10 ] 29;
    m amd Rx 6700 ~sufijo:"xt" "Radeon RX 6700 XT" 2021 [ 12 ] 33 ~pvp:479;
    m amd Rx 6750 ~sufijo:"xt" "Radeon RX 6750 XT" 2022 [ 12 ] 35 ~pvp:549;
    m amd Rx 6800 "Radeon RX 6800" 2020 [ 16 ] 42 ~pvp:579;
    m amd Rx 6800 ~sufijo:"xt" "Radeon RX 6800 XT" 2020 [ 16 ] 49 ~pvp:649;
    m amd Rx 6900 ~sufijo:"xt" "Radeon RX 6900 XT" 2020 [ 16 ] 52 ~pvp:999;
    m amd Rx 6950 ~sufijo:"xt" "Radeon RX 6950 XT" 2022 [ 16 ] 56 ~pvp:1099;
    (* RDNA 3 *)
    m amd Rx 7600 "Radeon RX 7600" 2023 [ 8 ] 26 ~pvp:269;
    m amd Rx 7600 ~sufijo:"xt" "Radeon RX 7600 XT" 2024 [ 16 ] 27 ~pvp:329;
    m amd Rx 7700 ~sufijo:"xt" "Radeon RX 7700 XT" 2023 [ 12 ] 41 ~pvp:449;
    m amd Rx 7800 ~sufijo:"xt" "Radeon RX 7800 XT" 2023 [ 16 ] 50 ~pvp:499;
    m amd Rx 7900 ~sufijo:"gre" "Radeon RX 7900 GRE" 2023 [ 16 ] 54 ~pvp:549;
    m amd Rx 7900 ~sufijo:"xt" "Radeon RX 7900 XT" 2022 [ 20 ] 66 ~pvp:899;
    m amd Rx 7900 ~sufijo:"xtx" "Radeon RX 7900 XTX" 2022 [ 24 ] 77 ~pvp:999;
    (* RDNA 4 *)
    m amd Rx 9060 ~sufijo:"xt" "Radeon RX 9060 XT" 2025 [ 16; 8 ] 36 ~pvp:299;
    m amd Rx 9070 "Radeon RX 9070" 2025 [ 16 ] 63 ~pvp:549;
    m amd Rx 9070 ~sufijo:"xt" "Radeon RX 9070 XT" 2025 [ 16 ] 70 ~pvp:599;
    (* Intel Arc *)
    m intel Arc_a 310 "Arc A310" 2022 [ 4 ] 4;
    m intel Arc_a 380 "Arc A380" 2022 [ 6 ] 6 ~pvp:139;
    m intel Arc_a 580 "Arc A580" 2023 [ 8 ] 18 ~pvp:179;
    m intel Arc_a 750 "Arc A750" 2022 [ 8 ] 20 ~pvp:289;
    m intel Arc_a 770 "Arc A770" 2022 [ 16; 8 ] 22 ~pvp:329;
    m intel Arc_b 570 "Arc B570" 2025 [ 10 ] 22 ~pvp:219;
    m intel Arc_b 580 "Arc B580" 2024 [ 12 ] 26 ~pvp:249 ]

let por_clave = Hashtbl.create 128
let () = List.iter (fun x -> Hashtbl.replace por_clave x.clave x) modelos
let buscar clave = Hashtbl.find_opt por_clave clave

let es_nvidia = function Rtx | Gtx | Gt -> true | _ -> false

(* Los de [numero] con [sufijo] de la familia [f] (o de cualquiera del mismo
   fabricante si [f] es de NVIDIA: «RTX 1660» es la GTX 1660). *)
let con_numero ?familia numero sufijo =
  List.filter
    (fun x ->
      x.numero = numero && x.sufijo = sufijo
      && match familia with
         | None -> true
         | Some f when es_nvidia f -> es_nvidia x.familia
         | Some f -> x.familia = f)
    modelos

(* Los números de cada familia, para leer los que van sin prefijo. *)
let numeros_de f = List.sort_uniq compare (List.filter_map (fun x -> if x.familia = f then Some x.numero else None) modelos)

let fabricante_texto = function Nvidia -> "nvidia" | Amd -> "amd" | Intel -> "intel"
