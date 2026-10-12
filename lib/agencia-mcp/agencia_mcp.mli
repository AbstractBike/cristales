(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** La agencia como servidor MCP: un agente (Claude Code, Claude Desktop)
    crea agentes, les hace encargos y juzga lo que devuelven; la agencia
    elige el modelo de cada encargo y lo guarda todo en su archivo.

    Herramientas fijas: [agencia_crear], [agencia_agentes],
    [agencia_historico], [agencia_encargar] y [agencia_juzgar]. Y una por
    agente, con su nombre, que es [agencia_encargar] para ese agente.

    Puro: el LLM, el archivo y los ids se inyectan ({!efectos}); el
    transporte (stdio) lo pone [bin/agencia-mcp]. *)

type efectos = {
  archivo : Agencia.Archivo.t;
  llamar : Agencia.Agente.t -> Agencia.Modelo.t -> string -> Agencia.respuesta;
      (** Pide al modelo las instrucciones del agente sobre esa entrada. *)
  id : unit -> string;  (** Un id de encargo nuevo: 16 hex. *)
  escalera : Agencia.Modelo.t list;
      (** La de los agentes que se crean sin la suya. *)
  politica : Agencia.Politica.t;
}

val encargar : efectos -> Agencia.Agente.t -> ?modelo:Agencia.Modelo.t -> string -> Agencia.Encargo.t
(** Elige el modelo (o usa [modelo]), lo llama y registra el encargo. *)

val servidor : efectos -> Mcp_rpc.servidor
