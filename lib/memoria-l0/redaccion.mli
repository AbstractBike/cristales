(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Redacción de secretos (doc/memoria.md, «Seguridad»): lo que va a
    [memoria_l0] pasa antes por aquí. Cada secreto se sustituye por
    [[redactado:<tipo>]]; en asignaciones, [Bearer] y URLs se conserva el
    nombre, la palabra o el esquema, que sí dicen algo.

    Se aplican de lo más específico a lo más genérico, así que un token
    conocido se cuenta por su tipo y no como «entropía». Mejor redactar de
    más que de menos. *)

type tipo =
  | Pem  (** Bloque [-----BEGIN … KEY-----] (hasta su [END] o el final). *)
  | Anthropic  (** [sk-ant-…] *)
  | Openai  (** [sk-…], [sk-proj-…] *)
  | Github  (** [ghp_], [gho_], [ghu_], [ghs_], [ghr_], [github_pat_] *)
  | Gitlab  (** [glpat-…] *)
  | Slack  (** [xoxb-], [xoxp-], [xoxa-], [xoxr-], [xoxs-] *)
  | Aws  (** [AKIA…], [ASIA…] *)
  | Jwt  (** [eyJ….….…] *)
  | Bearer  (** [Bearer <token>] *)
  | Url  (** [esquema://usuario:clave@] *)
  | Clave  (** [*_TOKEN=], [*_KEY=], [*SECRET*=], [api_key: …] *)
  | Password  (** [password=], [passwd:], [pwd=] *)
  | Entropia
      (** Una cadena de 20 o más caracteres de token con algún trozo (entre
          [/], [_], [.], [-], [=]) de 16 o más que parece al azar:
          mayúsculas, minúsculas y dígitos, que cambian de clase en al
          menos el 45 % de los pares de vecinos, y entropía ≥ 3,5 bits por
          carácter. Un hash hexadecimal o de Nix (sin mayúsculas), una ruta
          o un identificador CamelCase no llegan. *)

val todos : tipo list
val nombre : tipo -> string
(** El que aparece en [[redactado:<nombre>]]. *)

val redactar :
  ?al_redactar:(tipo -> antes:string -> string -> unit) -> string -> string * (tipo * int) list
(** El texto redactado y cuántas sustituciones de cada tipo (solo los que
    tienen alguna). [al_redactar] ve cada sustitución, para auditarla sin
    enseñar el secreto: lo que lo precede (hasta 24 bytes, ya redactado por
    las reglas anteriores) y su {!forma}. *)

val forma : string -> string
(** Las minúsculas a [a], las mayúsculas a [A] y los dígitos a [9]: la
    silueta de un acierto, no su contenido. *)

val entropia : string -> float
(** Bits por carácter (Shannon, sobre bytes). *)
