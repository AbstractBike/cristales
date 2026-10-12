# Semilla: grafica-anuncio

Qué se vende en un anuncio de segunda mano de la categoría de informática:
una gráfica suelta (y cuál, y en qué estado), o un PC, un portátil, una pieza
para una gráfica, un componente, un lote, alguien que busca.

- Entrada: el anuncio en líneas `Título: …`, `Categoría: …` (la del portal,
  si la hay) y `Descripción: …` (hasta el final). Sin `Título:`, todo el texto
  es el título (lo que manda un agente por MCP).
- Salida: JSON con `tipo` (`grafica`, `antigua`, `profesional`, `pc`,
  `portatil`, `pieza`, `componente`, `busca`, `lote`, `otro`), la gráfica
  (`modelo`, `nombre`, `fabricante`, `vram`, `anyo`, `pvp`, `rendimiento`,
  como en grafica-modelo; `null` si no es una gráfica suelta), su `estado`
  (`nueva`, `usada`, `averiada`) y lo que dice de `mineria`, `garantia`,
  `factura`, `caja` y `cambio` (`si`, `no`, `?`).

Antes era líquida: el anuncio al LLM. graficas.email la llama como
herramienta (la forja en su variante MCP) en cada anuncio que trae un portal;
con el defecto decide la app y, si no le basta, el LLM por la forja con la
misma tarea.

Lo que es se decide por el título y la categoría; la descripción solo da el
modelo si el título no lo dice, y el estado. Muestras: Wallapop (API de
búsqueda, con su taxonomía) y Kleinanzeigen (Grafikkarten, c225), 2026-10-12.

## Ejemplos

| Título | Categoría | Salida (tipo, modelo) |
|---|---|---|
| `ASUS Dual GeForce RTX 3060 ti V2 OC Edition` | Computer components & parts | grafica, rtx-3060-ti |
| `Tarjeta Gráfica MSI GTX 1080 Gaming x 8GB` | Gaming desktops | grafica, gtx-1080 (el título manda sobre la categoría) |
| `Tarjeta Gráfica ELSA Rx580 2048sp averiada` | | grafica, rx-580, averiada |
| `Asus TUF Gaming RTX 3080 OC mit Alphacool Wasserkühlung` | Grafikkarten | grafica, rtx-3080 (la refrigeración viene con ella) |
| `Sapphire Nitro+ RX 6800 XT + Alphacool Eiswolf 2 AIO - DEFEKT` | Grafikkarten | grafica, rx-6800-xt, averiada |
| `Gigabyte RTX 4070 TI Aorus Master Tausch Radeon RX7900/9070XT` | Grafikkarten | grafica, rtx-4070-ti, cambio (lo de detrás de «Tausch» es lo que quiere) |
| `AMD Radeon™ RX 7900 GRE Neu!` | Grafikkarten | grafica, rx-7900-gre, nueva |
| `RTX 4070 KFA2 EX GAMER 12GB in OVP wie Neu` | Grafikkarten | grafica, rtx-4070, usada, caja |
| `Alienware M18 R1 RTX 4090` | Laptops | portatil |
| `ASUS ROG STRIG G16 \| I9 14900HX - RTX 4070` | Gaming laptops | portatil |
| `PC Gaming Ryzen 7 5800X3D + RTX 3080 10GB` | Gaming desktops | pc |
| `HYPERX OMEN 45L - Ultra 7 270K plus + 3080 MSI` | Desktop computers | pc |
| `Backplate original MSI RTX 4090 Trio` | | pieza |
| `EK Waterblocks Backplate für RTX 3080/3090` | Grafikkarten | pieza |
| `Alphacool GPX \| EVGA XC3 RTX 3080 \| Eisblock NEU` | Grafikkarten | pieza |
| `Razer Core con Gráfica GTX 1060g1 gaming 3g` | | pieza (carcasa eGPU) |
| `Pack de 4 Tarjetas Gráficas vintage` | | lote |
| `✨SUCHE: NVIDIA GeForce RTX 2080 3050 2070 …` | Grafikkarten | busca |
| `Fuente de Alimentación NOX AT-500P12P 500W` | | componente |
| `Tarjeta Gráfica Gigabyte GTX 260 OC` | | antigua |
| `Tarjeta Gráfica Gigabyte GeForce` + descripción «Vendo mi RTX 3060 Gaming OC 12GB» | | grafica, rtx-3060 |

Y el estado por lo que dicen título y descripción: «Nunca minada, solo juegos.
Con factura y garantía hasta 2026. Sin caja.» da `mineria: no`, `factura: si`,
`garantia: si`, `caja: no`; «Sin ninguna avería» no es averiada; «como nueva»,
«wie neu» y «like new» son usadas.

## Invariantes

- `tipo` es uno de los diez; si es `grafica`, `modelo` es una clave del
  catálogo de grafica-modelo y `vram` una de sus memorias.
- Una pieza lo es si su palabra (backplate, disipador, Wasserblock, Eisblock,
  eGPU, «solo caja»…) no va detrás del modelo y de un «con», «mit», «inkl.» o
  «+»; las débiles (ventilador, cable, soporte) solo al principio del título.
- Un título con procesador y gráfica es un sistema (PC), salvo que sea de un
  portátil (palabra, línea de portátil o procesador HX/H/U).
- Las negaciones (sin, nunca, ohne, kein, never…) en las dos palabras de
  antes dan la vuelta a minería, garantía, factura, caja y avería.

## Fuera de dominio (defecto)

- Gráfica sin modelo en el título ni uno solo en la descripción:
  «gráfica sin modelo».
- Varias gráficas en el título: «varios modelos: rx-6800, rx-6800-xt».
- Una gráfica que el catálogo no tiene: «modelo desconocido: rtx 4060 super».


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
