(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* memoria-rejuzga: juzga los encargos de la memoria que se quedaron sin
   veredicto, con el mismo criterio que hoy aplican memoria-destila y
   memoria-consolida (doc/memoria.md): la salida que el pipeline entiende,
   bien; la que no, mal.

   Hasta 2026-10-16 el pipeline solo juzgaba [mal] (lo que no entendía) y
   nunca [bien]: con tres juicios y un 80 % de acierto, cuatro fallos de
   parseo entre 2266 encargos descartaron a sonnet en memoria-escenas y la
   agencia pasó a Opus. Esto recupera el histórico; idempotente: solo toca
   lo que no tiene veredicto, y lo que acabó en error del modelo ya cuenta
   como mal sin juzgarlo.

   memoria-rejuzga [--seco] [--greptime URL] [--db BASE] [AGENTE…]

   --seco     cuenta lo que juzgaría, sin escribir
   AGENTE…    por defecto, los cuatro de la memoria

   AGENCIA_GREPTIME y AGENCIA_GREPTIME_DB (agencia), como agencia-mcp. *)

(* El criterio de cada agente: el mismo parser que usa el pipeline. Los de
   memoria-l1 piden contexto (los mensajes, los casos) solo para construir
   el resultado; si parsea o no depende únicamente del texto. *)
let validadores =
  [ ("memoria-atomos", fun t -> Result.map ignore (Memoria_l1.Extraccion.leer ~clave:"" ~nuevos:[] t));
    ("memoria-dedup", fun t -> Result.map ignore (Memoria_l1.Dedup.leer [] t));
    ("memoria-escenas", fun t -> Result.map ignore (Memoria_escenas.Operacion.de_texto t));
    ("memoria-persona", fun t -> Result.map ignore (Memoria_escenas.Persona.validar t)) ]

let var k = match Sys.getenv_opt k with Some v when String.trim v <> "" -> Some (String.trim v) | _ -> None

let uso () =
  prerr_endline "uso: memoria-rejuzga [--seco] [--greptime URL] [--db BASE] [AGENTE…]";
  exit 2

let () =
  let seco = ref false and greptime = ref (var "AGENCIA_GREPTIME")
  and db = ref (Option.value ~default:"agencia" (var "AGENCIA_GREPTIME_DB")) and agentes = ref [] in
  let rec args = function
    | [] -> ()
    | "--seco" :: r -> seco := true; args r
    | "--greptime" :: u :: r -> greptime := Some u; args r
    | "--db" :: d :: r -> db := d; args r
    | a :: _ when String.starts_with ~prefix:"-" a -> uso ()
    | a :: r -> agentes := a :: !agentes; args r
  in
  args (List.tl (Array.to_list Sys.argv));
  let agentes = if !agentes = [] then List.map fst validadores else List.rev !agentes in
  let url = match !greptime with Some u -> Uri.of_string u | None -> prerr_endline "memoria-rejuzga: falta --greptime o AGENCIA_GREPTIME"; exit 2 in
  Eio_main.run @@ fun env ->
  let post = Forja_http.Proxy.post (Forja_http.Proxy.cliente (Eio.Stdenv.net env)) in
  let archivo = Agencia_http.Archivo_greptime.crear ~post ~url ~db:!db () in
  List.iter
    (fun nombre ->
      match (List.assoc_opt nombre validadores, Forja.Tarea.explicita nombre) with
      | None, _ | _, Error _ -> Printf.eprintf "memoria-rejuzga: %s no es de la memoria\n%!" nombre; exit 2
      | Some valida, Ok tarea ->
          let bien = ref 0 and mal = ref 0 in
          List.iter
            (fun (e : Agencia.Encargo.t) ->
              match (e.veredicto, e.salida) with
              | Some _, _ | None, Error _ -> ()
              | None, Ok texto ->
                  let v, nota =
                    match valida texto with
                    | Ok () -> incr bien; (Agencia.Bien, "rejuzgado: el pipeline la entiende")
                    | Error err -> incr mal; (Agencia.Mal, "rejuzgado: salida no válida: " ^ err)
                  in
                  if not !seco then archivo.juzgar tarea e.id v nota)
            (archivo.historial tarea);
          Printf.printf "%s: %d bien, %d mal%s\n%!" nombre !bien !mal (if !seco then " (en seco)" else ""))
    agentes
