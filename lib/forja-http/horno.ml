(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Sin licencia. Ver COPYRIGHT.md. *)

(* El horno es el directorio donde la forja deja las tareas maduras, listas
   para nuclear: horno/<tarea>/SEMILLA.md y horno/<tarea>/nucleacion.md.
   La nucleación, la revisión y el commit del cristal son humanos (o de un
   agente), fuera del camino caliente. *)

let cocer ~dir ~prompt tarea informe muestras =
  let d = Eio.Path.(dir / Forja.Tarea.to_string tarea) in
  Eio.Path.mkdirs ~exists_ok:true ~perm:0o755 d;
  Eio.Path.save ~create:(`Or_truncate 0o644) Eio.Path.(d / "SEMILLA.md")
    (Forja.Semilla.markdown tarea informe muestras);
  Eio.Path.save ~create:(`Or_truncate 0o644) Eio.Path.(d / "nucleacion.md")
    (Forja.Semilla.nucleacion ~prompt muestras);
  Eio.Path.native_exn d
