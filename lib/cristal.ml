(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type motivo = string
type ('i, 'o) cristal = { nombre : string; aplicar : 'i -> ('o, motivo) result }

let cristal nombre aplicar = { nombre; aplicar }

type ('i, 'o) etapa =
  | Liquida of { nombre : string; llm : 'i -> 'o }
  | Mixta of { cristal : ('i, 'o) cristal; llm : 'i -> 'o }
  | Cristalina of ('i, 'o) cristal

let liquida nombre llm = Liquida { nombre; llm }
let mixta cristal llm = Mixta { cristal; llm }
let cristalina c = Cristalina c

let nombre = function
  | Liquida { nombre; _ } -> nombre
  | Mixta { cristal; _ } | Cristalina cristal -> cristal.nombre

let solidificar = function Mixta { cristal; _ } -> Cristalina cristal | e -> e

let fundir = function
  | Mixta { cristal; llm } -> Liquida { nombre = cristal.nombre; llm }
  | e -> e

type ('i, 'o) t =
  | Etapa : ('i, 'o) etapa -> ('i, 'o) t
  | Seq : ('i, 'm) t * ('m, 'o) t -> ('i, 'o) t

let etapa e = Etapa e
let ( >>> ) a b = Seq (a, b)

type evento =
  | Por_cristal of string
  | Por_liquido of string
  | Defecto of string * motivo

type fallo = { etapa : string; motivo : motivo }

let ejecutar_etapa observar e x =
  match e with
  | Liquida { nombre; llm } ->
      observar (Por_liquido nombre);
      Ok (llm x)
  | Mixta { cristal; llm } -> (
      match cristal.aplicar x with
      | Ok y ->
          observar (Por_cristal cristal.nombre);
          Ok y
      | Error motivo ->
          observar (Defecto (cristal.nombre, motivo));
          Ok (llm x))
  | Cristalina cristal -> (
      match cristal.aplicar x with
      | Ok y ->
          observar (Por_cristal cristal.nombre);
          Ok y
      | Error motivo ->
          observar (Defecto (cristal.nombre, motivo));
          Error { etapa = cristal.nombre; motivo })

let rec ejecutar : type i o.
    ?observar:(evento -> unit) -> (i, o) t -> i -> (o, fallo) result =
 fun ?(observar = ignore) p x ->
  match p with
  | Etapa e -> ejecutar_etapa observar e x
  | Seq (a, b) -> Result.bind (ejecutar ~observar a x) (ejecutar ~observar b)

let etapas p =
  let estado = function
    | Liquida _ -> `Liquida
    | Mixta _ -> `Mixta
    | Cristalina _ -> `Cristalina
  in
  let rec ir : type i o. (i, o) t -> _ = function
    | Etapa e -> [ (nombre e, estado e) ]
    | Seq (a, b) -> ir a @ ir b
  in
  ir p

module Medidor = struct
  type cuenta = { mutable cristal : int; mutable total : int }
  type t = (string, cuenta) Hashtbl.t

  let crear () = Hashtbl.create 8

  let cuenta m nombre =
    match Hashtbl.find_opt m nombre with
    | Some c -> c
    | None ->
        let c = { cristal = 0; total = 0 } in
        Hashtbl.add m nombre c;
        c

  (* Un [Defecto] no cierra la entrada: le sigue el LLM (mixta) o un fallo
     (cristalina). En ambos casos esa entrada no la resolvió el cristal, así
     que cuenta en el total pero no como cristal. *)
  let observar m = function
    | Por_cristal n ->
        let c = cuenta m n in
        c.cristal <- c.cristal + 1;
        c.total <- c.total + 1
    | Por_liquido n | Defecto (n, _) ->
        let c = cuenta m n in
        c.total <- c.total + 1

  let fraccion { cristal; total } =
    if total = 0 then None else Some (float cristal /. float total)

  let grado m nombre = Option.bind (Hashtbl.find_opt m nombre) fraccion

  let grado_total m =
    fraccion
      (Hashtbl.fold
         (fun _ c acc ->
           { cristal = acc.cristal + c.cristal; total = acc.total + c.total })
         m { cristal = 0; total = 0 })
end
