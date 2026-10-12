(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: de qué va una noticia de hardware, para quien sigue las gráficas
   de sobremesa. Ver SEMILLA.md.

   La entrada son líneas «Título: …», «Resumen: …» y «Fuente: …»; sin
   «Título:», todo es el título. Se decide por el título; el resumen solo
   suma modelos y marcas cuando el título ya va de gráficas. *)

open Grafica_modelo

type noticia = { titulo : string; resumen : string; fuente : string }

let partes entrada =
  let lineas = String.split_on_char '\n' entrada in
  let campo nombres l =
    let l = String.trim l in
    List.find_map
      (fun nombre ->
        let p = nombre ^ ":" in
        if String.length l >= String.length p && String.lowercase_ascii (String.sub l 0 (String.length p)) = String.lowercase_ascii p
        then Some (String.trim (String.sub l (String.length p) (String.length l - String.length p)))
        else None)
      nombres
  in
  match List.find_map (campo [ "Título"; "Titulo"; "Title" ]) lineas with
  | None -> { titulo = String.trim entrada; resumen = ""; fuente = "" }
  | Some titulo ->
    let resumen = Option.value ~default:"" (List.find_map (campo [ "Resumen"; "Summary" ]) lineas) in
    let fuente = Option.value ~default:"" (List.find_map (campo [ "Fuente"; "Source" ]) lineas) in
    { titulo; resumen; fuente }

(* --- palabras (plegadas) --------------------------------------------------- *)

let gpu =
  [ "gpu"; "gpus"; "geforce"; "radeon"; "grafica"; "graficas"; "tarjeta grafica"; "tarjetas graficas"; "grafikkarte"; "grafikkarten";
    "graphics card"; "graphics cards"; "video card"; "vram"; "rdna"; "rdna 4"; "rdna 5"; "blackwell"; "ada lovelace"; "battlemage";
    "celestial"; "dlss"; "fsr"; "game ready"; "adrenalin"; "founders edition"; "gddr6"; "gddr6x"; "gddr7"; "xess" ]

(* Lo que no es una gráfica de sobremesa para jugar. *)
let fuera =
  [ "data center"; "datacenter"; "rack"; "racks"; "server"; "servers"; "servidor"; "servidores"; "hbm"; "hbm3e"; "hbm4"; "hbm4e";
    "rubin"; "vera rubin"; "mgx"; "dgx"; "hgx"; "instinct"; "epyc"; "xeon"; "laptop"; "laptops"; "portatil"; "portatiles"; "notebook";
    "ps5"; "ps6"; "xbox"; "playstation"; "switch 2"; "iphone"; "smartphone"; "tablet"; "ai pc"; "agentic"; "supercomputer"; "nvlink";
    "workstation"; "radeon pro"; "radeon ai pro"; "quadro"; "rtx pro"; "tesla"; "jetson"; "drive thor"; "rtx spark"; "dgx spark";
    "mini pc"; "handheld"; "arc raiders"; "apu"; "apus"; "ryzen ai"; "cpu"; "cpus"; "procesador"; "procesadores"; "prozessor" ]

(* Marcas de que va de juegos en sobremesa, aunque hable también de otra cosa. *)
let consumo = [ "geforce"; "radeon rx"; "game ready"; "dlss"; "fsr"; "adrenalin"; "founders edition"; "gaming" ]

let tipos =
  [ ("drivers", [ "driver"; "drivers"; "controladores"; "controlador"; "treiber"; "game ready"; "whql"; "adrenalin"; "hotfix" ]);
    ("analisis", [ "review"; "reviewed"; "tested"; "benchmark"; "benchmarks"; "analisis"; "a prueba"; "probamos"; "im test"; "test"; "hands on" ]);
    ("rumor", [ "rumor"; "rumors"; "rumour"; "rumoured"; "rumored"; "reportedly"; "leak"; "leaks"; "leaked"; "allegedly"; "expected";
                "tips"; "spotted"; "filtra"; "filtrado"; "filtracion"; "rumorea"; "llegaria"; "lanzaria"; "habria"; "tendria"; "seria";
                "costaria"; "geruecht"; "geruch"; "gerucht"; "soll"; "sollen"; "angeblich"; "durchgesickert"; "could"; "might"; "likely" ]);
    ("precio", [ "price"; "prices"; "pricing"; "precio"; "precios"; "preis"; "preise"; "deal"; "deals"; "discount"; "oferta"; "ofertas";
                 "rebaja"; "rebajada"; "msrp"; "cheaper"; "barata"; "angebot"; "price hike"; "sube"; "suben"; "subida"; "teurer"; "gunstiger";
                 "cae"; "baja"; "bajan"; "drops"; "price drop"; "fallt"; "euros" ]);
    ("mercado", [ "eol"; "end of life"; "discontinued"; "halts"; "halt"; "ending"; "stock"; "shortage"; "supply"; "lagerware"; "production";
                  "produccion"; "deja de fabricar"; "dejado de fabricar"; "escasez"; "agotada"; "agotadas"; "ausverkauft"; "lieferbar" ]);
    ("lanzamiento", [ "launch"; "launches"; "launched"; "available"; "availability"; "now available"; "on sale"; "release"; "releases";
                      "released"; "lanza"; "lanzamiento"; "disponible"; "a la venta"; "llega"; "llegan"; "erscheint"; "startet";
                      "verfugbar"; "marktstart" ]);
    ("anuncio", [ "announce"; "announces"; "announced"; "unveil"; "unveils"; "unveiled"; "introduces"; "reveals"; "debuts"; "anuncia";
                  "presenta"; "desvela"; "vorgestellt"; "kundigt"; "enthullt"; "offiziell"; "pr" ]) ]

