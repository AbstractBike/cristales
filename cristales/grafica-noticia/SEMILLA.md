# Semilla: grafica-noticia

De qué va una noticia de hardware para quien sigue las gráficas de
sobremesa: si va de ellas, qué tipo de noticia es, de qué fabricantes y
modelos, y si nombra alguna que aún no existía.

- Entrada: líneas `Título: …`, `Resumen: …` y `Fuente: …`; sin `Título:`,
  todo es el título.
- Salida: JSON `{"tema": "graficas"|"otro", "tipo": "drivers"|"analisis"|
  "rumor"|"precio"|"mercado"|"lanzamiento"|"anuncio"|"otro", "fabricantes":
  [...], "modelos": [...], "nuevos": [...]}`. `modelos`, claves de
  grafica-modelo; `nuevos`, lo que parece una gráfica y no está en el catálogo
  («arc b770») o una memoria que su modelo no tenía («rtx-5080 24gb»).

Antes era líquida. graficas.email la llama como herramienta (la forja en su
variante MCP) con cada titular de sus feeds; con el defecto, el LLM por la
forja con la misma tarea.

Se decide por el título: el resumen solo suma modelos y marcas. Muestras: RSS
de TechPowerUp, Wccftech, Tom's Hardware, ComputerBase, PCGH, HardZone y El
Chapuzas Informático, 2026-10-12.

## Ejemplos

| Título | tema, tipo | modelos / nuevos |
|---|---|---|
| `AMD RDNA 5 Likely Scheduled for Second Half of 2027` | graficas, rumor | |
| `(PR) INNO3D Announces AGS-4UMGX-R1 4U GPU Server With NVIDIA MGX` | otro | |
| `NVIDIA Reportedly Ending the RTX 5090, Reserves GB202 Silicon for Workstation GPUs` | graficas, rumor | rtx-5090 |
| `AMD GPUs Get Price Hike in China with International Increases To Follow` | graficas, precio | |
| `NVIDIA Releases GeForce 617.42 WHQL Game Ready Drivers` | graficas, drivers | |
| `La GeForce RTX 5080 24 GB, el reemplazo de la RTX 5090, llegaría a principios de 2027` | graficas, rumor | rtx-5080, rtx-5090 / rtx-5080 24gb |
| `Kaum noch Lagerware: Die Nvidia GeForce RTX 5090 soll „EOL“ sein (Update)` | graficas, rumor | rtx-5090 |
| `Walmart has slashed $750 off this RTX 5060 gaming laptop, now 40% cheaper` | otro | |
| `RTX Spark: Nvidia lädt Interessenten am 16. Oktober zur „Launch Celebration“` | otro | |
| `Arc Raiders Jumps to Six-Month High Player Count With 2.0 Update` | otro (un juego, no una Arc) | |
| `Samsung HBM4E Passes Testing for NVIDIA's "Rubin Ultra" GPU` | otro | |
| `Lokale KI auf der RTX 3060: Kostenloses Tool verspricht schnellere Verarbeitung` | graficas, otro | rtx-3060 |
| `NVIDIA GeForce RTX 5070 Ti Founders Edition Review` | graficas, analisis | rtx-5070-ti |
| `La RTX 4070 Super cae a 549 euros en PcComponentes` | graficas, precio | rtx-4070-super |
| `Intel Arc B770 spotted in shipping manifests` | graficas, rumor | / arc b770 |

## Invariantes

- Un modelo del catálogo en el título es una gráfica de sobremesa: la noticia
  va de gráficas salvo que hable de un portátil.
- Sin modelo, va de gráficas si nombra gráficas (GPU, GeForce, Radeon, VRAM,
  RDNA, DLSS…) y nada de fuera (centros de datos, servidores, HBM, Rubin,
  portátiles, consolas, procesadores, estaciones de trabajo, RTX Spark).
- El tipo es el primero que encaja en el orden drivers, análisis, rumor
  (también el condicional: «llegaría», «habría», «soll»), precio, mercado,
  lanzamiento, anuncio.
- Con `tema: otro`, las listas van vacías.

## Fuera de dominio (defecto)

- Nombra gráficas y algo de fuera, sin modelo, con marcas de juego («FSR 4
  llega a las APU»): «no sé si va de gráficas de sobremesa».


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
