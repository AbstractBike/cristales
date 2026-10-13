(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type tipo = Pem | Anthropic | Openai | Github | Gitlab | Slack | Aws | Jwt | Bearer | Url | Infisical | Clave | Password | Entropia

let todos = [ Pem; Anthropic; Openai; Github; Gitlab; Slack; Aws; Jwt; Bearer; Url; Infisical; Clave; Password; Entropia ]

let nombre = function
  | Pem -> "pem"
  | Anthropic -> "anthropic"
  | Openai -> "openai"
  | Github -> "github"
  | Gitlab -> "gitlab"
  | Slack -> "slack"
  | Aws -> "aws"
  | Jwt -> "jwt"
  | Bearer -> "bearer"
  | Url -> "url"
  | Infisical -> "infisical"
  | Clave -> "clave"
  | Password -> "password"
  | Entropia -> "entropia"

let marca t = "[redactado:" ^ nombre t ^ "]"

let entropia s =
  let n = String.length s in
  if n = 0 then 0.
  else
    let cuenta = Array.make 256 0 in
    String.iter (fun c -> cuenta.(Char.code c) <- cuenta.(Char.code c) + 1) s;
    Array.fold_left
      (fun h k ->
        if k = 0 then h
        else
          let p = float k /. float n in
          h -. (p *. Float.log2 p))
      0. cuenta

let existe f s = String.exists f s
let re_separador = Re.compile (Re.set "_.=-")

let clase c =
  if c >= 'a' && c <= 'z' then 1 else if c >= 'A' && c <= 'Z' then 2 else if c >= '0' && c <= '9' then 3 else 0

(* Saltos entre minúscula, mayúscula y dígito por par de vecinos: unos 0,6
   en una cadena al azar, menos de 0,25 en un identificador CamelCase. *)
let saltos s =
  let n = ref 0 in
  for i = 1 to String.length s - 1 do
    if clase s.[i] <> clase s.[i - 1] then incr n
  done;
  float !n /. float (String.length s - 1)

let al_azar s =
  String.length s >= 16
  && existe (fun c -> clase c = 1) s
  && existe (fun c -> clase c = 2) s
  && existe (fun c -> clase c = 3) s
  && saltos s >= 0.45 && entropia s >= 3.5

(* Un trozo al azar entre separadores basta: así las rutas, los nombres de
   variable o los de fichero (palabras unidas por [/], [_], [.], [-], [=])
   no cuentan, y una clave sí aunque lleve alguno. Los ids de invocación de
   Restate ([inv_…]) son al azar pero no son secretos. *)
let parece_secreto s =
  (not (String.starts_with ~prefix:"inv_" s))
  && List.exists al_azar (String.split_on_char '/' s |> List.concat_map (fun t -> Re.split re_separador t))

let perl ?(opts = []) p = Re.compile (Re.Perl.re ~opts p)

(* Cada regla: su tipo, la expresión y cómo se sustituye un acierto
   ([None] = no era un secreto, se deja tal cual). Las fronteras de token
   se hacen con un grupo previo que se conserva, porque Re no tiene
   lookbehind. *)
type regla = { tipo : tipo; re : Re.re; sustituto : Re.Group.t -> string option }

let entero t _ = Some (marca t)

(* Grupo 1: lo que precede (inicio o un carácter que no es de token). *)
let con_frontera t g = Some (Re.Group.get g 1 ^ marca t)
let ini = {|(^|[^A-Za-z0-9_-])|}

let reglas =
  [ { tipo = Pem;
      re = perl {|-----BEGIN[A-Z0-9 ]*KEY[A-Z ]*-----(.|\n)*?(-----END[A-Z0-9 ]*-----|\z)|};
      sustituto = entero Pem };
    { tipo = Anthropic; re = perl (ini ^ {|sk-ant-[A-Za-z0-9_-]{16,}|}); sustituto = con_frontera Anthropic };
    { tipo = Openai;
      re = perl (ini ^ {|sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}|});
      (* [sk-] es un prefijo corriente (rutas, slugs): solo si lo que sigue
         mezcla mayúsculas, minúsculas y dígitos. *)
      sustituto =
        (fun g ->
          let s = Re.Group.get g 0 in
          if existe (fun c -> clase c = 1) s && existe (fun c -> clase c = 2) s && existe (fun c -> clase c = 3) s
          then con_frontera Openai g
          else None) };
    { tipo = Github;
      re = perl (ini ^ {|(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})|});
      sustituto = con_frontera Github };
    { tipo = Gitlab; re = perl (ini ^ {|glpat-[A-Za-z0-9_-]{20,}|}); sustituto = con_frontera Gitlab };
    { tipo = Slack; re = perl (ini ^ {|xox[abprs]-[A-Za-z0-9-]{10,}|}); sustituto = con_frontera Slack };
    { tipo = Aws; re = perl {|(^|[^A-Z0-9])(AKIA|ASIA)[A-Z0-9]{16}|}; sustituto = con_frontera Aws };
    { tipo = Jwt;
      re = perl (ini ^ {|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}|});
      sustituto = con_frontera Jwt };
    { tipo = Bearer;
      re = perl ~opts:[ `Caseless ] {|(bearer[ \t]+)[A-Za-z0-9._~+/=-]{12,}|};
      sustituto = (fun g -> Some (Re.Group.get g 1 ^ marca Bearer)) };
    { tipo = Url;
      re = perl {|([A-Za-z][A-Za-z0-9+.-]*://)[^/\s:@'"]+:[^/\s@'"]+@|};
      sustituto = (fun g -> Some (Re.Group.get g 1 ^ marca Url ^ "@")) };
    (* Tokens de servicio de Infisical: [st.<id>.<clave>…]. *)
    { tipo = Infisical; re = perl (ini ^ {|st\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_.-]{8,}|}); sustituto = con_frontera Infisical };
    (* Nombre (con comillas opcionales), separador y valor: se conserva lo
       primero. Contraseñas desde 3 caracteres; claves desde 8, que [KEY]
       aparece en mucho código ([primaryKey: true]). *)
    { tipo = Password;
      re =
        perl ~opts:[ `Caseless ]
          {|([A-Za-z0-9_.-]*(password|passwd|passphrase|pwd|contraseña)["']?[ \t]*[:=][ \t]*)("[^"\n]{3,}"|'[^'\n]{3,}'|[^\s"'\[]{3,})|};
      sustituto = (fun g -> Some (Re.Group.get g 1 ^ marca Password)) };
    (* [pass] y [clave] son palabras corrientes ("Pass: all tests", "La
       clave: Infisical guarda…"): con [:] solo si el valor cierra la frase
       (no le sigue otra palabra) y no empieza por [*] ni signos; con [=],
       siempre ([DB_PASS=…]). *)
    { tipo = Password;
      re =
        perl ~opts:[ `Caseless ]
          ({|([A-Za-z0-9_.-]*(pass|clave)["']?[ \t]*([:=])[ \t]*)("[^"\n]{3,}"|'[^'\n]{3,}'|[^\s"'\[*|}
          ^ "\xC2" (* ¿, ¡, «… *) ^ {|]{3,})([ \t]+[A-Za-z(])?|});
      sustituto =
        (fun g ->
          let v = Re.Group.get g 4 in
          let sigue = Re.Group.test g 5 in
          if Re.Group.get g 3 = ":" && sigue && v.[0] <> '"' && v.[0] <> '\'' then None
          else Some (Re.Group.get g 1 ^ marca Password ^ if sigue then Re.Group.get g 5 else "")) };
    (* En la línea de órdenes: [--password X], [mysql -pX], [-p 'X']
       ([sshpass -p X] también), [curl -u usuario:clave]. Un [-p] suelto
       ([mkdir -p], [ssh -p 22]) no es una contraseña. *)
    { tipo = Password;
      re = perl {|(--password[ \t]+)("[^"\n]+"|'[^'\n]+'|[^\s"']+)|};
      sustituto = (fun g -> Some (Re.Group.get g 1 ^ marca Password)) };
    { tipo = Password;
      re = perl {|((mysql|mysqldump|mysqladmin|mariadb|mariadb-dump)[^\n]*?[ \t]-p)([^\s"']+)|};
      sustituto = (fun g -> Some (Re.Group.get g 1 ^ marca Password)) };
    { tipo = Password;
      re = perl {|((^|[ \t])-p[ \t]+)("[^"\n]+"|'[^'\n]+')|};
      sustituto =
        (fun g ->
          (* [mkdir -p '/ruta con espacios'] no. *)
          let v = Re.Group.get g 3 in
          if String.length v > 1 && (v.[1] = '/' || v.[1] = '$') then None
          else Some (Re.Group.get g 1 ^ marca Password)) };
    { tipo = Password;
      re = perl {|(sshpass[ \t]+-p[ \t]*)([^\s"']+)|};
      sustituto = (fun g -> Some (Re.Group.get g 1 ^ marca Password)) };
    { tipo = Password;
      re = perl {|((^|[ \t])(-u|--user)[ \t]+["']?[^\s:"'/]+:)([^\s"'@]+)|};
      sustituto =
        (fun g ->
          (* [docker run -u 1000:1000] es un uid, no una clave. *)
          let v = Re.Group.get g 4 in
          if String.for_all (fun c -> c >= '0' && c <= '9') v then None
          else Some (Re.Group.get g 1 ^ marca Password)) };
    { tipo = Clave;
      re =
        perl ~opts:[ `Caseless ]
          {|([A-Za-z0-9_.-]*(token|secret|api_?key|access_?key|private_?key|_key|-key|credentials?)["']?[ \t]*[:=][ \t]*)("[^"\n]{8,}"|'[^'\n]{8,}'|[^\s"'\[]{8,})|};
      sustituto =
        (fun g ->
          let v = Re.Group.get g 3 in
          (* Referencias, no valores: $VAR, ${…}, rutas de fichero. *)
          if v.[0] = '$' || v.[0] = '/' || String.starts_with ~prefix:"\"$" v || String.starts_with ~prefix:"\"/" v
          then None
          else Some (Re.Group.get g 1 ^ marca Clave)) };
    (* Variables de entorno con la palabra en medio ([KEY_ID_ACCESS=…],
       [SECRET_ACCESS_KEY_ID=…]): en mayúsculas, sin distinguir dónde. *)
    { tipo = Clave;
      re = perl {|(\b[A-Z0-9_]*(TOKEN|SECRET|KEY|PASSWORD|PASSWD)[A-Z0-9_]*["']?[ \t]*[:=][ \t]*)("[^"\n]{8,}"|'[^'\n]{8,}'|[^\s"'\[$/]{8,})|};
      sustituto = (fun g -> Some (Re.Group.get g 1 ^ marca Clave)) };
    (* Hex de 32 o más poco después de la palabra: un token de Forgejo es
       igual que un hash de git, pero un hash no va detrás de [token]. *)
    { tipo = Clave;
      re =
        perl ~opts:[ `Caseless ]
          {|((token|secret|api[-_]?key|key|password|passwd|clave|contraseña)[^\n]{0,24}?[^0-9a-f\n])[0-9a-f]{32,}|};
      sustituto = (fun g -> Some (Re.Group.get g 1 ^ marca Clave)) };
    { tipo = Entropia;
      re = perl {|[A-Za-z0-9+/_.-]{20,}|};
      sustituto = (fun g -> if parece_secreto (Re.Group.get g 0) then Some (marca Entropia) else None) } ]

let forma s =
  String.map
    (fun c ->
      if c >= 'a' && c <= 'z' then 'a'
      else if c >= 'A' && c <= 'Z' then 'A'
      else if c >= '0' && c <= '9' then '9'
      else c)
    s

let redactar ?(al_redactar = fun _ ~antes:_ _ -> ()) texto =
  List.fold_left
    (fun (texto, cuentas) r ->
      let n = ref 0 in
      let texto =
        Re.replace r.re texto ~f:(fun g ->
            match r.sustituto g with
            | Some s ->
                incr n;
                let i = Re.Group.start g 0 in
                let k = min i 24 in
                al_redactar r.tipo ~antes:(String.sub texto (i - k) k) (forma (Re.Group.get g 0));
                s
            | None -> Re.Group.get g 0)
      in
      (texto, if !n > 0 then (r.tipo, !n) :: cuentas else cuentas))
    (texto, []) reglas
  |> fun (t, c) -> (t, List.rev c)
