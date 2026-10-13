(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** El cursor de la consolidación: [.estado] en el propio repo memoria.

    Vive junto a lo que describe: el commit que reescribe las escenas
    mueve también el cursor, y revertirlo devuelve los dos a la vez (en
    GreptimeDB el cursor podría ir por delante de unas escenas que nadie
    ha subido). *)

type t = {
  cursor : int;  (** El [escrito] (ms) del último átomo L1 consolidado. *)
  persona : string option;  (** Cuándo se escribió la persona (ISO). *)
  atomos_desde_persona : int;
}

val inicial : t
val de_texto : string -> t
(** Lo que no entiende, a {!inicial}. *)

val a_texto : t -> string
