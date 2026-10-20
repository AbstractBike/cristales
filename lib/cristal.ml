(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type motivo = string
type ('i, 'o) forma = { entrada : 'i -> string; salida : 'o -> string }

type ('i, 'o) cristal = {
  nombre : string;
  forma : ('i, 'o) forma;
  aplicar : 'i -> ('o, motivo) result;
}

let cristal nombre forma aplicar = { nombre; forma; aplicar }
let texto = { entrada = Fun.id; salida = Fun.id }

type ('i, 'o) etapa =
  | Liquida of { nombre : string; forma : ('i, 'o) forma; llm : 'i -> 'o }
  | Sombra of { cristal : ('i, 'o) cristal; llm : 'i -> 'o }
  | Mixta of { cristal : ('i, 'o) cristal; llm : 'i -> 'o }
  | Cristalina of ('i, 'o) cristal

type fase = [ `Liquida | `Sombra | `Mixta | `Cristalina ]

let liquida nombre forma llm = Liquida { nombre; forma; llm }
let sombra cristal llm = Sombra { cristal; llm }
let mixta cristal llm = Mixta { cristal; llm }
let cristalina c = Cristalina c

let nombre = function
  | Liquida { nombre; _ } -> nombre
  | Sombra { cristal; _ } | Mixta { cristal; _ } | Cristalina cristal ->
      cristal.nombre

let fase : _ etapa -> fase = function
  | Liquida _ -> `Liquida
  | Sombra _ -> `Sombra
  | Mixta _ -> `Mixta
  | Cristalina _ -> `Cristalina

let solidificar = function
  | Sombra { cristal; llm } -> Mixta { cristal; llm }
  | Mixta { cristal; _ } -> Cristalina cristal
  | e -> e

let fundir = function
  | Sombra { cristal; llm } | Mixta { cristal; llm } ->
      Liquida { nombre = cristal.nombre; forma = cristal.forma; llm }
  | e -> e

type ('i, 'o) t =
  | Etapa : ('i, 'o) etapa -> ('i, 'o) t
  | Seq : ('i, 'm) t * ('m, 'o) t -> ('i, 'o) t

let etapa e = Etapa e
let ( >>> ) a b = Seq (a, b)

type evento =
  | Por_cristal of { etapa : string; entrada : string; salida : string }
  | Por_liquido of { etapa : string; entrada : string; salida : string }
  | Defecto of {
      etapa : string;
      entrada : string;
      motivo : motivo;
      liquido : string option;
    }
  | Comparado of {
      etapa : string;
      entrada : string;
      liquido : string;
      cristal : (string, motivo) result;
    }

let etapa_de = function
  | Por_cristal { etapa; _ }
  | Por_liquido { etapa; _ }
  | Defecto { etapa; _ }
  | Comparado { etapa; _ } ->
      etapa

type fallo = { etapa : string; motivo : motivo }

let ejecutar_etapa observar e x =
  match e with
  | Liquida { nombre; forma; llm } ->
      let y = llm x in
      observar
        (Por_liquido
           { etapa = nombre; entrada = forma.entrada x; salida = forma.salida y });
      Ok y
  | Sombra { cristal = c; llm } ->
      let y = llm x in
      observar
        (Comparado
           {
             etapa = c.nombre;
             entrada = c.forma.entrada x;
             liquido = c.forma.salida y;
             cristal = Result.map c.forma.salida (c.aplicar x);
           });
      Ok y
  | Mixta { cristal = c; llm } -> (
      let entrada = c.forma.entrada x in
      match c.aplicar x with
      | Ok y ->
          observar
            (Por_cristal { etapa = c.nombre; entrada; salida = c.forma.salida y });
          Ok y
      | Error motivo ->
          let y = llm x in
          observar
            (Defecto
               {
                 etapa = c.nombre;
                 entrada;
                 motivo;
                 liquido = Some (c.forma.salida y);
               });
          Ok y)
  | Cristalina c -> (
      let entrada = c.forma.entrada x in
      match c.aplicar x with
      | Ok y ->
          observar
            (Por_cristal { etapa = c.nombre; entrada; salida = c.forma.salida y });
          Ok y
      | Error motivo ->
          observar (Defecto { etapa = c.nombre; entrada; motivo; liquido = None });
          Error { etapa = c.nombre; motivo })

let rec ejecutar : type i o.
    ?observar:(evento -> unit) -> (i, o) t -> i -> (o, fallo) result =
 fun ?(observar = ignore) p x ->
  match p with
  | Etapa e -> ejecutar_etapa observar e x
  | Seq (a, b) -> Result.bind (ejecutar ~observar a x) (ejecutar ~observar b)

let etapas p =
  let rec ir : type i o. (i, o) t -> _ = function
    | Etapa e -> [ (nombre e, fase e) ]
    | Seq (a, b) -> ir a @ ir b
  in
  ir p

module Medidor = struct
  type cuenta = {
    mutable cristal : int;
    mutable total : int;
    mutable coinciden : int;
    mutable comparadas : int;
  }

  type t = (string, cuenta) Hashtbl.t

  let crear () = Hashtbl.create 8

  let cuenta m nombre =
    match Hashtbl.find_opt m nombre with
    | Some c -> c
    | None ->
        let c = { cristal = 0; total = 0; coinciden = 0; comparadas = 0 } in
        Hashtbl.add m nombre c;
        c

  (* Solo [Por_cristal] es una entrada resuelta sin LLM. Un [Defecto] la
     resolvió el LLM (mixta) o nadie (cristalina); una [Comparado] la
     resolvió el LLM aunque el cristal acertara. *)
  let observar m ev =
    let c = cuenta m (etapa_de ev) in
    c.total <- c.total + 1;
    match ev with
    | Por_cristal _ -> c.cristal <- c.cristal + 1
    | Por_liquido _ | Defecto _ -> ()
    | Comparado { liquido; cristal; _ } ->
        c.comparadas <- c.comparadas + 1;
        if cristal = Ok liquido then c.coinciden <- c.coinciden + 1

  let fraccion a b = if b = 0 then None else Some (float a /. float b)

  let grado m nombre =
    Option.bind (Hashtbl.find_opt m nombre) (fun c -> fraccion c.cristal c.total)

  let grado_total m =
    let cristal, total =
      Hashtbl.fold (fun _ c (a, b) -> (a + c.cristal, b + c.total)) m (0, 0)
    in
    fraccion cristal total

  let acuerdo m nombre =
    Option.bind (Hashtbl.find_opt m nombre) (fun c ->
        fraccion c.coinciden c.comparadas)

  let etapas m = Hashtbl.fold (fun n _ acc -> n :: acc) m [] |> List.sort compare
end
