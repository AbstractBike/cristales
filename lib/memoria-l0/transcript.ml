(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type mensaje = {
  ts : string;
  sesion : string;
  uuid : string;
  agente : string;
  proyecto : string;
  rol : string;
  texto : string;
  redacciones : (Redaccion.tipo * int) list;
  truncado : bool;
}

let max_bytes = 8192

(* Lo que mete el arnés o es salida de un comando: fuera con su contenido.
   [bash-input] se queda (lo escribió el usuario) sin las etiquetas. *)
let bloques =
  [ "system-reminder"; "command-name"; "command-message"; "command-args"; "command-contents";
    "local-command-stdout"; "local-command-stderr"; "local-command-caveat"; "bash-stdout"; "bash-stderr";
    "task-notification"; "diagnostics"; "ci-monitor-event"; "user-prompt-submit-hook" ]

let re_bloques =
  Re.compile
    (Re.Perl.re
       (* Re no tiene retroreferencias: cierra cualquiera de la lista. *)
       (let b = String.concat "|" bloques in
        Printf.sprintf {|<(%s)>(.|\n)*?(</(%s)>|\z)|} b b))

let re_bash_input = Re.compile (Re.Perl.re {|</?bash-input>|})
let re_huecos = Re.compile (Re.Perl.re {|\n{3,}|})

let limpiar s =
  let s = Re.replace_string re_bloques ~by:"" s in
  let s = Re.replace_string re_bash_input ~by:"" s in
  String.trim (Re.replace_string re_huecos ~by:"\n\n" s)

(* Ruido que no dice nada del trabajo. *)
let ruido s =
  s = ""
  || String.starts_with ~prefix:"[Request interrupted by user" s
  || String.starts_with ~prefix:"[Image" s
  || s = "No response requested."

let truncar s =
  let n = String.length s in
  if n <= max_bytes then (s, false)
  else
    (* Retrocede hasta el principio de un carácter UTF-8. *)
    let rec corte i = if i > 0 && Char.code s.[i] land 0xC0 = 0x80 then corte (i - 1) else i in
    let i = corte max_bytes in
    (Printf.sprintf "%s […truncado, %d bytes]" (String.sub s 0 i) n, true)

let corto s = s <> "" && String.length s <= 120 && not (String.contains s '\n')

let herramienta nombre input =
  let campos = match input with `Assoc l -> l | _ -> [] in
  let cadena = function `String s -> Some (String.trim s) | _ -> None in
  let desc =
    match Option.bind (List.assoc_opt "description" campos) cadena with
    | Some d when d <> "" -> Some (if String.length d > 200 then fst (truncar (String.sub d 0 200)) else d)
    | _ -> List.find_map (fun (_, v) -> Option.bind (cadena v) (fun s -> if corto s then Some s else None)) campos
  in
  match desc with
  | Some d -> Printf.sprintf "[herramienta %s: %s]" nombre (String.map (fun c -> if c = '\n' then ' ' else c) d)
  | None -> Printf.sprintf "[herramienta %s]" nombre

let cadena j = match j with `String s -> s | _ -> ""

let texto_de_bloques rol bloques =
  List.filter_map
    (fun b ->
      let open Yojson.Safe.Util in
      match cadena (member "type" b) with
      | "text" -> Some (limpiar (cadena (member "text" b)))
      | "tool_use" when rol = "assistant" -> Some (herramienta (cadena (member "name" b)) (member "input" b))
      | _ -> None (* tool_result, image, thinking, document… *))
    bloques
  |> List.filter (fun s -> not (ruido s))
  |> String.concat "\n"

let verdad j k = match Yojson.Safe.Util.member k j with `Bool b -> b | _ -> false

let de_linea linea =
  match Yojson.Safe.from_string linea with
  | exception Yojson.Json_error _ -> None
  | j -> (
      let open Yojson.Safe.Util in
      let campo k = cadena (member k j) in
      let rol = campo "type" in
      if (rol <> "user" && rol <> "assistant") || verdad j "isMeta" || verdad j "isCompactSummary" then None
      else
        let contenido = member "content" (member "message" j) in
        let texto =
          match contenido with
          | `String s -> limpiar s
          | `List bloques -> texto_de_bloques rol bloques
          | _ -> ""
        in
        let ts = campo "timestamp" and sesion = campo "sessionId" and uuid = campo "uuid" in
        if ruido texto || ts = "" || sesion = "" || uuid = "" then None
        else
          let texto, redacciones = Redaccion.redactar texto in
          let texto, truncado = truncar texto in
          Some
            { ts; sesion; uuid; agente = campo "agentId"; proyecto = campo "cwd"; rol; texto; redacciones;
              truncado })
