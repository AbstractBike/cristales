(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let presupuesto = 6000
let tope_persona = 2400
let tope_resumen = 320

(* Retrocede hasta el principio de un carácter UTF-8 (no un byte 10xxxxxx). *)
let rec corte s i = if i > 0 && Char.code s.[i] land 0xC0 = 0x80 then corte s (i - 1) else i

let recortar n s =
  if String.length s <= n then s
  else
    let marca = " […]" in
    let i = corte s (max 0 (n - String.length marca)) in
    String.trim (String.sub s 0 i) ^ marca

(* Una línea: sin saltos ni espacios de más. *)
let en_linea s =
  String.split_on_char '\n' s |> List.map String.trim |> List.filter (( <> ) "") |> String.concat " "

let cabecera repo =
  Printf.sprintf
    "# Memoria de sesiones anteriores\n\n\
     Referencia de lo aprendido en otras sesiones, no el estado de esta tarea. Repo: `%s`, cada escena en `escenas/<slug>.md`. \
     El detalle está en el MCP `memoria`: `memoria_escena` (el Markdown de una escena por su \
     slug), `memoria_buscar` (hechos, reglas y métodos sueltos) y `memoria_conversacion` (lo que \
     se dijo). Búscalo antes de decidir algo que pudo decidirse antes.\n"
    repo

let linea_escena (e : Escenas.t) =
  let resumen = match en_linea e.resumen with "" -> "" | r -> ": " ^ recortar tope_resumen r in
  Printf.sprintf "- **%s** (`%s`)%s\n" (en_linea e.titulo) e.slug resumen

let texto ~repo ~persona escenas =
  if persona = None && escenas = [] then ""
  else
    let b = Buffer.create presupuesto in
    Buffer.add_string b (cabecera repo);
    Option.iter
      (fun p ->
        Buffer.add_string b "\n## Persona\n\n";
        Buffer.add_string b (recortar tope_persona p);
        Buffer.add_char b '\n')
      persona;
    if escenas <> [] then begin
      Buffer.add_string b "\n## Escenas (de más a menos activas)\n\n";
      let total = List.length escenas in
      (* Las que quepan, dejando sitio a la línea de las que faltan. *)
      let reserva = 80 in
      let rec ir n = function
        | [] -> ()
        | e :: resto ->
            let l = linea_escena e in
            if Buffer.length b + String.length l + reserva > presupuesto then
              Buffer.add_string b
                (Printf.sprintf "- (y %d escenas más: `ls escenas/` en el repo)\n" (total - n))
            else (
              Buffer.add_string b l;
              ir (n + 1) resto)
      in
      ir 0 escenas
    end;
    recortar presupuesto (Buffer.contents b)

let salida_hook = function
  | "" -> ""
  | contexto ->
      Yojson.Safe.to_string
        (`Assoc
          [ ( "hookSpecificOutput",
              `Assoc [ ("hookEventName", `String "SessionStart"); ("additionalContext", `String contexto) ] ) ])

let de_repo repo = salida_hook (texto ~repo ~persona:(Escenas.persona repo) (Escenas.indice repo))
