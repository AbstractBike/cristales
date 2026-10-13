(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* La primera aparición de [sub] en [s] desde [desde]. *)
let indice s sub desde =
  let n = String.length s and m = String.length sub in
  let rec ir i = if i + m > n then None else if String.sub s i m = sub then Some i else ir (i + 1) in
  ir desde

(* Quita los <think>…</think> cerrados. Uno sin cerrar (cortado por
   max_tokens) se queda: lo que se lea de él casi seguro no será el JSON
   pedido y el encargo saldrá mal, que es lo que fue. *)
let sin_pensar s =
  let abre = "<think>" and cierra = "</think>" in
  let rec quitar s =
    match indice s abre 0 with
    | None -> s
    | Some i -> (
        match indice s cierra i with
        | None -> s
        | Some j ->
            let fin = j + String.length cierra in
            quitar (String.sub s 0 i ^ String.sub s fin (String.length s - fin)))
  in
  quitar s

(* Desde la primera llave o corchete, el valor que cierra a su nivel,
   saltando lo que va entre comillas. *)
let candidato s =
  let n = String.length s in
  let rec inicio i = if i >= n then None else match s.[i] with '{' | '[' -> Some i | _ -> inicio (i + 1) in
  match inicio 0 with
  | None -> None
  | Some i0 ->
      let rec andar i nivel en_cadena escapado =
        if i >= n then None
        else
          let c = s.[i] in
          if en_cadena then
            if escapado then andar (i + 1) nivel true false
            else if c = '\\' then andar (i + 1) nivel true true
            else if c = '"' then andar (i + 1) nivel false false
            else andar (i + 1) nivel true false
          else
            match c with
            | '"' -> andar (i + 1) nivel true false
            | '{' | '[' -> andar (i + 1) (nivel + 1) false false
            | '}' | ']' -> if nivel = 1 then Some (String.sub s i0 (i - i0 + 1)) else andar (i + 1) (nivel - 1) false false
            | _ -> andar (i + 1) nivel false false
      in
      andar i0 0 false false

let extraer respuesta =
  match candidato (sin_pensar respuesta) with
  | None -> Error "la respuesta no trae JSON"
  | Some j -> ( try Ok (Yojson.Safe.from_string j) with Yojson.Json_error e -> Error ("JSON inválido: " ^ e))

let campo j k = match j with `Assoc l -> List.assoc_opt k l | _ -> None

let texto j k =
  match campo j k with Some (`String s) when String.trim s <> "" -> Some (String.trim s) | _ -> None

let entero j k =
  match campo j k with
  | Some (`Int n) -> Some n
  | Some (`Float f) -> Some (int_of_float f)
  | Some (`String s) -> int_of_string_opt (String.trim s)
  | _ -> None

let textos j k =
  match campo j k with
  | Some (`List l) -> List.filter_map (function `String s when String.trim s <> "" -> Some (String.trim s) | _ -> None) l
  | _ -> []
