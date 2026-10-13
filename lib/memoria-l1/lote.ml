(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

let es_herramienta l =
  let l = String.trim l in
  l = "" || (String.starts_with ~prefix:"[herramienta" l && String.ends_with ~suffix:"]" l)

(* Al menos dos letras o cifras fuera de las líneas de herramientas. *)
let util (m : Atomo.mensaje) =
  let resto = List.filter (fun l -> not (es_herramienta l)) (String.split_on_char '\n' m.texto) in
  let alfanumericos =
    List.fold_left
      (fun n l -> String.fold_left (fun n c -> match c with 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '\128' .. '\255' -> n + 1 | _ -> n) n l)
      0 resto
  in
  alfanumericos >= 2

type t = { fondo : Atomo.mensaje list; nuevos : Atomo.mensaje list; hasta : int }
type paso = Nada | Avanzar of int | Lote of t

let rec tomar n = function [] -> [] | _ when n <= 0 -> [] | x :: r -> x :: tomar (n - 1) r

let ultimos n l = List.rev (tomar n (List.rev l))

let siguiente ?(nuevos = 10) ?(fondo = 5) ~cursor mensajes =
  let orden (a : Atomo.mensaje) (b : Atomo.mensaje) = compare (a.ts, a.uuid) (b.ts, b.uuid) in
  let mensajes = List.sort_uniq orden mensajes in
  let despues (m : Atomo.mensaje) = match cursor with None -> true | Some c -> m.ts > c in
  let antes, pendientes = List.partition (fun m -> not (despues m)) mensajes in
  match (pendientes, List.filter util pendientes) with
  | [], _ -> Nada
  | _, [] -> Avanzar (List.fold_left (fun a (m : Atomo.mensaje) -> max a m.ts) min_int pendientes)
  | _, (primero :: _ as utiles) ->
      let lote = tomar nuevos utiles in
      let ultimo = (List.nth lote (List.length lote - 1)).ts in
      (* Los del mismo ts que el último, también: el cursor no puede partirlos. *)
      let lote = lote @ List.filter (fun (m : Atomo.mensaje) -> m.ts = ultimo && not (List.memq m lote)) utiles in
      let previos = List.filter (fun (m : Atomo.mensaje) -> util m && m.ts < primero.ts) (antes @ pendientes) in
      Lote { fondo = ultimos fondo previos; nuevos = lote; hasta = ultimo }
