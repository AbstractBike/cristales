(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* Cristal: las gráficas que nombra un texto, con sus datos del catálogo. Ver
   SEMILLA.md. *)

module Catalogo = Catalogo
module Texto = Texto

type gpu = { modelo : Catalogo.modelo; vram : int }

type lectura = {
  modelos : gpu list;  (** Las del catálogo, una vez cada una, en el orden del texto. *)
  desconocidos : string list;  (** Parecen gráficas y no están en el catálogo («rtx 4060 super»). *)
  antiguas : string list;  (** De antes del catálogo (Radeon HD, GeForce FX, GTX 580…). *)
  profesionales : string list;  (** Quadro, Radeon Pro, FirePro… *)
}

let leer texto =
  let ms = Texto.menciones texto in
  let unicos f = List.sort_uniq compare (List.filter_map f ms) in
  let modelos =
    List.fold_left
      (fun acc (x : Texto.mencion) ->
        match x.modelo with
        | Some m when not (List.exists (fun g -> g.modelo.clave = m.clave) acc) -> acc @ [ { modelo = m; vram = Texto.memoria_de m texto } ]
        | _ -> acc)
      [] ms
  in
  {
    modelos;
    desconocidos = unicos (fun (x : Texto.mencion) -> if x.modelo = None && not (x.antigua || x.profesional) then Some x.leido else None);
    antiguas = unicos (fun (x : Texto.mencion) -> if x.antigua then Some x.leido else None);
    profesionales = unicos (fun (x : Texto.mencion) -> if x.profesional then Some x.leido else None);
  }

let json_gpu { modelo = m; vram } : Yojson.Safe.t =
  `Assoc
    [ ("modelo", `String m.clave);
      ("nombre", `String m.nombre);
      ("fabricante", `String (Catalogo.fabricante_texto m.fabricante));
      ("vram", `Int vram);
      ("anyo", `Int m.anyo);
      ("pvp", match m.pvp with Some p -> `Int p | None -> `Null);
      ("rendimiento", `Int m.rendimiento) ]

let lista xs = `List (List.map (fun s -> `String s) xs)

let aplicar texto : (string, string) result =
  let l = leer texto in
  match (l.modelos, l.desconocidos, l.antiguas, l.profesionales) with
  | [], [], [], [] -> Error "no nombra ninguna gráfica"
  | [], d :: _, _, _ -> Error ("modelo desconocido: " ^ d)
  | _ ->
    Ok
      (Yojson.Safe.to_string
         (`Assoc
            [ ("modelos", `List (List.map json_gpu l.modelos));
              ("desconocidos", lista l.desconocidos);
              ("antiguas", lista l.antiguas);
              ("profesionales", lista l.profesionales) ]))

let cristal = Cristal.cristal "grafica-modelo" aplicar
