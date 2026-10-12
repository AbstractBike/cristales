(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: los SSD que nombra un texto, con sus datos del catálogo y la
   capacidad que dice. Ver SEMILLA.md. *)

module Catalogo = Catalogo
module Texto = Texto

type ssd = {
  modelo : Catalogo.modelo;
  capacidad : int option;  (** GB nominales: la del texto, o la que es de las suyas. *)
  tbw : int option;  (** La de esa capacidad, si el catálogo la sabe. *)
  formato : string;
}

type lectura = {
  modelos : ssd list;  (** Los del catálogo, una vez cada uno, en el orden del texto. *)
  desconocidos : string list;  (** Una marca y algo que parece un modelo, sin estar en el catálogo («fikwot fx991»). *)
  capacidades : int list;  (** Las del texto, nominales. *)
  interfaz : Texto.interfaz_leida;
  formato : string option;  (** El que dice el texto. *)
  marcas : string list;
  enterprise : bool;  (** El texto habla de un disco de servidor. *)
}

(* La capacidad de [m]: la primera del texto que es de las suyas; si no, la primera. *)
let capacidad_de (m : Catalogo.modelo) caps =
  let suya c = List.find_opt (fun (k, _) -> Texto.casi k c) m.capacidades in
  match List.find_map suya caps with
  | Some (k, t) -> (Some k, t)
  | None -> (match caps with c :: _ -> (Some c, None) | [] -> (None, None))

let formato_de (m : Catalogo.modelo) leido =
  match leido with
  | Some f when List.mem f m.formatos -> f
  | Some "m2" -> (match List.find_opt (fun f -> String.length f > 3 && String.sub f 0 3 = "m2-") m.formatos with Some f -> f | None -> List.hd m.formatos)
  | Some (("u2" | "u3") as f) when List.exists (fun g -> g = "u2" || g = "u3") m.formatos -> f
  | _ -> List.hd m.formatos

(* Entre los que comparten alias (Micron 7450 PRO y MAX), el que tiene esa capacidad. *)
let elige (ms : Catalogo.modelo list) caps =
  match ms with
  | [ x ] -> x
  | x :: _ ->
    (match List.find_opt (fun (m : Catalogo.modelo) -> List.exists (fun c -> List.exists (fun (k, _) -> Texto.casi k c) m.capacidades) caps) ms with
     | Some m -> m
     | None -> x)
  | [] -> invalid_arg "elige"

let leer texto =
  let caps = List.map Texto.nominal (Texto.capacidades texto) in
  let formato = Texto.formato texto in
  let modelos =
    List.fold_left
      (fun acc (x : Texto.mencion) ->
        let m = elige x.modelos caps in
        if List.exists (fun s -> s.modelo.Catalogo.clave = m.clave) acc then acc
        else
          let capacidad, tbw = capacidad_de m caps in
          acc @ [ { modelo = m; capacidad; tbw; formato = formato_de m formato } ])
      [] (Texto.menciones texto)
  in
  {
    modelos;
    desconocidos = (if modelos = [] then Texto.desconocidos texto else []);
    capacidades = caps;
    interfaz = Texto.interfaz texto;
    formato;
    marcas = Texto.marcas texto;
    enterprise = Texto.enterprise texto || (match formato with Some ("u2" | "u3" | "e1s" | "e1l" | "e3s") -> true | _ -> false);
  }

let opt f = function Some x -> f x | None -> `Null

let json_ssd { modelo = m; capacidad; tbw; formato } : Yojson.Safe.t =
  `Assoc
    [ ("modelo", `String m.clave);
      ("nombre", `String m.nombre);
      ("marca", `String m.marca);
      ("segmento", `String (Catalogo.segmento_texto m.segmento));
      ("interfaz", `String (Catalogo.interfaz_texto m.interfaz));
      ("formato", `String formato);
      ("dram", `String (Catalogo.dram_texto m.dram));
      ("nand", `String (Catalogo.nand_texto m.nand));
      ("controladora", if m.controladora = "" then `Null else `String m.controladora);
      ("plp", `Bool m.plp);
      ("capacidad", opt (fun c -> `Int c) capacidad);
      ("tbw", opt (fun t -> `Int t) tbw);
      ("anyo", `Int m.anyo);
      ("lectura", opt (fun l -> `Int l) m.lectura) ]

let lista xs = `List (List.map (fun s -> `String s) xs)

let interfaz_texto (i : Texto.interfaz_leida) =
  match i.pcie with
  | Some n -> Some ("pcie" ^ string_of_int n)
  | None -> if i.sas then Some "sas" else if i.sata && not i.nvme then Some "sata" else None

let aplicar texto : (string, string) result =
  let l = leer texto in
  match (l.modelos, l.desconocidos) with
  | [], [] -> Error "no nombra ningún modelo de SSD"
  | [], d :: _ -> Error ("modelo desconocido: " ^ d)
  | _ ->
    Ok
      (Yojson.Safe.to_string
         (`Assoc
            [ ("modelos", `List (List.map json_ssd l.modelos));
              ("desconocidos", lista l.desconocidos);
              ("capacidades", `List (List.map (fun c -> `Int c) l.capacidades));
              ("interfaz", opt (fun s -> `String s) (interfaz_texto l.interfaz));
              ("formato", opt (fun s -> `String s) l.formato);
              ("marcas", lista l.marcas) ]))

let cristal = Cristal.cristal "nvme-modelo" aplicar
