(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let max_caracteres = 2000
let umbral_atomos = 50

let cambiadas ~ultima escenas =
  let escenas = List.filter (fun (e : Escena.t) -> e.cuerpo <> "") escenas in
  match ultima with
  | None -> escenas
  | Some u -> List.filter (fun (e : Escena.t) -> e.actualizada > u) escenas

let disparo ~ultima ~escenas ~senal ~atomos_desde =
  match senal with
  | Some m -> Some ("señal de la consolidación: " ^ (if m = "" then "sin motivo" else m))
  | None -> (
      match cambiadas ~ultima escenas with
      | _ :: _ as c ->
          Some
            (Printf.sprintf "%d escenas nuevas o actualizadas: %s" (List.length c)
               (String.concat ", " (List.map (fun (e : Escena.t) -> e.slug) c)))
      | [] when atomos_desde >= umbral_atomos -> Some (Printf.sprintf "%d átomos nuevos" atomos_desde)
      | [] -> None)

let entrada ~reglas ~actual ~motivo ~cambiadas ~resto =
  let b = Buffer.create 16384 in
  let p fmt = Printf.bprintf b fmt in
  if String.trim reglas <> "" then
    p "## Reglas vigentes (máxima prioridad)\n\nEl CLAUDE.md y el AGENTS.md de hoy: mandan sobre las escenas y la persona actual. Lo que los contradiga no entra como regla.\n\n%s\n\n" (String.trim reglas);
  p "## Persona actual\n\n%s\n\n" (if String.trim actual = "" then "(vacía: es la primera)" else String.trim actual);
  p "## Motivo\n\n%s\n\n## Escenas cambiadas\n\n" motivo;
  List.iter (fun (e : Escena.t) -> p "### %s\n\n%s\n" e.titulo (Escena.a_texto e)) cambiadas;
  p "## Resto de escenas\n\n";
  if resto = [] then p "(ninguna)\n";
  List.iter (fun (e : Escena.t) -> p "- %s: %s\n" e.titulo e.resumen) resto;
  Buffer.contents b

(* Quita un bloque de código que envuelva toda la salida. *)
let desenvolver s =
  let s = String.trim s in
  let lineas = String.split_on_char '\n' s in
  match lineas with
  | p :: (_ :: _ as resto) when String.length p >= 3 && String.sub p 0 3 = "```" -> (
      match List.rev resto with
      | u :: medio when String.trim u = "```" -> String.trim (String.concat "\n" (List.rev medio))
      | _ -> s)
  | _ -> s

let validar salida =
  let s = desenvolver salida in
  let n = Escena.longitud s in
  if s = "" then Error "la persona está vacía"
  else if n > max_caracteres then
    Error (Printf.sprintf "la persona tiene %d caracteres: el máximo es %d, condénsala" n max_caracteres)
  else Ok s
