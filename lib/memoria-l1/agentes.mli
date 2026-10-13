(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Los dos agentes de la agencia que usa la destilación, definidos aquí
    (sus instrucciones son [prompts/memoria-*.md], dentro del binario).

    Por defecto, cada uno a quien le toca mientras la agencia no sepa más
    (luego manda el histórico: el más barato fiable):

    - [memoria-atomos] a [claude-sonnet-5-5]: es la pieza que decide qué se
      recuerda; separar lo que el usuario acepta de lo que el asistente solo
      propone, y callarse ante lo rutinario, pide criterio, y un átomo malo
      contamina todo lo de encima (escenas, persona). La agencia explora
      haiku y gemma uno de cada cinco encargos y bajará si lo hacen bien;
    - [memoria-dedup] a [claude-haiku-5-5]: comparar frases cortas con sus
      candidatos y devolver una acción es acotado, y si se equivoca hacia
      [guardar] no se pierde nada. *)

val atomos : escalera:Agencia.Modelo.t list -> (Agencia.Agente.t, string) result
val dedup : escalera:Agencia.Modelo.t list -> (Agencia.Agente.t, string) result

val defecto : preferido:string -> Agencia.Modelo.t list -> Agencia.Modelo.t option
(** El [preferido] si está en la escalera; si no, [None] (el más capaz). *)

val asegurar : Agencia.Archivo.t -> Agencia.Agente.t -> bool
(** Lo guarda en el archivo si no estaba o si ha cambiado (instrucciones,
    escalera, defecto, descripción o [max_tokens]). [true] si lo guardó. *)
