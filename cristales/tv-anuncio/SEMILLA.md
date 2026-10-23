# Semilla: tv-anuncio

Qué se vende en un anuncio de televisores, de segunda mano o nuevos, en
España y Europa: una tele (y cuál, de cuántas pulgadas y en qué estado), un
monitor, un proyector, un accesorio (mando, soporte, Fire TV Stick, barra de
sonido), una pieza (placa base, T-CON, fuente, tiras LED, panel), un lote o
alguien que busca. Es lo que smarttv.email pregunta de cada anuncio que trae
un portal.

- Entrada: el anuncio en líneas `Título: …`, `Categoría: …`, `Precio: …`,
  `Portal: …`, `País: …`, `Estado: …` (opcional: el estado que declara el
  portal) y `Descripción: …` (hasta el final), como en memoria-anuncio y
  leída con su `partes` y su `leer_precio`. Sin `Título:`, todo es el título.
- Salida: JSON

```
{"tipo": "tv"|"monitor"|"proyector"|"accesorio"|"pieza"|"lote"|"busca"|"otro",
 "marca": str|null, "modelo": str|null, "serie": str|null, "anio": int|null,
 "pulgadas": int|null, "tecnologia": "oled"|"qd-oled"|"mini-led"|"rgb-mini-led"|"qled"|"led"|null,
 "resolucion": "4k"|"8k"|"fhd"|"hd"|null, "hz": int|null, "hdmi21": bool|null,
 "sistema": "google-tv"|"webos"|"tizen"|"vidaa"|"fire-tv"|"android-tv"|"titan"|null,
 "gama": "alta"|"media-alta"|"media"|"entrada"|null,
 "precio_lanzamiento": float|null, "precio_nuevo": float|null,
 "estado": "precintado"|"nuevo"|"como-nuevo"|"usado"|"averiado"|"para-piezas",
 "averia": "pantalla rota"|"rayas"|"manchas"|"retroiluminacion"|"no enciende"|"quemado"|"sin imagen"|null,
 "garantia": bool|null, "factura": bool|null, "caja": bool|null, "envio": bool|null,
 "solo_recogida": bool|null, "cambio": bool|null, "precio": float|null}
```

`marca` es la clave de tv-modelo (`lg`, `samsung`, `xiaomi`…); `modelo`,
`serie`, `anio`, `gama` y los precios, los de tv-modelo (el modelo
canónico, «LG OLED77C6»). Los campos de la tele (`pulgadas`, `tecnologia`,
`resolucion`, `hz`, `hdmi21`, `sistema`) van solo con `tv`, `monitor`,
`lote` y `busca` (`resolucion` también con `proyector`); con lo demás,
`null`. `precio_nuevo` (añadido al contrato) es el de idealo.es del
2026-10-23, nueva; `precio_lanzamiento` es siempre `null` en esta versión.
`precio` es el de la línea `Precio:`; 0, `null`.

Antes era líquida: el anuncio al LLM. smarttv.email la llama como herramienta
(la forja en su variante MCP) en cada anuncio; con el defecto decide la app o
el LLM por la forja con la misma tarea.

## Cómo se decide

Lo que es, por el título, mirando qué va antes: «Main Board TV LG» es una
pieza; «Mando a distancia Samsung Smart TV», un accesorio; «TV Box», «TV
Stick», «Apple TV», accesorios (en el mismo sitio, la frase más larga);
«Universal TV Standfuß», un accesorio (justo detrás de «TV»); «Original LG
Wandhalterung für 77 Zoll TVs», un accesorio; «Sony Bravia 47 Zoll (Ohne
Fernbedienung)», una tele (una marca con su tamaño es una tele, donde el
tamaño). «Despiece» al principio es una pieza; detrás de la tele, la tele
para piezas. «Lote», «Konvolut», «2 Televisores», o dos teles de dos marcas,
un lote. Si el título no dice qué es, la categoría del portal (`Remote
controls`, `TV stands`, `Projectors`…); con la de teles (`TVs`,
`Fernseher`) y una marca, una tele.

Las pulgadas de la tele, por lo que más fe da en el título: el código de un
modelo, las unidades, los cm, el tamaño de un código sin modelo, los números
sueltos. Si no casan, defecto (salvo un suelto detrás de la unidad, o unos cm
que no casan con las pulgadas: «138 cm 65 Zoll» son 65). Si el título calla,
la descripción: unidades, códigos o cm detrás de «Diagonale». El modelo, del
título; si no, de la descripción si nombra uno solo; el tamaño de su código
manda.

