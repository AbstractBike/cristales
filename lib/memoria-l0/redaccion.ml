(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type tipo = Pem | Anthropic | Openai | Github | Gitlab | Slack | Aws | Jwt | Bearer | Url | Clave | Password | Entropia

let todos = [ Pem; Anthropic; Openai; Github; Gitlab; Slack; Aws; Jwt; Bearer; Url; Clave; Password; Entropia ]

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

let parece_secreto s =
  String.length s >= 32
  && existe (fun c -> c >= 'A' && c <= 'Z') s
  && existe (fun c -> c >= 'a' && c <= 'z') s
  && existe (fun c -> c >= '0' && c <= '9') s
  && entropia s >= 4.3

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
    { tipo = Openai; re = perl (ini ^ {|sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}|}); sustituto = con_frontera Openai };
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
    (* Nombre (con comillas opcionales), separador y valor: se conserva lo
       primero. Contraseñas desde 3 caracteres; claves desde 8, que [KEY]
       aparece en mucho código ([primaryKey: true]). *)
    { tipo = Password;
      re =
        perl ~opts:[ `Caseless ]
          {|([A-Za-z0-9_.-]*(password|passwd|passphrase|pwd)["']?[ \t]*[:=][ \t]*)("[^"\n]{3,}"|'[^'\n]{3,}'|[^\s"'\[]{3,})|};
      sustituto = (fun g -> Some (Re.Group.get g 1 ^ marca Password)) };
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
    { tipo = Entropia;
      re = perl {|[A-Za-z0-9+/_=-]{32,}|};
      sustituto = (fun g -> if parece_secreto (Re.Group.get g 0) then Some (marca Entropia) else None) } ]

let redactar texto =
  List.fold_left
    (fun (texto, cuentas) r ->
      let n = ref 0 in
      let texto =
        Re.replace r.re texto ~f:(fun g ->
            match r.sustituto g with
            | Some s ->
                incr n;
                s
            | None -> Re.Group.get g 0)
      in
      (texto, if !n > 0 then (r.tipo, !n) :: cuentas else cuentas))
    (texto, []) reglas
  |> fun (t, c) -> (t, List.rev c)
