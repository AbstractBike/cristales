(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

module Tarea = struct
  type t = string

  let explicita s =
    let valido = function 'a' .. 'z' | '0' .. '9' | '-' -> true | _ -> false in
    if s <> "" && String.length s <= 64 && String.for_all valido s then Ok s
    else Error (Printf.sprintf "nombre de tarea no válido: %S" s)

  let de_plantilla p = "t-" ^ String.sub (Digest.to_hex (Digest.string p)) 0 12
  let to_string t = t
end

type peticion = { tarea : Tarea.t; plantilla : string; entrada : string }
type cristal = (string, string) Cristal.cristal

module Vitrina = struct
  type estado = [ `Mixta | `Cristalina ]
  type pieza = { tarea : Tarea.t; estado : estado; cristal : cristal; descripcion : string }
  module M = Map.Make (String)

  type t = pieza M.t

  let vacia = M.empty

  let con ?(descripcion = "") tarea estado cristal v =
    M.add tarea { tarea; estado; cristal; descripcion } v

  let buscar v tarea = Option.map (fun e -> (e.estado, e.cristal)) (M.find_opt tarea v)
  let listar v = List.map snd (M.bindings v)
end

module Cantera = struct
  type muestra = {
    tarea : Tarea.t;
    plantilla : string;
    entrada : string;
    salida : string;
    contraste : string option;
    defecto : Cristal.motivo option;
  }

  type t = {
    registrar : muestra -> unit;
    muestras : Tarea.t -> muestra list;
  }

  let en_memoria () =
    (* Cada lista se guarda al revés: registrar es O(1). *)
    let h = Hashtbl.create 16 in
    let al_reves t = Option.value ~default:[] (Hashtbl.find_opt h t) in
    let muestras t = List.rev (al_reves t) in
    let registrar m = Hashtbl.replace h m.tarea (m :: al_reves m.tarea) in
    { registrar; muestras }
end

module Madurez = struct
  type politica = {
    minimo : int;
    contrastar_cada : int;
    contrastes : int;
    estabilidad : float;
  }

  let por_defecto =
    { minimo = 20; contrastar_cada = 10; contrastes = 2; estabilidad = 0.9 }

  type informe = { muestras : int; contrastes : int; coincidencias : int }

  let vacio = { muestras = 0; contrastes = 0; coincidencias = 0 }

  let sumar i (m : Cantera.muestra) =
    match m.contraste with
    | None -> { i with muestras = i.muestras + 1 }
    | Some c ->
        { muestras = i.muestras + 1;
          contrastes = i.contrastes + 1;
          coincidencias = (i.coincidencias + if c = m.salida then 1 else 0) }

  let informe = List.fold_left sumar vacio

  let madura p i =
    i.muestras >= p.minimo
    && i.contrastes >= p.contrastes
    && float i.coincidencias >= p.estabilidad *. float i.contrastes
end

module Semilla = struct
  let bloque s = "~~~~\n" ^ s ^ "\n~~~~"

  let ejemplos muestras =
    List.mapi
      (fun i (m : Cantera.muestra) ->
        Printf.sprintf "### %d%s\n\nEntrada:\n\n%s\n\nSalida:\n\n%s" (i + 1)
          (match m.defecto with
          | Some d -> Printf.sprintf " (defecto del cristal: %s)" d
          | None -> "")
          (bloque m.entrada) (bloque m.salida))
      muestras
    |> String.concat "\n\n"

  let plantilla = function
    | [] -> ""
    | (m : Cantera.muestra) :: _ -> m.plantilla

  let markdown tarea (i : Madurez.informe) muestras =
    String.concat "\n"
      [ Printf.sprintf "# Semilla: %s" (Tarea.to_string tarea);
        "";
        "Tarea que atendía el LLM a través de la forja. Sus instrucciones \
         (la plantilla) eran:";
        "";
        bloque (plantilla muestras);
        "";
        "- Entrada: texto (lo que variaba en cada llamada).";
        "- Salida: texto (la respuesta del LLM).";
        "";
        Printf.sprintf
          "Cantera: %d muestras; el LLM repitió la respuesta en %d de %d \
           contrastes."
          i.muestras i.coincidencias i.contrastes;
        "";
        "## Ejemplos";
        "";
        ejemplos muestras;
        "";
        "## Invariantes";
        "";
        "Por declarar en la nucleación.";
        "";
        "## Fuera de dominio (defecto)";
        "";
        "Por declarar en la nucleación.";
        "" ]

  (* Sustituye todas las apariciones de [a] por [b] en [s]. *)
  let reemplazar ~a ~b s =
    let la = String.length a in
    let buf = Buffer.create (String.length s) in
    let rec ir i =
      if i > String.length s - la then
        Buffer.add_string buf (String.sub s i (String.length s - i))
      else if String.sub s i la = a then (
        Buffer.add_string buf b;
        ir (i + la))
      else (
        Buffer.add_char buf s.[i];
        ir (i + 1))
    in
    ir 0;
    Buffer.contents buf

  (* prompts/cristalizar.md lleva una cabecera y un pie separados por
     rayas [---]: el prompt es lo de en medio. Sin rayas, todo. *)
  let cuerpo prompt =
    let raya = "\n---\n" and n = String.length prompt in
    let en i = i + 5 <= n && String.sub prompt i 5 = raya in
    let rec primera i = if i + 5 > n then None else if en i then Some i else primera (i + 1) in
    let rec ultima i = if i < 0 then None else if en i then Some i else ultima (i - 1) in
    match (primera 0, ultima (n - 5)) with
    | Some a, Some b when a < b -> String.trim (String.sub prompt (a + 5) (b - a - 5)) ^ "\n"
    | _ -> prompt

  let nucleacion ~prompt muestras =
    let por_declarar =
      "No las conozco: dedúcelas de la plantilla y los ejemplos y \
       decláralas explícitamente en tu respuesta."
    in
    List.fold_left
      (fun s (a, b) -> reemplazar ~a ~b s)
      (cuerpo prompt)
      [ ("{{descripción en una frase}}",
          "Lo que hacía el LLM con estas instrucciones:\n\n"
          ^ bloque (plantilla muestras));
        ("{{tipo de entrada}}", "texto");
        ("{{tipo de salida}}", "texto");
        ("{{pares entrada → salida, incluidos los raros}}", ejemplos muestras);
        ("{{lista de invariantes}}", por_declarar);
        ("{{lista o descripción}}", por_declarar);
        ("{{entrada}}", "string");
        ("{{salida}}", "string") ]
end

type estado = {
  mutable informe : Madurez.informe;
  mutable llamadas : int;
  mutable avisada : bool;
}

type t = {
  politica : Madurez.politica;
  observar : Cristal.evento -> unit;
  vitrina : Vitrina.t;
  cantera : Cantera.t;
  estados : (Tarea.t, estado) Hashtbl.t;
}

let crear ?(politica = Madurez.por_defecto) ?(observar = ignore) ~vitrina
    ~cantera () =
  { politica; observar; vitrina; cantera; estados = Hashtbl.create 16 }

(* La primera vez que se ve una tarea se recupera lo que ya tenía la
   cantera: la madurez sobrevive a los reinicios del proxy. *)
let estado f tarea =
  match Hashtbl.find_opt f.estados tarea with
  | Some e -> e
  | None ->
      let informe = Madurez.informe (f.cantera.muestras tarea) in
      let e = { informe; llamadas = 0; avisada = false } in
      Hashtbl.add f.estados tarea e;
      e

type decision =
  | Por_cristal of string
  | Al_liquido of { contrastar : bool; defecto : Cristal.motivo option }
  | Fallo of Cristal.fallo

let decidir f p =
  let nombre = Tarea.to_string p.tarea in
  match Vitrina.buscar f.vitrina p.tarea with
  | Some (estado, c) -> (
      match c.aplicar p.entrada with
      | Ok y ->
          f.observar (Por_cristal nombre);
          Por_cristal y
      | Error motivo -> (
          f.observar (Defecto (nombre, motivo));
          match estado with
          | `Mixta -> Al_liquido { contrastar = false; defecto = Some motivo }
          | `Cristalina -> Fallo { etapa = nombre; motivo }))
  | None ->
      f.observar (Por_liquido nombre);
      let e = estado f p.tarea in
      e.llamadas <- e.llamadas + 1;
      let n = f.politica.contrastar_cada in
      Al_liquido { contrastar = n > 0 && e.llamadas mod n = 0; defecto = None }

let aprender f p ?contraste ?defecto salida =
  let m =
    { Cantera.tarea = p.tarea; plantilla = p.plantilla; entrada = p.entrada;
      salida; contraste; defecto }
  in
  let e = estado f p.tarea in
  f.cantera.registrar m;
  e.informe <- Madurez.sumar e.informe m;
  let en_vitrina = Option.is_some (Vitrina.buscar f.vitrina p.tarea) in
  if (not en_vitrina) && (not e.avisada) && Madurez.madura f.politica e.informe
  then (
    e.avisada <- true;
    Some e.informe)
  else None

let informe f tarea = (estado f tarea).informe
let cantera f = f.cantera
