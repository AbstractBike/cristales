(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

type tipo = Pem_base64 | Hex_tras_clave | Valor_tras_clave

let nombre = function
  | Pem_base64 -> "pem-base64"
  | Hex_tras_clave -> "hex-tras-clave"
  | Valor_tras_clave -> "valor-tras-clave"

let perl p = Re.compile (Re.Perl.re ~opts:[ `Caseless ] p)
let clave = {|(token|key|secret|password|passwd|api[-_]?key)|}

let patrones =
  [ (Pem_base64, Re.compile (Re.Perl.re {|LS0t[A-Za-z0-9+/=]{20,}|}));
    (Hex_tras_clave, perl (clave ^ {|[^\n]{0,24}?[^0-9a-f][0-9a-f]{32,}|}));
    (Valor_tras_clave, perl (clave ^ {|[A-Za-z0-9_-]*["']?[ \t]*[:=][ \t]*["']?[A-Za-z0-9_+/.-]{20,}|})) ]

let buscar texto =
  List.concat_map
    (fun (t, re) -> List.map (fun g -> (t, Redaccion.forma (Re.Group.get g 0))) (Re.all re texto))
    patrones