let fabricantes_de texto (l : lectura) =
  let por_modelo = List.map (fun g -> Catalogo.fabricante_texto g.modelo.Catalogo.fabricante) l.modelos in
  let por_nombre =
    List.filter_map
      (fun (f, ws) -> if Texto.contiene texto ws then Some f else None)
      [ ("nvidia", [ "nvidia"; "geforce"; "rtx"; "dlss"; "blackwell" ]); ("amd", [ "amd"; "radeon"; "rdna"; "fsr" ]); ("intel", [ "intel arc"; "arc"; "battlemage"; "celestial"; "xess" ]) ]
  in
  List.sort_uniq compare (por_modelo @ por_nombre)

(* Marcas de que va de juegos en sobremesa, aunque hable también de otra cosa. *)
let consumo = [ "geforce"; "radeon rx"; "game ready"; "dlss"; "fsr"; "adrenalin"; "founders edition"; "gaming" ]

let portatil = [ "laptop"; "laptops"; "portatil"; "portatiles"; "notebook"; "gaming laptop" ]

(* Un modelo del catálogo es de sobremesa: va de gráficas salvo que hable de un portátil. Sin
   modelo, por las palabras; con palabras de los dos lados y marcas de juego, no se sabe. *)
let tema t (l : lectura) =
  if l.modelos <> [] || l.desconocidos <> [] then Some (if Texto.contiene t portatil then "otro" else "graficas")
  else if not (Texto.contiene t gpu) then Some "otro"
  else if not (Texto.contiene t fuera) then Some "graficas"
  else if Texto.contiene t consumo then None
  else Some "otro"

(* Lo que parece una gráfica y no está en el catálogo: un modelo nuevo, o una memoria que no
   tenía el modelo nombrado justo antes («RTX 5080 24 GB»). *)
let nuevos t (l : lectura) =
  let ms = List.filter (fun (x : Texto.mencion) -> x.modelo <> None) (Texto.menciones t) in
  let variantes =
    List.filter_map
      (fun (w, gb) ->
        match List.rev (List.filter (fun (x : Texto.mencion) -> x.palabra <= w) ms) with
        | { modelo = Some m; _ } :: _ when gb >= 4 && not (List.mem gb m.Catalogo.vram) -> Some (m.Catalogo.clave ^ " " ^ string_of_int gb ^ "gb")
        | _ -> None)
      (Texto.memorias_en t)
  in
  List.sort_uniq compare (l.desconocidos @ variantes)

let aplicar entrada : (string, string) result =
  let n = partes entrada in
  let t = n.titulo in
  if String.trim t = "" then Error "sin título"
  else
    match tema t (leer t) with
    | None -> Error "no sé si va de gráficas de sobremesa"
    | Some tema ->
      let graficas = tema = "graficas" in
      let tipo = if graficas then Option.value ~default:"otro" (List.find_map (fun (k, ws) -> if Texto.contiene t ws then Some k else None) tipos) else "otro" in
      let todo = t ^ "\n" ^ n.resumen in
      let lr = leer todo in
      let lista xs = `List (List.map (fun s -> `String s) (if graficas then xs else [])) in
      Ok
        (Yojson.Safe.to_string
           (`Assoc
              [ ("tema", `String tema);
                ("tipo", `String tipo);
                ("fabricantes", lista (fabricantes_de todo lr));
                ("modelos", lista (List.map (fun g -> g.modelo.Catalogo.clave) lr.modelos));
                ("nuevos", lista (nuevos t (leer t))) ]))

let cristal = Cristal.cristal "grafica-noticia" aplicar
