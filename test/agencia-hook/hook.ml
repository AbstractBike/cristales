(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Agencia_hook

let fallos = ref 0

let comprueba nombre cond =
  if not cond then (
    incr fallos;
    Printf.eprintf "FALLA: %s\n%!" nombre)

let contiene s sub =
  let n = String.length sub in
  let rec en i = i + n <= String.length s && (String.sub s i n = sub || en (i + 1)) in
  en 0

let j = Yojson.Safe.from_string

(* Una sesión: dos encargos (el traductor y uno por agencia_encargar, que
   sale dos veces en la transcripción), y solo uno juzgado. *)
let meta agente id =
  Printf.sprintf "encargo %s · claude-haiku-5-5 (x) · directo · 1 ms · 1+1 tokens. Júzgalo con agencia_juzgar (agente %s, id %s): así aprende." id agente id

let resultado texto =
  j
    (Printf.sprintf
       {|{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t","content":[{"type":"text","text":"salida"},{"type":"text","text":%s}]}]}}|}
       (Yojson.Safe.to_string (`String texto)))

let juzgar id =
  j
    (Printf.sprintf
       {|{"type":"assistant","message":{"content":[{"type":"tool_use","name":"mcp__agencia__agencia_juzgar","input":{"agente":"a","id":"%s","veredicto":"bien"}}]}}|}
       id)

let () =
  let lineas =
    [ resultado (meta "traductor-markdown" "00000000000000aa");
      resultado (meta "resumen" "00000000000000bb");
      resultado (meta "resumen" "00000000000000bb");
      juzgar "00000000000000aa";
      (* Un texto del asistente que cita la meta no es un encargo. *)
      j (Printf.sprintf {|{"type":"assistant","message":{"content":[{"type":"text","text":%s}]}}|}
           (Yojson.Safe.to_string (`String (meta "x" "00000000000000cc")))) ]
  in
  comprueba "pendientes: solo el no juzgado, una vez" (pendientes lineas = [ ("resumen", "00000000000000bb") ]);
  comprueba "pendientes: sin encargos, nada" (pendientes [ juzgar "1" ] = []);
  comprueba "bloqueo: sin pendientes, nada" (bloqueo [] = None);
  (match bloqueo [ ("resumen", "00000000000000bb") ] with
  | Some s ->
      comprueba "bloqueo: decision block" (contiene s {|"decision":"block"|});
      comprueba "bloqueo: nombra el encargo" (contiene s "resumen/00000000000000bb")
  | None -> comprueba "bloqueo: hay pendientes" false);
  comprueba "contexto: sin agentes, nada" (contexto [] = None);
  (match contexto [ ("traductor-markdown", "Traduce markdown.") ] with
  | Some s ->
      let c = Yojson.Safe.(Util.(member "hookSpecificOutput" (from_string s))) in
      comprueba "contexto: SessionStart" (Yojson.Safe.Util.member "hookEventName" c = `String "SessionStart");
      comprueba "contexto: el agente"
        (match Yojson.Safe.Util.member "additionalContext" c with `String t -> contiene t "`traductor-markdown`: Traduce markdown." | _ -> false)
  | None -> comprueba "contexto: hay agentes" false);
  if !fallos > 0 then exit 1
