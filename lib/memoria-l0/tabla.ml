(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let nombre = "memoria_l0"

let crear =
  Printf.sprintf
    {|CREATE TABLE IF NOT EXISTS %s (
  ts TIMESTAMP(3) NOT NULL,
  sesion STRING,
  "uuid" STRING,
  agente STRING,
  proyecto STRING,
  nodo STRING,
  rol STRING,
  texto STRING FULLTEXT INDEX WITH (analyzer = 'English', case_sensitive = 'false', backend = 'tantivy'),
  TIME INDEX (ts),
  PRIMARY KEY (sesion, "uuid")
)|}
    nombre

let literal s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '\'';
  String.iter
    (function '\'' -> Buffer.add_string b "''" | '\000' -> () | c -> Buffer.add_char b c)
    s;
  Buffer.add_char b '\'';
  Buffer.contents b

let insertar ~nodo (ms : Transcript.mensaje list) =
  let fila (m : Transcript.mensaje) =
    "("
    ^ String.concat ", " (List.map literal [ m.ts; m.sesion; m.uuid; m.agente; m.proyecto; nodo; m.rol; m.texto ])
    ^ ")"
  in
  Printf.sprintf {|INSERT INTO %s (ts, sesion, "uuid", agente, proyecto, nodo, rol, texto) VALUES %s|} nombre
    (String.concat ",\n" (List.map fila ms))

let lotes ?(max_filas = 500) ?(max_bytes = 1 lsl 20) ms =
  let cerrar actual acc = if actual = [] then acc else List.rev actual :: acc in
  let rec ir acc actual n bytes = function
    | [] -> List.rev (cerrar actual acc)
    | (m : Transcript.mensaje) :: resto ->
        let t = String.length m.texto + 200 in
        if actual <> [] && (n >= max_filas || bytes + t > max_bytes) then ir (cerrar actual acc) [ m ] 1 t resto
        else ir acc (m :: actual) (n + 1) (bytes + t) resto
  in
  ir [] [] 0 0 ms
