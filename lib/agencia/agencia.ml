(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

module Modelo = struct
  type api = Anthropic | Openai
  type t = { nombre : string; api : api }

  let prefijo = "openai:"

  let de_texto s =
    let s = String.trim s in
    let api, nombre =
      if String.starts_with ~prefix:prefijo s then
        (Openai, String.sub s (String.length prefijo) (String.length s - String.length prefijo))
      else (Anthropic, s)
    in
    if nombre = "" || String.exists (fun c -> c = ' ' || c = ',' || c = '\n') nombre then
      Error (s ^ ": no es un nombre de modelo")
    else Ok { nombre; api }

  let to_string m = match m.api with Anthropic -> m.nombre | Openai -> prefijo ^ m.nombre
end

module Agente = struct
  type t = {
    nombre : Forja.Tarea.t;
    descripcion : string;
    instrucciones : string;
    escalera : Modelo.t list;
    defecto : Modelo.t;
    max_tokens : int;
  }

  let crear ~nombre ?(descripcion = "") ~instrucciones ~escalera ?defecto ?(max_tokens = 4096) () =
    match (Forja.Tarea.explicita nombre, List.rev escalera) with
    | Error e, _ -> Error e
    | _, [] -> Error "la escalera de modelos está vacía"
    | Ok nombre, mas_capaz :: _ -> (
        let defecto = Option.value ~default:mas_capaz defecto in
        if String.trim instrucciones = "" then Error "faltan las instrucciones"
        else if max_tokens < 1 then Error "max_tokens: al menos 1"
        else
          match List.find_opt (( = ) defecto) escalera with
          | None -> Error (Modelo.to_string defecto ^ ": el modelo por defecto no está en la escalera")
          | Some _ -> Ok { nombre; descripcion; instrucciones; escalera; defecto; max_tokens })

  let version a = String.sub (Digest.to_hex (Digest.string a.instrucciones)) 0 12
end

type respuesta = {
  salida : (string, string) result;
  fuente : string;
  ms : int;
  tokens_entrada : int;
  tokens_salida : int;
}

let sin_respuesta = "sin-respuesta"

type veredicto = Bien | Mal

let veredicto_de_texto = function "bien" -> Some Bien | "mal" -> Some Mal | _ -> None
let veredicto_a_texto = function Bien -> "bien" | Mal -> "mal"

module Encargo = struct
  type t = {
    id : string;
    agente : Forja.Tarea.t;
    version : string;
    modelo : string;
    motivo : string;
    fuente : string;
    entrada : string;
    salida : (string, string) result;
    ms : int;
    tokens_entrada : int;
    tokens_salida : int;
    veredicto : veredicto option;
    nota : string;
  }

  let id_valido s =
    String.length s = 16 && String.for_all (function '0' .. '9' | 'a' .. 'f' -> true | _ -> false) s
end

module Archivo = struct
  type t = {
    guardar : Agente.t -> unit;
    agentes : unit -> Agente.t list;
    registrar : Encargo.t -> unit;
    juzgar : Forja.Tarea.t -> string -> veredicto -> string -> unit;
    historial : Forja.Tarea.t -> Encargo.t list;
  }

  let en_memoria () =
    let agentes = Hashtbl.create 16 and encargos = ref [] in
    let juzgar _ id v nota =
      encargos :=
        List.map
          (fun (e : Encargo.t) -> if e.id = id then { e with veredicto = Some v; nota } else e)
          !encargos
    in
    { guardar = (fun (a : Agente.t) -> Hashtbl.replace agentes a.nombre a);
      agentes =
        (fun () ->
          Hashtbl.to_seq_values agentes |> List.of_seq
          |> List.sort (fun (a : Agente.t) b -> compare a.nombre b.nombre));
      registrar = (fun e -> encargos := e :: !encargos);
      juzgar;
      historial = (fun t -> List.rev (List.filter (fun (e : Encargo.t) -> e.agente = t) !encargos)) }
end

module Politica = struct
  type t = { juicios : int; acierto : float; explorar_cada : int }

  let por_defecto = { juicios = 3; acierto = 0.8; explorar_cada = 5 }
end

type nivel = Fiable | Descartado | Por_ver

type cuenta = {
  modelo : Modelo.t;
  encargos : int;
  errores : int;
  juzgados : int;
  bien : int;
  ms_medio : int;
  tokens : int;
  nivel : nivel;
}

let cuenta (p : Politica.t) modelo (es : Encargo.t list) =
  let es = List.filter (fun (e : Encargo.t) -> e.modelo = Modelo.to_string modelo) es in
  let n = List.length es in
  (* Lo que no llegó al modelo no dice nada de él. *)
  let es = List.filter (fun (e : Encargo.t) -> e.fuente <> sin_respuesta) es in
  let errores = List.length (List.filter (fun (e : Encargo.t) -> Result.is_error e.salida) es) in
  (* Un error es un mal sin que haga falta juzgarlo. *)
  let juzgados =
    List.length
      (List.filter (fun (e : Encargo.t) -> Result.is_error e.salida || e.veredicto <> None) es)
  in
  let bien =
    List.length
      (List.filter (fun (e : Encargo.t) -> Result.is_ok e.salida && e.veredicto = Some Bien) es)
  in
  let suma f = List.fold_left (fun s e -> s + f e) 0 es in
  let nivel =
    if juzgados < p.juicios then Por_ver
    else if float_of_int bien >= p.acierto *. float_of_int juzgados then Fiable
    else Descartado
  in
  { modelo;
    encargos = n;
    errores;
    juzgados;
    bien;
    ms_medio = (if n = 0 then 0 else suma (fun e -> e.ms) / n);
    tokens = suma (fun e -> e.tokens_entrada + e.tokens_salida);
    nivel }

let actuales (a : Agente.t) es =
  let v = Agente.version a in
  List.filter (fun (e : Encargo.t) -> e.version = v) es

let cuentas ?(politica = Politica.por_defecto) (a : Agente.t) es =
  let es = actuales a es in
  List.map (fun m -> cuenta politica m es) a.escalera

type eleccion = { modelo : Modelo.t; motivo : string }

(* Los peldaños desde [desde] hacia arriba (incluido). *)
let rec desde m : cuenta list -> cuenta list = function
  | [] -> []
  | c :: _ as l when c.modelo = m -> l
  | _ :: l -> desde m l

let elegir ?(politica = Politica.por_defecto) (a : Agente.t) es =
  let cs = cuentas ~politica a es in
  let base =
    match List.find_opt (fun c -> c.nivel = Fiable) cs with
    | Some c ->
        { modelo = c.modelo;
          motivo = Printf.sprintf "el más barato fiable (%d de %d bien)" c.bien c.juzgados }
    | None -> (
        (* Desde el de por defecto hacia arriba y, si no queda nada, hacia
           abajo. *)
        let arriba = desde a.defecto cs in
        let abajo = List.rev (List.filteri (fun i _ -> i < List.length cs - List.length arriba) cs) in
        match List.find_opt (fun c -> c.nivel <> Descartado) (arriba @ abajo) with
        | Some c when c.modelo = a.defecto -> { modelo = c.modelo; motivo = "el de por defecto, aún sin un fiable" }
        | Some c ->
            { modelo = c.modelo;
              motivo = Printf.sprintf "%s descartado, el siguiente que no lo está" (Modelo.to_string a.defecto) }
        | None ->
            let c = List.nth cs (List.length cs - 1) in
            { modelo = c.modelo; motivo = "todos descartados, el más capaz" })
  in
  let rec por_debajo : cuenta list -> cuenta list = function
    | [] -> []
    | c :: _ when c.modelo = base.modelo -> []
    | c :: l -> c :: por_debajo l
  in
  let explorar = List.length (actuales a es) mod politica.explorar_cada = politica.explorar_cada - 1 in
  match List.find_opt (fun c -> c.nivel = Por_ver) (por_debajo cs) with
  | Some c when explorar ->
      { modelo = c.modelo;
        motivo = Printf.sprintf "explorando uno más barato que %s (%s)" (Modelo.to_string base.modelo) base.motivo }
  | _ -> base
