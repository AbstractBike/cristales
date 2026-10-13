(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Agencia
open Mcp_rpc

type efectos = {
  archivo : Archivo.t;
  llamar : Agente.t -> Modelo.t -> string -> Agencia.respuesta;
  id : unit -> string;
  escalera : Modelo.t list;
  politica : Politica.t;
}

let encargar ef (a : Agente.t) ?modelo entrada =
  let eleccion =
    match modelo with
    | Some modelo -> { modelo; motivo = "pedido por quien encarga" }
    | None -> elegir ~politica:ef.politica a (ef.archivo.historial a.nombre)
  in
  let r = ef.llamar a eleccion.modelo entrada in
  let e =
    { Encargo.id = ef.id ();
      agente = a.nombre;
      version = Agente.version a;
      (* Si respondió un cristal de la forja, el modelo no lo vio: no cuenta
         para él. *)
      modelo = (if r.fuente = "cristal" then "cristal" else Modelo.to_string eleccion.modelo);
      motivo = eleccion.motivo;
      fuente = r.fuente;
      entrada;
      salida = r.salida;
      ms = r.ms;
      tokens_entrada = r.tokens_entrada;
      tokens_salida = r.tokens_salida;
      veredicto = None;
      nota = "" }
  in
  ef.archivo.registrar e;
  e

(* {1 JSON} (los de la vista: los mismos que pinta agencia.pin) *)

let json_texto j = Yojson.Safe.pretty_to_string j
let json_agente ef a = Agencia_vista.json_agente ef.archivo ef.politica a

(* {1 Herramientas} *)

let ( let* ) = Result.bind

let texto_de args k =
  match argumento args k with
  | Ok (Some (`String s)) -> Ok (Some s)
  | Ok None -> Ok None
  | Ok (Some _) -> invalido (k ^ ": tiene que ser texto")
  | Error e -> Error e

let requerido args k =
  let* v = texto_de args k in
  match v with Some s -> Ok s | None -> invalido ("falta " ^ k ^ " (texto)")

let modelo_de s = match Modelo.de_texto s with Ok m -> Ok m | Error e -> invalido e

let buscar ef n =
  match List.find_opt (fun (a : Agente.t) -> Forja.Tarea.to_string a.nombre = n) (ef.archivo.agentes ()) with
  | Some a -> Ok a
  | None -> invalido (n ^ ": no hay tal agente (agencia_crear)")

let crear ef args =
  let* nombre = requerido args "nombre" in
  let* instrucciones = requerido args "instrucciones" in
  let* descripcion = texto_de args "descripcion" in
  let* escalera =
    match argumento args "escalera" with
    | Ok None -> Ok ef.escalera
    | Ok (Some (`List l)) ->
        List.fold_right
          (fun m acc ->
            let* acc = acc in
            match m with `String s -> Result.map (fun m -> m :: acc) (modelo_de s) | _ -> invalido "escalera: lista de textos")
          l (Ok [])
    | Ok (Some _) -> invalido "escalera: lista de modelos, del más barato al más capaz"
    | Error e -> Error e
  in
  let* defecto = texto_de args "defecto" in
  let* defecto = match defecto with None -> Ok None | Some s -> Result.map Option.some (modelo_de s) in
  let* max_tokens =
    match argumento args "max_tokens" with
    | Ok None -> Ok None
    | Ok (Some (`Int n)) -> Ok (Some n)
    | Ok (Some _) -> invalido "max_tokens: entero"
    | Error e -> Error e
  in
  let* ejemplos =
    match argumento args "ejemplos" with
    | Ok None -> Ok None
    | Ok (Some (`Int n)) -> Ok (Some n)
    | Ok (Some _) -> invalido "ejemplos: entero"
    | Error e -> Error e
  in
  match Agente.crear ~nombre ?descripcion ~instrucciones ~escalera ?defecto ?max_tokens ?ejemplos () with
  | Error e -> invalido e
  | Ok a ->
      ef.archivo.guardar a;
      Ok (texto (json_texto (json_agente ef a)))

let agentes ef _ = Ok (texto (json_texto (`List (List.map (json_agente ef) (ef.archivo.agentes ())))))

