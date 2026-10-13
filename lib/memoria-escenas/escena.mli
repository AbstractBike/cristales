(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Una escena L2: [escenas/<slug>.md] del repo memoria.

    Una cabecera sencilla entre dos líneas [---], una clave por línea
    ([clave: valor]), y el cuerpo en Markdown:

    {v
---
titulo: Flota NixOS
resumen: Cómo se despliega la flota con colmena...
creada: 2026-10-13T20:00:00Z
actualizada: 2026-10-13T21:00:00Z
calor: 3
bloqueada: false
atomos: [a-0123456789ab, a-ba9876543210]
---

## Datos clave
...
    v}

    Las claves que no conoce se conservan tal cual, en su orden: lo que
    añada una persona a mano no se pierde al reescribirla. *)

type t = {
  slug : string;  (** El nombre del fichero sin [.md]. *)
  titulo : string;
  resumen : string;  (** Una frase, para el índice. *)
  creada : string;  (** ISO 8601 en UTC. *)
  actualizada : string;
  calor : int;  (** 1 al crear, +1 al actualizar, suma+1 al fusionar. *)
  bloqueada : bool;  (** La escribió una persona: el código no la toca. *)
  atomos : string list;  (** Los ids L1 de los que sale. *)
  extra : (string * string) list;  (** Claves desconocidas, en su orden. *)
  cuerpo : string;
}

val max_cuerpo : int
(** 1500 caracteres. *)

val longitud : string -> int
(** Caracteres (puntos de código UTF-8), no bytes. *)

val slug_valido : string -> bool
(** Minúsculas ASCII, dígitos y guiones; ni vacío, ni con guion al
    principio o al final; 60 como mucho. *)

val de_texto : slug:string -> string -> (t, string) result
(** Lee un fichero. Sin cabecera, todo es cuerpo y el título es el slug. *)

val a_texto : t -> string
(** Inverso de {!de_texto}: [de_texto ~slug (a_texto e) = Ok e] si los
    campos son de una línea y el cuerpo no empieza ni acaba en blanco. *)

val recortar : ?max:int -> string -> string
(** El cuerpo, quitando líneas enteras desde el final (y los encabezados
    que se queden vacíos) hasta caber en [max] ({!max_cuerpo}). Nunca corta
    una línea por la mitad. *)

val sin_trayectoria : string -> string
(** El cuerpo sin su sección [## Trayectoria] y sin líneas en blanco ni
    sangrías: para comprobar que una edición solo tocó la trayectoria. *)
