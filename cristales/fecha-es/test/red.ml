(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

(* Red cristalina de fecha-es: los ejemplos y el fuera de dominio de
   SEMILLA.md, más las invariantes sobre un barrido del calendario. *)

open Fecha_es

let hoy = { anyo = 2026; mes = 10; dia = 11 }
let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

let ejemplos =
  [ ("3 de marzo de 2024", "2024-03-03");
    ("el 1 de enero del 2025", "2025-01-01");
    ("29 de Febrero de 2024", "2024-02-29");
    ("15 de agosto", "2026-08-15");
    ("lunes, 5 de octubre de 2026", "2026-10-05");
    ("03/03/2024", "2024-03-03");
    ("3-3-24", "2024-03-03");
    ("2024-03-03", "2024-03-03");
    ("hoy", "2026-10-11");
    ("mañana", "2026-10-12");
    ("pasado mañana", "2026-10-13");
    ("ayer", "2026-10-10");
    ("anteayer", "2026-10-09");
    ("1º de mayo de 2026", "2026-05-01") ]

let fuera_de_dominio =
  [ "30 de febrero de 2024"; "31/04/2024"; "el próximo martes";
    "dentro de tres semanas"; "del 3 al 5 de marzo"; "sin fecha"; "" ]

let () =
  List.iter
    (fun (e, esperado) ->
      match aplicar ~hoy e with
      | Ok f when iso f = esperado -> ()
      | Ok f -> falla "%S: %s, se esperaba %s" e (iso f) esperado
      | Error m -> falla "%S: defecto (%s), se esperaba %s" e m esperado)
    ejemplos;
  List.iter
    (fun e ->
      match aplicar ~hoy e with
      | Error _ -> ()
      | Ok f -> falla "%S debía ser defecto y dio %s" e (iso f))
    fuera_de_dominio

(* Invariante: para toda fecha válida de 1970 a 2069, sus formas escritas
   vuelven a ella, y "mañana" desde ella es el día siguiente válido. *)
let meses =
  [| ""; "enero"; "febrero"; "marzo"; "abril"; "mayo"; "junio"; "julio";
     "agosto"; "septiembre"; "octubre"; "noviembre"; "diciembre" |]

let () =
  for anyo = 1970 to 2069 do
    for mes = 1 to 12 do
      for dia = 1 to 31 do
        let f = { anyo; mes; dia } in
        let formas =
          [ Printf.sprintf "%d de %s de %d" dia meses.(mes) anyo;
            Printf.sprintf "%02d/%02d/%04d" dia mes anyo;
            Printf.sprintf "%d-%d-%02d" dia mes (anyo mod 100);
            iso f ]
        in
        List.iter
          (fun t ->
            match (valida f, aplicar ~hoy t) with
            | true, Ok g when g = f -> ()
            | false, Error _ -> ()
            | true, _ -> falla "%S no vuelve a %s" t (iso f)
            | false, Ok g -> falla "%S imposible y dio %s" t (iso g))
          formas;
        if valida f then
          match aplicar ~hoy:f "mañana" with
          | Ok g when valida g && g <> f -> ()
          | _ -> falla "mañana desde %s no es una fecha válida" (iso f)
      done
    done
  done

(* La etapa mixta: lo que el cristal no sabe cae al LLM y se mide. *)
let () =
  let llm_llamadas = ref 0 in
  let llm _ =
    incr llm_llamadas;
    { anyo = 2026; mes = 10; dia = 13 }
  in
  let medidor = Cristal.Medidor.crear () in
  let p = Cristal.(etapa (mixta (Fecha_es.cristal ~hoy) llm)) in
  List.iter
    (fun t ->
      ignore (Cristal.ejecutar ~observar:(Cristal.Medidor.observar medidor) p t))
    [ "hoy"; "3/3/2024"; "el próximo martes"; "ayer" ];
  if !llm_llamadas <> 1 then falla "mixta: %d llamadas al LLM, se esperaba 1" !llm_llamadas;
  if Cristal.Medidor.grado medidor "fecha-es" <> Some 0.75 then
    falla "mixta: grado de cristalización distinto de 0.75";
  let solida = Cristal.(etapa (solidificar (mixta (Fecha_es.cristal ~hoy) llm))) in
  match Cristal.ejecutar solida "el próximo martes" with
  | Error { etapa = "fecha-es"; _ } -> ()
  | _ -> falla "cristalina: un defecto debía ser fallo visible"

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de fecha-es\n" !fallos;
    exit 1)
