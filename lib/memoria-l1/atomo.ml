(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type tipo = Persona | Regla | Hecho | Metodo | Episodio

let tipo_de_texto s =
  match String.lowercase_ascii (String.trim s) with
  | "persona" -> Some Persona
  | "regla" -> Some Regla
  | "hecho" -> Some Hecho
  | "metodo" | "método" | "mÉtodo" -> Some Metodo
  | "episodio" -> Some Episodio
  | _ -> None

let tipo_a_texto = function
  | Persona -> "persona"
  | Regla -> "regla"
  | Hecho -> "hecho"
  | Metodo -> "metodo"
  | Episodio -> "episodio"

(* Los mismos cortes que dicen las instrucciones de memoria-atomos. *)
let umbral = function Persona -> 50 | Regla -> 70 | Hecho | Metodo | Episodio -> 60

let conservar tipo p = p >= umbral tipo || (tipo = Regla && p = -1)

let prioridad_valida p = max (-1) (min 100 p)

type mensaje = { sesion : string; uuid : string; ts : int; proyecto : string; rol : string; texto : string }

let origen m = m.sesion ^ "/" ^ m.uuid

(* Días desde 1970-01-01 a fecha civil (Howard Hinnant, days_from_civil
   al revés): sin Unix, para que el núcleo siga siendo puro. *)
let civil dias =
  let z = dias + 719468 in
  let era = (if z >= 0 then z else z - 146096) / 146097 in
  let doe = z - (era * 146097) in
  let yoe = (doe - (doe / 1460) + (doe / 36524) - (doe / 146096)) / 365 in
  let y = yoe + (era * 400) in
  let doy = doe - ((365 * yoe) + (yoe / 4) - (yoe / 100)) in
  let mp = ((5 * doy) + 2) / 153 in
  let d = doy - (((153 * mp) + 2) / 5) + 1 in
  let m = if mp < 10 then mp + 3 else mp - 9 in
  ((if m <= 2 then y + 1 else y), m, d)

let dia_ms = 86_400_000

let partes ms =
  let dias = if ms >= 0 then ms / dia_ms else ((ms + 1) / dia_ms) - 1 in
  let resto = ms - (dias * dia_ms) in
  (civil dias, resto / 3_600_000, resto / 60_000 mod 60)

let fecha ms =
  let (y, m, d), _, _ = partes ms in
  Printf.sprintf "%04d-%02d-%02d" y m d

let hora ms =
  let (y, m, d), h, mi = partes ms in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d" y m d h mi

type nuevo = {
  contenido : string;
  tipo : tipo;
  prioridad : int;
  escena : string;
  proyecto : string;
  origen : string list;
  fechas : string list;
}

type t = {
  id : string;
  version : int;
  vigente : bool;
  tipo : tipo;
  prioridad : int;
  escena : string;
  contenido : string;
  proyecto : string;
  origen : string list;
  fechas : string list;
}

let id_de (n : nuevo) =
  "a-" ^ String.sub (Digest.to_hex (Digest.string (n.contenido ^ "\000" ^ String.concat "," n.origen))) 0 12

let de_nuevo (n : nuevo) =
  { id = id_de n;
    version = 1;
    vigente = true;
    tipo = n.tipo;
    prioridad = n.prioridad;
    escena = n.escena;
    contenido = n.contenido;
    proyecto = n.proyecto;
    origen = n.origen;
    fechas = n.fechas }

let union a b = List.sort_uniq String.compare (a @ b)
