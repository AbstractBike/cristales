(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

open Agencia

type destinos = {
  anthropic : Uri.t;
  openai : Uri.t option;
  cabeceras_anthropic : (string * string) list;
  cabeceras_openai : (string * string) list;
}

let peticion (a : Agente.t) (m : Modelo.t) entrada =
  let usuario = `Assoc [ ("role", `String "user"); ("content", `String entrada) ] in
  match m.api with
  | Anthropic ->
      ( "/v1/messages",
        `Assoc
          [ ("model", `String m.nombre);
            ("max_tokens", `Int a.max_tokens);
            ("system", `String a.instrucciones);
            ("messages", `List [ usuario ]) ] )
  | Openai ->
      ( "/v1/chat/completions",
        `Assoc
          [ ("model", `String m.nombre);
            ("max_tokens", `Int a.max_tokens);
            ( "messages",
              `List [ `Assoc [ ("role", `String "system"); ("content", `String a.instrucciones) ]; usuario ] ) ] )

let leer api j =
  let open Yojson.Safe.Util in
  let tokens k = match j |> member "usage" |> member k with `Int n -> n | _ -> 0 in
  let texto =
    match api with
    (* Los bloques de texto; los demás (thinking…) no son la salida. *)
    | Modelo.Anthropic -> (
        match j |> member "content" with
        | `List bloques ->
            Some
              (String.concat ""
                 (List.filter_map
                    (fun b ->
                      match (b |> member "type", b |> member "text") with
                      | `String "text", `String t -> Some t
                      | _ -> None)
                    bloques))
        | _ -> None)
    | Modelo.Openai -> (
        match j |> member "choices" with
        | `List (c :: _) -> ( match c |> member "message" |> member "content" with `String t -> Some t | _ -> None)
        | _ -> None)
  in
  match (texto, api) with
  | None, _ -> Error "respuesta sin texto"
  | Some t, Modelo.Anthropic -> Ok (t, tokens "input_tokens", tokens "output_tokens")
  | Some t, Modelo.Openai -> Ok (t, tokens "prompt_tokens", tokens "completion_tokens")
  | exception Type_error (m, _) -> Error m

let sin_barra p = if String.ends_with ~suffix:"/" p then String.sub p 0 (String.length p - 1) else p

let recortar s = if String.length s <= 500 then s else String.sub s 0 500 ^ "…"

let llamar clock cliente d ?(espera = 600.) (a : Agente.t) (m : Modelo.t) entrada =
  let inicio = Eio.Time.now clock in
  let ms () = int_of_float ((Eio.Time.now clock -. inicio) *. 1000.) in
  let fallo ?(fuente = sin_respuesta) e =
    { salida = Error e; fuente; ms = ms (); tokens_entrada = 0; tokens_salida = 0 }
  in
  let base, propias =
    match m.api with
    | Anthropic -> (Some d.anthropic, ("anthropic-version", "2023-06-01") :: d.cabeceras_anthropic)
    | Openai -> (d.openai, d.cabeceras_openai)
  in
  match base with
  | None -> fallo (Modelo.to_string m ^ ": no hay servidor Chat Completions (AGENCIA_OPENAI)")
  | Some base -> (
      let ruta, cuerpo = peticion a m entrada in
      let cuerpo = Yojson.Safe.to_string cuerpo in
      let uri = Uri.with_path base (sin_barra (Uri.path base) ^ ruta) in
      let cabeceras =
        Http.Header.of_list
          ([ ("content-type", "application/json");
             ("content-length", string_of_int (String.length cuerpo));
             (Forja_http.Anthropic.cabecera_tarea, Forja.Tarea.to_string a.nombre) ]
          @ propias)
      in
      match
        Eio.Time.with_timeout_exn clock espera (fun () ->
            Eio.Switch.run @@ fun sw ->
            let r, b =
              Cohttp_eio.Client.call cliente ~sw ~headers:cabeceras ~body:(Cohttp_eio.Body.of_string cuerpo) `POST uri
            in
            ( Http.Status.to_int (Http.Response.status r),
              Http.Header.get (Http.Response.headers r) "x-forja-fuente",
              Eio.Buf_read.(parse_exn take_all) b ~max_size:max_int ))
      with
      | exception e -> fallo (Printexc.to_string e)
      | estado, fuente, b -> (
          let fuente = Option.value ~default:"directo" fuente in
          (* Sin autorización, con límite o con el servidor caído, el modelo
             no ha llegado a ver el encargo. *)
          let fuente = if List.mem estado [ 401; 403; 429 ] || estado >= 500 then sin_respuesta else fuente in
          if estado <> 200 then fallo ~fuente (Printf.sprintf "%d: %s" estado (recortar b))
          else
            match Result.bind (try Ok (Yojson.Safe.from_string b) with Yojson.Json_error e -> Error e) (leer m.api) with
            | Ok (t, tokens_entrada, tokens_salida) -> { salida = Ok t; fuente; ms = ms (); tokens_entrada; tokens_salida }
            | Error e -> fallo ~fuente (e ^ ": " ^ recortar b)))