let historico ef args =
  let* n = requerido args "agente" in
  let* a = buscar ef n in
  let* ultimos =
    match argumento args "ultimos" with
    | Ok None -> Ok 10
    | Ok (Some (`Int k)) when k >= 0 && k <= 1000 -> Ok k
    | Ok (Some _) -> invalido "ultimos: entero de 0 a 1000"
    | Error e -> Error e
  in
  Ok (texto (json_texto (Agencia_vista.json_historico ef.archivo ef.politica ~ultimos a)))

let resultado (e : Encargo.t) =
  let meta =
    Printf.sprintf
      "encargo %s · %s (%s) · %s · %d ms · %d+%d tokens. Júzgalo con agencia_juzgar (agente %s, id \
       %s): así aprende la agencia a qué modelo pedírselo."
      e.id e.modelo e.motivo e.fuente e.ms e.tokens_entrada e.tokens_salida
      (Forja.Tarea.to_string e.agente) e.id
  in
  let bloque s = `Assoc [ ("type", `String "text"); ("text", `String s) ] in
  match e.salida with
  | Ok s -> `Assoc [ ("content", `List [ bloque s; bloque meta ]); ("isError", `Bool false) ]
  | Error m -> `Assoc [ ("content", `List [ bloque ("error: " ^ m); bloque meta ]); ("isError", `Bool true) ]

let encargar_a ef a args =
  let* entrada = requerido args "entrada" in
  let* modelo = texto_de args "modelo" in
  let* modelo = match modelo with None -> Ok None | Some s -> Result.map Option.some (modelo_de s) in
  Ok (resultado (encargar ef a ?modelo entrada))

let encargar_mcp ef args =
  let* n = requerido args "agente" in
  let* a = buscar ef n in
  encargar_a ef a args

let juzgar ef args =
  let* n = requerido args "agente" in
  let* a = buscar ef n in
  let* id = requerido args "id" in
  let* v = requerido args "veredicto" in
  let* nota = texto_de args "nota" in
  match veredicto_de_texto v with
  | None -> invalido "veredicto: bien o mal"
  | Some v -> (
      match List.find_opt (fun (e : Encargo.t) -> e.id = id) (ef.archivo.historial a.nombre) with
      | None -> invalido (id ^ ": no es un encargo de " ^ n)
      | Some _ ->
          ef.archivo.juzgar a.nombre id v (Option.value ~default:"" nota);
          let siguiente = elegir ~politica:ef.politica a (ef.archivo.historial a.nombre) in
          Ok
            (texto
               (Printf.sprintf "%s: %s. El siguiente encargo irá a %s (%s)." id (veredicto_a_texto v)
                  (Modelo.to_string siguiente.modelo) siguiente.motivo)))

type fija = {
  nombre : string;
  descripcion : string;
  esquema : Yojson.Safe.t;
  llamar : efectos -> Yojson.Safe.t -> (Yojson.Safe.t, error) result;
}

let agente = ("agente", cadena)
let entrada = ("entrada", cadena)
let modelo = ("modelo", cadena)

let fijas =
  [ { nombre = "agencia_crear";
      descripcion =
        "Crea (o redefine) un agente: un nombre [a-z0-9-], sus instrucciones fijas (el system \
         prompt) y la escalera de modelos que puede usar, del más barato al más capaz \
         (\"claude-haiku-5-5\", \"openai:<modelo>\" para uno local). Sin escalera, la de la \
         agencia. defecto es a quién pedir mientras no se sepa más (el más capaz si no se dice). \
         Redefinir las instrucciones empieza un histórico nuevo para elegir modelo. \
         ejemplos (3 si no se dice, 0 los apaga) es cuántos encargos juzgados bien van como \
         ejemplos en cada encargo nuevo, los más parecidos a su entrada; las notas de los mal van \
         como advertencias.";
      esquema =
        esquema ~requeridos:[ "nombre"; "instrucciones" ]
          [ ("nombre", cadena);
            ("instrucciones", cadena);
            ("descripcion", cadena);
            ("escalera", `Assoc [ ("type", `String "array"); ("items", cadena) ]);
            ("defecto", cadena);
            ("max_tokens", entero);
            ("ejemplos", entero) ];
      llamar = crear };
    { nombre = "agencia_agentes";
      descripcion =
        "Los agentes de la agencia: su escalera de modelos, cómo le va a cada modelo con cada \
         agente (fiable, descartado o por ver; encargos, aciertos, ms y tokens) y a qué modelo irá \
         su siguiente encargo y por qué.";
      esquema = esquema [];
      llamar = agentes };
    { nombre = "agencia_historico";
      descripcion =
        "El histórico de un agente: su definición con las instrucciones, las cuentas por modelo y \
         sus últimos encargos (modelo, motivo, tiempo, tokens, veredicto, entrada y salida).";
      esquema = esquema ~requeridos:[ "agente" ] [ agente; ("ultimos", entero) ];
      llamar = historico };
    { nombre = "agencia_encargar";
      descripcion =
        "Hace un encargo a un agente: la agencia elige el modelo con su histórico (o usa modelo \
         si se da), le pasa la entrada con las instrucciones del agente y guarda el resultado. \
         Devuelve la salida y el id del encargo para juzgarlo.";
      esquema = esquema ~requeridos:[ "agente"; "entrada" ] [ agente; entrada; modelo ];
      llamar = encargar_mcp };
    { nombre = "agencia_juzgar";
      descripcion =
        "Juzga un encargo: bien o mal, con una nota opcional. Con los veredictos la agencia \
         aprende qué modelo hace bien cada agente y deja de pedírselo a los que no.";
      esquema =
        esquema ~requeridos:[ "agente"; "id"; "veredicto" ]
          [ agente;
            ("id", cadena);
            ("veredicto", `Assoc [ ("type", `String "string"); ("enum", `List [ `String "bien"; `String "mal" ]) ]);
            ("nota", cadena) ];
      llamar = juzgar } ]

let herramientas ef () =
  List.map (fun f -> herramienta f.nombre f.descripcion f.esquema) fijas
  @ List.map
      (fun (a : Agente.t) ->
        herramienta (Forja.Tarea.to_string a.nombre)
          ((if a.descripcion = "" then "Agente de la agencia." else a.descripcion)
          ^ " (Agente de la agencia: el modelo lo elige ella; juzga el resultado con agencia_juzgar.)")
          (esquema ~requeridos:[ "entrada" ] [ entrada; modelo ]))
      (ef.archivo.agentes ())

let llamar ef n args =
  match List.find_opt (fun f -> f.nombre = n) fijas with
  | Some f -> f.llamar ef args
  | None ->
      let* a = buscar ef n in
      encargar_a ef a args

(* {1 Instrucciones} *)

let uso =
  "La agencia hace encargos a agentes y sabe a qué modelo pedir cada uno. Úsala por defecto: \
   cuando una subtarea sea una transformación con instrucciones fijas que harías igual otra vez \
   (clasificar, extraer, resumir, traducir, reescribir, redactar con una plantilla), no la hagas \
   tú. Mira antes agencia_agentes por si ya hay un agente para ella; si no, créalo con \
   agencia_crear y encárgasela: la agencia elige el modelo más barato que la hace bien, y un \
   modelo pequeño o un cristal cuestan mucho menos que tú. Juzga cada resultado con \
   agencia_juzgar (bien o mal): sin veredictos no aprende. Si un cristal (servidor cristales) \
   cubre la tarea, llámalo a él. Todo se ve en https://agencia.pin."

let instrucciones ef () =
  match ef.archivo.agentes () with
  | [] -> uso ^ "\n\nAún no hay agentes."
  | l ->
      uso ^ "\n\nAgentes: "
      ^ String.concat ", "
          (List.map
             (fun (a : Agente.t) ->
               let n = Forja.Tarea.to_string a.nombre in
               if a.descripcion = "" then n else Printf.sprintf "%s (%s)" n a.descripcion)
             l)
      ^ "."
      ^
      (* Lo que falta por juzgar: la agencia aprende de eso. *)
      let sin_juzgar =
        List.fold_left
          (fun n (a : Agente.t) ->
            n
            + List.length
                (List.filter
                   (fun (e : Encargo.t) -> e.veredicto = None && Result.is_ok e.salida)
                   (ef.archivo.historial a.nombre)))
          0 l
      in
      if sin_juzgar = 0 then ""
      else
        Printf.sprintf
          "\n\nHay %d encargos sin juzgar: si sabes si salieron bien, júzgalos (agencia_historico los \
           enseña)."
          sin_juzgar

let servidor ef =
  { Mcp_rpc.nombre = "agencia-mcp";
    version = "0.1.0";
    instrucciones = instrucciones ef;
    herramientas = herramientas ef;
    llamar = llamar ef }
