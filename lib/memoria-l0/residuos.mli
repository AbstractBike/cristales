(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Red de seguridad de {!Redaccion}: patrones sospechosos que se buscan en
    el texto ya limpio y redactado, el que iría a L0. Un acierto es un
    hueco de la redacción (o un falso positivo que justificar). Más amplios
    que las reglas a propósito: solo cuentan, no sustituyen. *)

type tipo =
  | Pem_base64  (** [LS0t…]: un PEM codificado en base64. *)
  | Hex_tras_clave  (** Hex de 32 o más poco después de token/key/secret. *)
  | Valor_tras_clave
      (** token/key/secret/password/apikey (con [-]/[_], cualquier
          capitalización), [:] o [=] y 20 o más caracteres de token. *)

val nombre : tipo -> string

val buscar : string -> (tipo * string) list
(** Cada acierto con su silueta ({!Redaccion.forma}), nunca el valor. *)