El estado: la avería que dice el texto manda (`para-piezas`: «para piezas»,
«Bastler», «Ersatzteile», «despiece»; `averiado`: una avería o «defekt»,
«no funciona», «averiada»); si no, el que declara el portal (`Estado: Como
nuevo`); si no, lo que dice el texto (`precintado`: «precintado», «sin
abrir», «versiegelt»; `como-nuevo`: «como nuevo», «wie neu», «neuwertig»,
«B-Ware»; `nuevo`: «nuevo», «neu», «new» en el título, o «a estrenar»,
«unbenutzt»); si no, `usado`. Las negaciones (sin, no, ni, kein, keine,
keinerlei, ohne, senza…) en las dos palabras de antes, o más allá de un «o»,
«oder», «ni», dan la vuelta: «keine Pixelfehler oder Burn-in» no es una
avería. Una «rotura» o un «botón roto» no son una pantalla rota; «LED
Backlight», tampoco una avería de retroiluminación.

`envio`: «envío», «Versand», «spedizione», «Correos», «DHL»…; «nur
Abholung», «solo en mano», «kein Versand» dan `envio: false` y
`solo_recogida: true`; con envío, `solo_recogida: false`. `garantia`:
«Privatverkauf», «keine Garantie», «ohne Gewährleistung», `false`.

Muestras: Wallapop (API de búsqueda; Imagen: TVs y proyectores, subcategoría
10206, y TVs, 10414, con `next_page`; ES, IT y PT) y Kleinanzeigen (Fernseher,
c175; sus descripciones vienen cortadas a ~200 caracteres), 2026-10-23, en
`test/anuncios.jsonl`. **Sin LLM, 1.084 de 1.181**: 667 de 712 de Wallapop y
417 de 469 de Kleinanzeigen. De los 97 defectos, 84 son teles que no dicen
sus pulgadas ni en el título ni en la descripción («Televisión Philips»,
«Hisense Fernseher»), 11 varias pulgadas (tiendas con «55, 65, 75, 85 Zoll»,
«65 U 77 HQ») y 2 que no se sabe si son teles (IPTV).

## Ejemplos

| Título | tipo, modelo, pulgadas, tecnología, estado |
|---|---|
| `Xiaomi TV S Mini 75 2025 75 Pulgadas` (Wallapop, 550 €) | tv, Xiaomi TV S Mini LED 75 2025, 75, mini-led (2025, 144 Hz), usado; con `Estado: Como nuevo`, como-nuevo |
| `LG OLED77B42LA 77 Zoll (195 cm)` | tv, LG OLED77B4, 77, oled, usado |
| `Samsung GQ77S95HFT OLED 195,6 cm (77 Zoll)` | tv, Samsung TQ77S95H, 77, qd-oled, usado |
| `Hisense 85U7Q PRO – 85 Zoll ULED Mini-LED 165 Hz` | tv, Hisense 85U7Q PRO, 85, mini-led, usado |
| `TV Samsung 75 pulgadas para piezas` | tv, -, 75, -, para-piezas |
| `TV Sony Bravia 75 Mini LED (Panel Roto)` | tv, -, 75, mini-led, averiado (pantalla rota) |
| `Xiaomi TV F 43 Zoll – NEU & OVP – Ungeöffnet und versiegelt` | tv, Xiaomi TV F 43, 43, -, precintado |
| `Main Board TV LG EAX69830902` | pieza |
| `Amazon Fire TV Stick 4K Select` | accesorio |
| `Proyector Hisense PT1 Tiro Corto + Pantalla 100”` | proyector |
| `Monitor Gaming Philips Evnia 49 QD-OLED` | monitor |
| `Lote de 3 Televisores (2 Sony, 1 LG)` | lote |
| `SUCHE Röhrenfernseher klein !` | busca |
| `Laserdisc Demolition Man` | otro |

## Invariantes

- `tipo`, `tecnologia`, `estado` y los demás enumerados son de sus
  conjuntos; una `tv` tiene siempre `pulgadas`, entre 13 y 120.
- Con `modelo` hay `marca`; están todas las claves del contrato.
- La red lee sin defecto al menos 1.080 de los 1.181 anuncios de la semilla.
- Una avería que dice el texto manda sobre «nueva»: «TV TCL 75P8L Nueva Rota.» es averiado, pantalla rota. En el título
  basta la palabra («rota», «rotto», «partido», «kaputt», «cassé», «golpe»); en la descripción, la frase («pantalla rota»,
  «panel roto», «unidades rotas», «se reinicia sola», «defectuosa», «no funciona»): un «botón roto» o «la peana rota» de la
  descripción no son la pantalla.

## Fuera de dominio (defecto)

- Una tele sin pulgadas: «no dice las pulgadas».
- Varias en el título que no casan: «varias pulgadas: 55, 65, 75, 85».
- Con la categoría de teles o una marca, pero nada que diga qué es: «no sé si
  es una tele».


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
