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
      (** Cadena de 32 o más caracteres con mayúsculas, minúsculas y
          dígitos, y entropía de Shannon ≥ 4,3 bits por carácter (un hash
          hexadecimal o uno de Nix no llega: no se tocan). *)

val todos : tipo list
val nombre : tipo -> string
(** El que aparece en [[redactado:<nombre>]]. *)

val redactar : string -> string * (tipo * int) list
(** El texto redactado y cuántas sustituciones de cada tipo (solo los que
    tienen alguna). *)

val entropia : string -> float
(** Bits por carácter (Shannon, sobre bytes). *)
