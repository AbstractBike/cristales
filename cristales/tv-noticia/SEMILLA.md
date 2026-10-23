# Semilla: tv-noticia

De qué va una noticia de imagen y sonido para quien sigue los televisores: si
va de teles, del resto de la imagen y el sonido (barras de sonido, altavoces,
auriculares, proyectores, Blu-ray, streaming, monitores, HDR) o de otra cosa;
qué tipo de noticia es, qué marcas y modelos nombra y si nombra alguna serie
que aún no estaba en el catálogo.

- Entrada: líneas `Título: …`, `Resumen: …` y `Fuente: …`, como en
  grafica-noticia y leídas con su `partes`; sin `Título:`, todo es el título.
- Salida: JSON `{"tema": "tv"|"imagen-sonido"|"otro", "tipo":
  "lanzamiento"|"precio"|"oferta"|"analisis"|"software"|"mercado"|"rumor"|"otro",
  "marcas": [...], "modelos": [...], "nuevos": [...], "tecnologias": [...]}`.
  `modelos`, los canónicos de tv-modelo de las series del catálogo, sin
  tamaño («LG OLED C6», «Sony BRAVIA 9 II», «TCL QM7L»); `nuevos`, los que
  lee de un código y el catálogo no tiene («Samsung S99H»); `marcas`, claves
  de tv-modelo; `tecnologias` (añadido), las que nombra el título. Fuera de
  tema (`otro`), el tipo es `otro` y las listas van vacías.

Antes era líquida. smarttv.email la llama con cada titular de sus feeds; con
el defecto, el LLM por la forja con la misma tarea.

Se decide por el título; el resumen solo suma marcas y modelos. El tipo, por
la primera lista que casa, en este orden: análisis (review, test, vs, best,
comparativa), oferta (deal, bon plan, Angebot, chollo), precio (prices, more
expensive, teurer), rumor, software (update, app, webOS, Titan OS), mercado
(market, Omdia, returns to, production), lanzamiento (launches, unveils,
available, llega, erscheint, new). Una serie nombrada sin código es de la
marca nombrada antes más cerca: «Review: Sony A1 OLED» no es la LG A1.

Muestras: RSS de FlatpanelsHD (noticias y análisis), HDTVTest (YouTube),
AVForums, What Hi-Fi, TechRadar (televisores), Digital Trends (home theater),
Display Daily, Xataka, Xataka Home, AVPasión, 4kfilme, areaDVD, HDblog y Les
Numériques, 2026-10-23, en `test/titulares.jsonl`. **Sin LLM, 578 de 623**:
160 de teles, 248 de imagen y sonido, 170 de otra cosa; 45 defectos, casi
todos análisis antiguos de FlatpanelsHD con el modelo a secas («Review:
Panasonic VT60», «Review: LG UF8500») y noticias de marcas de teles que no
son de teles («Xiaomi 18 Pro», «Samsung Gear VR»).

## Ejemplos

| Título | tema, tipo | modelos / nuevos |
|---|---|---|
| `TCL QM7L review: the best mid-range TV of 2026` | tv, analisis | TCL QM7L |
| `Review: TCL C8L / QM8L` | tv, analisis | TCL C8L, TCL QM8L |
| `Review: Samsung S99H / S95H (QD-OLED)` | tv, analisis | Samsung S95H / Samsung S99H |
| `Actualité : Bon plan – Le téléviseur LG 65G6 "5 étoiles" à 2 456,07 €` | tv, oferta | LG OLED G6 |
| `Roku launches Pro LX OLED TVs with higher brightness` | tv, lanzamiento | |
| `Many TVs are about to become more expensive, warns Omdia` | tv, precio | |
| `Panasonic returns to Canada with 2026 OLED and miniLED LCD TVs` | tv, mercado | |
| `SkyShowtime app comes to Philips TVs with Titan OS` | tv, software | |
| `Sonos Beam Ultra review: … Dolby Atmos soundbars` | imagen-sonido, analisis | |
| `New Apple TV 4K (4th Gen) unveiled with A19 chip` | imagen-sonido, lanzamiento | |
| `OLED monitor prices set to fall further` | imagen-sonido, precio | |
| `Adiós al juego ilimitado: Xbox Cloud Gaming …` | otro, otro | |

## Invariantes

- `tema` y `tipo` son de sus conjuntos; fuera de tema, tipo `otro` y
  listas vacías.
- La red lee sin defecto al menos 575 de los 623 titulares de la semilla.

## Fuera de dominio (defecto)

- Un titular con una marca de teles (LG, Samsung, Sony, TCL, Hisense,
  Philips, Panasonic, Xiaomi) que no se sabe si va de teles: «no sé si va de
  teles».


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
