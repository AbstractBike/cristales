(* © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
   Libre para investigación; uso comercial: ver COPYRIGHT.md. *)

(** Cristal: qué se vende en un anuncio de televisores de segunda mano (y
    nuevos). Ver [SEMILLA.md]. *)

type tipo = Tv | Monitor | Proyector | Accesorio | Pieza | Lote | Busca | Otro

val tipo_texto : tipo -> string

type decision = Decide of tipo | Defecto of string

val decidir : Memoria_anuncio.anuncio -> decision

val estado : ?declarado:string -> Memoria_anuncio.anuncio -> string * string option
(** El estado («precintado», «nuevo», «como-nuevo», «usado», «averiado», «para-piezas») y la avería que
    dice, si la dice («pantalla rota», «rayas», «manchas», «retroiluminacion», «no enciende»,
    «quemado», «sin imagen»). [declarado], el que declara el portal (la línea «Estado:»): la avería del
    texto manda sobre él, y él sobre lo demás que diga el texto. *)

val aplicar : string -> (string, string) result
(** Pura. El JSON con [tipo], la tele (marca, modelo canónico, serie, año, pulgadas, tecnología,
    resolución, Hz, HDMI 2.1, sistema, gama, precios de catálogo), su estado y avería, lo que dice de
    garantía, factura, caja, envío, recogida y cambio, y el precio; defecto si no sabe si es una tele
    o, si lo es, cuántas pulgadas tiene («no dice las pulgadas», «varias pulgadas: 55, 65»). *)

val cristal : (string, string) Cristal.cristal
