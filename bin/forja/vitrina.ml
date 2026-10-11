(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

(* Los cristales que atiende el proxy. Añadir uno es un commit: se nuclea
   desde el horno, se revisa, se mete en cristales/<tarea>/ y se registra
   aquí. Los cristales tipados se adaptan a texto → texto; el contexto que
   necesiten (la fecha de hoy) lo pone el adaptador, no el cristal. *)

let tarea n = Result.get_ok (Forja.Tarea.explicita n)

let hoy () =
  let t = Unix.gmtime (Unix.time ()) in
  { Fecha_es.anyo = t.tm_year + 1900; mes = t.tm_mon + 1; dia = t.tm_mday }

let fecha_es =
  Cristal.cristal "fecha-es" (fun texto ->
      Result.map Fecha_es.iso (Fecha_es.aplicar ~hoy:(hoy ()) (String.trim texto)))

let vitrina = Forja.Vitrina.(vacia |> con (tarea "fecha-es") `Mixta fecha_es)
