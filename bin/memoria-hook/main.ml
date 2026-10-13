(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(* memoria-hook: el hook SessionStart de Claude Code (doc/memoria.md). Lee
   persona.md y el índice de escenas del repo memoria y escribe por stdout el
   JSON del hook con el contexto. Sin red y sin nada variable: la misma
   salida mientras el repo no cambie, para la caché de prompts. No falla
   nunca: sin repo, o con cualquier error, no escribe nada y sale con 0.

   MEMORIA_REPO   el checkout (/logical-node/repositories/logical-license/memoria) *)

let () =
  let repo =
    match Sys.getenv_opt "MEMORIA_REPO" with
    | Some r when String.trim r <> "" -> String.trim r
    | _ -> "/logical-node/repositories/logical-license/memoria"
  in
  (try print_string (Memoria_recall.Contexto.de_repo repo)
   with e -> prerr_endline ("memoria-hook: " ^ Printexc.to_string e));
  exit 0
