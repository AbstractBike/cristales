(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** El servidor MCP [memoria]: el recall fino, bajo demanda, de lo que el
    hook SessionStart solo enseña por encima (doc/memoria.md).

    - [memoria_buscar]: átomos L1 vigentes por texto completo.
    - [memoria_conversacion]: mensajes L0 por texto completo.
    - [memoria_escena]: el Markdown de una escena del repo. *)

type efectos = {
  sql : string -> (Yojson.Safe.t list, string) result;
      (** Una consulta en la base [memoria]: sus filas, o el error. *)
  repo : string;  (** El checkout del repo [memoria]. *)
  tablas : Consulta.tablas;
}

val instrucciones : string
val servidor : efectos -> Mcp_rpc.servidor

val fecha_de_ms : int -> string
(** [AAAA-MM-DD HH:MM], en UTC. *)
