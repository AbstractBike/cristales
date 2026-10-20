(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

(* Red de la librería: el ciclo líquida → sombra → mixta → cristalina sobre un
   cristal de juguete, la medida en cada fase y el registro JSONL. *)

let fallos = ref 0

let falla fmt =
  incr fallos;
  Printf.eprintf (fmt ^^ "\n")

(* Paridad de un entero escrito en texto. El cristal no sabe de negativos. *)
let forma = { Cristal.entrada = Fun.id; salida = Fun.id }

let paridad =
  Cristal.cristal "paridad" forma (fun s ->
      match int_of_string_opt s with
      | Some n when n >= 0 -> Ok (if n mod 2 = 0 then "par" else "impar")
      | _ -> Error "no es un natural")

(* Un líquido que se equivoca con el 7. *)
let llamadas = ref 0

let llm s =
  incr llamadas;
  if s = "7" then "par"
  else match int_of_string_opt s with
    | Some n when n mod 2 = 0 -> "par"
    | Some _ -> "impar"
    | None -> "?"

let entradas = [ "2"; "7"; "10"; "-3" ]

let correr etapa =
  llamadas := 0;
  let m = Cristal.Medidor.crear () in
  let evs = ref [] in
  let observar ev =
    Cristal.Medidor.observar m ev;
    evs := ev :: !evs
  in
  let rs = List.map (Cristal.ejecutar ~observar (Cristal.etapa etapa)) entradas in
  (m, List.rev !evs, rs)

let () =
  let sombra = Cristal.sombra paridad llm in
  let m, evs, rs = correr sombra in
  if !llamadas <> 4 then falla "sombra: %d llamadas, se esperaban 4" !llamadas;
  if List.exists Result.is_error rs then falla "sombra: nunca falla";
  if Cristal.Medidor.grado m "paridad" <> Some 0. then
    falla "sombra: el grado debe ser 0, responde siempre el LLM";
  (* Coinciden 2 y 10; el 7 discrepa y el -3 es defecto. *)
  if Cristal.Medidor.acuerdo m "paridad" <> Some 0.5 then
    falla "sombra: el acuerdo debe ser 0.5";
  (match List.nth evs 1 with
  | Comparado { entrada = "7"; liquido = "par"; cristal = Ok "impar"; _ } -> ()
  | _ -> falla "sombra: la discrepancia del 7 no queda registrada");

  let mixta = Cristal.solidificar sombra in
  if Cristal.fase mixta <> `Mixta then falla "solidificar: sombra → mixta";
  let m, evs, _ = correr mixta in
  if !llamadas <> 1 then falla "mixta: %d llamadas, se esperaba 1" !llamadas;
  if Cristal.Medidor.grado m "paridad" <> Some 0.75 then falla "mixta: grado 0.75";
  if Cristal.Medidor.acuerdo m "paridad" <> None then
    falla "mixta: sin sombra no hay acuerdo";
  (match List.nth evs 3 with
  | Defecto { entrada = "-3"; liquido = Some "impar"; _ } -> ()
  | _ -> falla "mixta: el defecto debe llevar la entrada y lo que dijo el LLM");

  let cristalina = Cristal.solidificar mixta in
  let _, evs, rs = correr cristalina in
  if !llamadas <> 0 then falla "cristalina: llamó al LLM";
  (match List.nth rs 3 with
  | Error { etapa = "paridad"; _ } -> ()
  | _ -> falla "cristalina: el defecto debe ser un fallo visible");
  (match List.nth evs 3 with
  | Defecto { liquido = None; _ } -> ()
  | _ -> falla "cristalina: el defecto no tiene líquido");

  if Cristal.fase (Cristal.fundir mixta) <> `Liquida then falla "fundir: mixta → líquida";
  if Cristal.fase (Cristal.fundir cristalina) <> `Cristalina then
    falla "fundir: una cristalina no tiene LLM al que volver"

(* Registro: todo evento sobrevive a la ida y vuelta, también con texto raro. *)
let () =
  let raro = "línea\ncon \"comillas\", | y ñ" in
  let eventos : Cristal.evento list =
    [ Por_cristal { etapa = "e"; entrada = raro; salida = "s" };
      Por_liquido { etapa = "e"; entrada = "x"; salida = raro };
      Defecto { etapa = "e"; entrada = "x"; motivo = raro; liquido = Some "y" };
      Defecto { etapa = "e"; entrada = "x"; motivo = "m"; liquido = None };
      Comparado { etapa = "e"; entrada = "x"; liquido = "a"; cristal = Ok "b" };
      Comparado { etapa = "e"; entrada = "x"; liquido = "a"; cristal = Error "m" } ]
  in
  List.iter
    (fun ev ->
      let j = Registro.a_json ev in
      if String.contains j '\n' then falla "registro: %s ocupa más de una línea" j;
      match Registro.de_json j with
      | Ok ev' when ev' = ev -> ()
      | Ok _ -> falla "registro: %s no vuelve igual" j
      | Error e -> falla "registro: %s no se lee: %s" j e)
    eventos;
  (match Registro.de_json {|{"v":1,"etapa":"e","evento":"cristal","entrada":"x","salida":"s","ts":"2026-10-11T00:00:00Z","modelo":"m"}|} with
  | Ok _ -> ()
  | Error e -> falla "registro: los campos extra deben ignorarse: %s" e);
  match Registro.de_json {|{"v":2,"etapa":"e","evento":"cristal","entrada":"x","salida":"s"}|} with
  | Error _ -> ()
  | Ok _ -> falla "registro: una versión desconocida debe rechazarse"

let () =
  if !fallos > 0 then (
    Printf.eprintf "%d fallos en la red de la librería\n" !fallos;
    exit 1)
