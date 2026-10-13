(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type t = {
  slug : string;
  titulo : string;
  resumen : string;
  creada : string;
  actualizada : string;
  calor : int;
  bloqueada : bool;
  atomos : string list;
  extra : (string * string) list;
  cuerpo : string;
}

let max_cuerpo = 1500

let longitud s =
  let n = ref 0 in
  String.iter (fun c -> if Char.code c land 0xC0 <> 0x80 then incr n) s;
  !n

let slug_valido s =
  let n = String.length s in
  n > 0 && n <= 60
  && String.for_all (function 'a' .. 'z' | '0' .. '9' | '-' -> true | _ -> false) s
  && s.[0] <> '-'
  && s.[n - 1] <> '-'

(* Un valor de cabecera es de una línea. *)
let una_linea s = String.trim (String.map (function '\n' | '\r' -> ' ' | c -> c) s)

let lista s =
  let s = String.trim s in
  let s =
    if String.length s >= 2 && s.[0] = '[' && s.[String.length s - 1] = ']' then String.sub s 1 (String.length s - 2)
    else s
  in
  String.split_on_char ',' s |> List.map String.trim |> List.filter (( <> ) "")

let si = function "true" | "sí" | "si" | "yes" -> true | _ -> false

(* Separa cabecera y cuerpo: la cabecera va entre la primera línea [---]
   y la siguiente. *)
let partir texto =
  let lineas = String.split_on_char '\n' texto in
  match lineas with
  | primera :: resto when String.trim primera = "---" ->
      let rec hasta acc = function
        | [] -> None
        | l :: r when String.trim l = "---" -> Some (List.rev acc, String.concat "\n" r)
        | l :: r -> hasta (l :: acc) r
      in
      hasta [] resto
  | _ -> None

let de_texto ~slug texto =
  let vacia =
    { slug; titulo = slug; resumen = ""; creada = ""; actualizada = ""; calor = 1; bloqueada = false; atomos = [];
      extra = []; cuerpo = String.trim texto }
  in
  match partir texto with
  | None -> Ok vacia
  | Some (cabecera, cuerpo) ->
      let e = { vacia with cuerpo = String.trim cuerpo } in
      List.fold_left
        (fun acc linea ->
          Result.bind acc (fun e ->
              if String.trim linea = "" then Ok e
              else
                match String.index_opt linea ':' with
                | None -> Error (Printf.sprintf "%s: línea de cabecera sin «clave:»: %s" slug linea)
                | Some i -> (
                    let k = String.trim (String.sub linea 0 i)
                    and v = String.trim (String.sub linea (i + 1) (String.length linea - i - 1)) in
                    match k with
                    | "titulo" -> Ok { e with titulo = v }
                    | "resumen" -> Ok { e with resumen = v }
                    | "creada" -> Ok { e with creada = v }
                    | "actualizada" -> Ok { e with actualizada = v }
                    | "calor" -> (
                        match int_of_string_opt v with
                        | Some c -> Ok { e with calor = c }
                        | None -> Error (Printf.sprintf "%s: calor no es un entero: %s" slug v))
                    | "bloqueada" -> Ok { e with bloqueada = si (String.lowercase_ascii v) }
                    | "atomos" -> Ok { e with atomos = lista v }
                    | _ -> Ok { e with extra = e.extra @ [ (k, v) ] })))
        (Ok e) cabecera

let a_texto e =
  let b = Buffer.create (String.length e.cuerpo + 256) in
  let campo k v = Buffer.add_string b (Printf.sprintf "%s: %s\n" k v) in
  Buffer.add_string b "---\n";
  campo "titulo" (una_linea e.titulo);
  campo "resumen" (una_linea e.resumen);
  campo "creada" e.creada;
  campo "actualizada" e.actualizada;
  campo "calor" (string_of_int e.calor);
  campo "bloqueada" (string_of_bool e.bloqueada);
  campo "atomos" ("[" ^ String.concat ", " e.atomos ^ "]");
  List.iter (fun (k, v) -> campo k (una_linea v)) e.extra;
  Buffer.add_string b "---\n\n";
  Buffer.add_string b (String.trim e.cuerpo);
  Buffer.add_char b '\n';
  Buffer.contents b

let recortar ?(max = max_cuerpo) cuerpo =
  let cuerpo = String.trim cuerpo in
  if longitud cuerpo <= max then cuerpo
  else
    (* Se quitan líneas enteras desde el final, y los encabezados que se
       queden sin nada debajo. *)
    let rec quitar = function
      | l :: r when String.trim l = "" || (String.length (String.trim l) > 0 && (String.trim l).[0] = '#') -> quitar r
      | l -> l
    in
    let rec ir lineas_rev =
      let t = String.concat "\n" (List.rev lineas_rev) in
      if longitud t <= max then t
      else match lineas_rev with [] -> "" | _ :: r -> ir (quitar r)
    in
    ir (quitar (List.rev (String.split_on_char '\n' cuerpo)))

let sin_trayectoria cuerpo =
  let lineas = String.split_on_char '\n' cuerpo |> List.map String.trim in
  let es_titulo l = String.length l >= 3 && String.sub l 0 3 = "## " in
  let rec ir dentro acc = function
    | [] -> List.rev acc
    | l :: r when es_titulo l -> ir (String.lowercase_ascii l = "## trayectoria") (if String.lowercase_ascii l = "## trayectoria" then acc else l :: acc) r
    | _ :: r when dentro -> ir dentro acc r
    | l :: r -> ir dentro (if l = "" then acc else l :: acc) r
  in
  String.concat "\n" (ir false [] lineas)
