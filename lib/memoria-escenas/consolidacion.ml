(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let tope = 15
let max_crear = 2

let aviso n =
  if n >= tope then
    Some
      (Printf.sprintf
         "Hay %d escenas: tope alcanzado. Antes de nada, FUSIONA las 2-4 escenas abiertas más parecidas (o las de \
          menos calor); «crear» se rechaza."
         n)
  else if n = tope - 1 then
    Some (Printf.sprintf "Hay %d escenas, a una del tope: solo actualizar o fusionar; «crear» se rechaza." n)
  else if n >= tope - 3 then
    Some (Printf.sprintf "Hay %d escenas, cerca del tope de %d: prefiere actualizar o fusionar a crear." n tope)
  else None

let puede_crear n = n < tope - 1

(* {1 Parecido} *)

let vacias =
  [ "para"; "como"; "pero"; "porque"; "desde"; "hasta"; "sobre"; "entre"; "cuando"; "donde"; "este"; "esta"; "esto";
    "estos"; "estas"; "todo"; "toda"; "todos"; "todas"; "tiene"; "tienen"; "hace"; "hacer"; "solo"; "sólo"; "también";
    "más"; "menos"; "cada"; "otro"; "otra"; "otros"; "otras"; "ahora"; "antes"; "después"; "sino"; "aunque"; "with";
    "that"; "this"; "from"; "have"; "into" ]

let palabras texto =
  let t = String.lowercase_ascii texto in
  let b = Buffer.create 16 and acc = ref [] in
  let cerrar () =
    if Buffer.length b >= 4 then acc := Buffer.contents b :: !acc;
    Buffer.clear b
  in
  String.iter
    (fun c -> match c with 'a' .. 'z' | '0' .. '9' | '\128' .. '\255' -> Buffer.add_char b c | _ -> cerrar ())
    t;
  cerrar ();
  List.sort_uniq compare !acc |> List.filter (fun p -> not (List.mem p vacias))

let texto_escena (e : Escena.t) =
  String.concat " " [ String.map (fun c -> if c = '-' then ' ' else c) e.slug; e.titulo; e.resumen; e.cuerpo ]

let abiertas escenas atomos =
  let n = List.length escenas in
  let k = if n >= tope - 3 then 5 else 3 in
  let lote = palabras (String.concat " " (List.map (fun (a : Atomo.t) -> a.contenido ^ " " ^ a.escena) atomos)) in
  let en_lote = Hashtbl.create 256 in
  List.iter (fun p -> Hashtbl.replace en_lote p ()) lote;
  escenas
  |> List.filter (fun (e : Escena.t) -> not e.bloqueada)
  |> List.map (fun (e : Escena.t) ->
         let ps = palabras (texto_escena e) in
         let comunes = List.length (List.filter (Hashtbl.mem en_lote) ps) in
         (float_of_int comunes /. sqrt (1. +. float_of_int (List.length ps)), e.slug))
  |> List.sort (fun (a, s) (b, t) -> compare (b, s) (a, t))
  |> List.filteri (fun i _ -> i < k)
  |> List.map snd

(* {1 El mensaje} *)

let reglas_vigentes b r =
  if String.trim r <> "" then
      Printf.bprintf b "## Reglas vigentes (máxima prioridad)\n\nLas reglas actuales del usuario (su CLAUDE.md y AGENTS.md). Mandan sobre cualquier átomo: lo que las contradiga solo puede ir a `## Trayectoria` o `## Por confirmar`, nunca como regla.\n\n%s\n\n" (String.trim r)

let entrada ?(reglas = "") ?(anteriores = []) ~ahora ~escenas ~abiertas atomos =
  let b = Buffer.create 8192 in
  let p fmt = Printf.bprintf b fmt in
  reglas_vigentes b reglas;
  let n = List.length escenas in
  Option.iter (fun a -> p "## Aviso de tope\n\n%s\n\n" a) (aviso n);
  p "## Índice de escenas (%d/%d)\n\n" n tope;
  if escenas = [] then p "(todavía no hay ninguna)\n";
  List.iter
    (fun (e : Escena.t) ->
      p "- `%s` — %s (calor %d%s%s): %s\n" e.slug e.titulo e.calor
        (if e.bloqueada then ", bloqueada: sí" else "")
        (if List.mem e.slug abiertas then ", abierta" else "")
        e.resumen)
    escenas;
  p "\n## Escenas abiertas\n\n";
  if abiertas = [] then p "(ninguna)\n\n";
  List.iter
    (fun s ->
      match List.find_opt (fun (e : Escena.t) -> e.slug = s) escenas with
      | Some e ->
          p "### `%s` (cuerpo: %d/%d caracteres)\n\n%s\n" s (Escena.longitud e.cuerpo) Escena.max_cuerpo
            (Escena.a_texto e)
      | None -> ())
    abiertas;
  (* Los de una etapa anterior, aparte: el modelo no los confunde con
     reglas vigentes si ni siquiera están en la misma lista. *)
  let viejos, nuevos = List.partition (Atomo.anterior ~anteriores) atomos in
  p "## Átomos nuevos (%d)\n\n" (List.length nuevos);
  if nuevos = [] then p "(ninguno)\n";
  List.iter (fun a -> p "%s\n" (Atomo.linea ~anteriores a)) nuevos;
  if viejos <> [] then (
    p "\n## Historia de una etapa anterior (%d)\n\nDe otra etapa de la flota (otras máquinas, rutas y lenguajes). PROHIBIDO usarlos como regla, método o dato vigente: como mucho, una línea en `## Trayectoria` de una escena que ya exista. Si no aportan trayectoria, ignóralos.\n\n" (List.length viejos);
    List.iter (fun a -> p "%s\n" (Atomo.linea ~anteriores a)) viejos);
  p "\n## Hora actual\n\n%s\n" ahora;
  Buffer.contents b

let reintento ~entrada ~salida rechazos =
  Printf.sprintf
    "%s\n## Tu respuesta anterior\n\n%s\n\n## Rechazos\n\n%s\n\nDevuelve de nuevo el JSON COMPLETO (todas las \
     operaciones, no solo las rechazadas), corrigiendo lo rechazado.\n"
    entrada salida
    (String.concat "\n" (List.map (fun r -> "- " ^ r) rechazos))

(* {1 Aplicar} *)

type resultado = {
  escenas : Escena.t list;
  escritas : string list;
  borradas : string list;
  aplicadas : Operacion.t list;
  rechazos : (Operacion.t * string) list;
  recortadas : string list;
}

let union a b = a @ List.filter (fun x -> not (List.mem x a)) b

let tolerancia = Escena.max_cuerpo * 5 / 4

(* Hasta un 25 % de más se recorta por líneas desde el final (lo último de
   una escena es lo menos vital: trayectoria y dudas, que siguen en L1); más
   allá, se rechaza y se pide condensar. *)
let validar_contenido (c : Operacion.contenido) =
  if not (Escena.slug_valido c.slug) then Error (Printf.sprintf "slug inválido «%s»" c.slug)
  else if String.trim c.titulo = "" then Error "sin título"
  else if String.trim c.resumen = "" then Error "sin resumen"
  else if String.trim c.cuerpo = "" then Error "cuerpo vacío"
  else
    let n = Escena.longitud (String.trim c.cuerpo) in
    if n <= Escena.max_cuerpo then Ok (c, false)
    else
      let r = Escena.recortar c.cuerpo in
      (* Recortar no debe dejarla en los huesos: si se va más de la mitad
         (líneas muy largas), mejor pedir que la condense. *)
      if n <= tolerancia && Escena.longitud r >= Escena.max_cuerpo / 2 then Ok ({ c with cuerpo = r }, true)
      else
      Error
        (Printf.sprintf "cuerpo de %d caracteres: el máximo es %d (apunta a 1100), condénsalo" n Escena.max_cuerpo)

let orden = function Operacion.Fusionar _ -> 0 | Actualizar _ -> 1 | Crear _ -> 2 | Nada -> 3

let aplicar ~ahora ~abiertas ~nuevos escenas ops =
  let recortadas = ref [] in
  let ids = List.map (fun (a : Atomo.t) -> a.id) nuevos in
  let suyos l = List.filter (fun i -> List.mem i ids) l in
  let ops = List.stable_sort (fun a b -> compare (orden a) (orden b)) ops in
  let buscar s l = List.find_opt (fun (e : Escena.t) -> e.slug = s) l in
  let sin s l = List.filter (fun (e : Escena.t) -> e.slug <> s) l in
  let con (e : Escena.t) l = List.sort (fun (a : Escena.t) b -> compare a.slug b.slug) (e :: sin e.slug l) in
  let tocable ?(escritas = []) l s =
    match buscar s l with
    | None -> Error (Printf.sprintf "«%s» no existe" s)
    | Some e when e.bloqueada -> Error (Printf.sprintf "«%s» está bloqueada" s)
    | Some _ when not (List.mem s abiertas || List.mem s escritas) -> Error (Printf.sprintf "«%s» no estaba abierta: no la has leído" s)
    | Some e -> Ok e
  in
  let nueva (c : Operacion.contenido) ~creada ~calor ~atomos =
    { Escena.slug = c.slug; titulo = String.trim c.titulo; resumen = String.trim c.resumen; creada;
      actualizada = ahora; calor; bloqueada = false; atomos; extra = []; cuerpo = String.trim c.cuerpo }
  in
  let ( let* ) = Result.bind in
  let paso (escenas, escritas, borradas, creadas) op =
    match (op : Operacion.t) with
    | Nada -> Ok (escenas, escritas, borradas, creadas)
    | Actualizar c ->
        let* c, r = validar_contenido c in
        if r then recortadas := c.slug :: !recortadas;
        let* e = tocable ~escritas escenas c.slug in
        let e' = nueva c ~creada:e.creada ~calor:(e.calor + 1) ~atomos:(union e.atomos (suyos c.atomos)) in
        Ok (con { e' with extra = e.extra } escenas, union escritas [ c.slug ], borradas, creadas)
    | Crear c ->
        let* c, r = validar_contenido c in
        if r then recortadas := c.slug :: !recortadas;
        if buscar c.slug escenas <> None then Error (Printf.sprintf "«%s» ya existe: actualízala" c.slug)
        else if not (puede_crear (List.length escenas)) then
          Error (Printf.sprintf "hay %d escenas: no se admite crear (tope %d)" (List.length escenas) tope)
        else if creadas >= max_crear then Error (Printf.sprintf "como mucho %d «crear» por lote" max_crear)
        else
          let e = nueva c ~creada:ahora ~calor:1 ~atomos:(suyos c.atomos) in
          Ok (con e escenas, union escritas [ c.slug ], borradas, creadas + 1)
    | Fusionar (de, c) ->
        let* c, r = validar_contenido c in
        if r then recortadas := c.slug :: !recortadas;
        let de = List.sort_uniq compare de in
        if List.length de < 2 || List.length de > 4 then Error "fusionar junta de 2 a 4 escenas"
        else if (not (List.mem c.slug de)) && buscar c.slug escenas <> None then
          Error (Printf.sprintf "«%s» ya existe y no está entre las que se fusionan" c.slug)
        else
          let* fuentes =
            List.fold_right
              (fun s acc ->
                let* acc = acc in
                let* e = tocable ~escritas escenas s in
                Ok (e :: acc))
              de (Ok [])
          in
          let creada =
            List.fold_left (fun m (e : Escena.t) -> if e.creada <> "" && e.creada < m then e.creada else m) ahora fuentes
          and calor = List.fold_left (fun s (e : Escena.t) -> s + e.calor) 1 fuentes
          and atomos = List.fold_left (fun a (e : Escena.t) -> union a e.atomos) [] fuentes in
          let e = nueva c ~creada ~calor ~atomos:(union atomos (suyos c.atomos)) in
          let resto = List.fold_left (fun l s -> sin s l) escenas de in
          let quitadas = List.filter (fun s -> s <> c.slug) de in
          Ok
            ( con e resto,
              union (List.filter (fun s -> not (List.mem s quitadas)) escritas) [ c.slug ],
              union (List.filter (fun s -> s <> c.slug) borradas) quitadas,
              creadas )
  in
  let estado, aplicadas, rechazos =
    List.fold_left
      (fun (estado, aplicadas, rechazos) op ->
        match paso estado op with
        | Ok estado -> (estado, op :: aplicadas, rechazos)
        | Error motivo -> (estado, aplicadas, (op, motivo) :: rechazos))
      ((escenas, [], [], 0), [], [])
      ops
  in
  let escenas, escritas, borradas, _ = estado in
  { escenas = List.sort (fun (a : Escena.t) b -> compare a.slug b.slug) escenas;
    escritas;
    borradas;
    aplicadas = List.rev aplicadas;
    rechazos = List.rev rechazos;
    recortadas = List.rev !recortadas }
