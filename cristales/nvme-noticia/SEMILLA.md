# Semilla: nvme-noticia

De qué va una noticia de hardware para quien sigue los SSD: si va de SSD y
flash, del resto del almacenamiento (discos duros, NAS, cabinas) o de otra
cosa; qué tipo de noticia es, de qué segmento, fabricantes y modelos, y si
nombra algún SSD que aún no estaba en el catálogo.

- Entrada: líneas `Título: …`, `Resumen: …` y `Fuente: …`, como en
  grafica-noticia y leídas con su `partes`; sin `Título:`, todo es el título.
- Salida: JSON `{"tema": "ssd"|"almacenamiento"|"otro", "tipo":
  "firmware"|"analisis"|"rumor"|"precio"|"mercado"|"lanzamiento"|"anuncio"|"otro",
  "segmento": "consumo"|"enterprise"|"?", "fabricantes": [...], "modelos":
  [...], "nuevos": [...]}`. `modelos`, claves de nvme-modelo; `nuevos`, una
  marca con algo que parece un modelo y no está en el catálogo («kioxia ld4»).

Antes era líquida. nvme.email la llama como herramienta con cada titular de
sus feeds; con el defecto, el LLM por la forja con la misma tarea.

Se decide por el título: el resumen solo suma modelos y marcas. Muestras: RSS
de TechPowerUp, Tom's Hardware, StorageReview, Blocks & Files, ServeTheHome,
TweakTown, ComputerBase, PCGH, HardZone y El Chapuzas Informático,
2026-10-12: de 413 titulares, 17 de SSD y 22 de almacenamiento; uno, defecto.

## Ejemplos

| Título | tema, tipo, segmento | nuevos |
|---|---|---|
| `(PR) Kioxia Announces E1.L QLC-Based SSD Designed for Hyperscale Data Centers` | ssd, anuncio, enterprise | |
| `Kioxia LD4 E1.L QLC NVMe SSD Announced` | ssd, anuncio | kioxia ld4 |
| `KIOXIA CM9-DLC Brings Direct Liquid Cooling to Dual-Port E3.S SSDs up to 30.72TB` | ssd, lanzamiento, enterprise | kioxia cm9 |
| `Grab Biwin Black Opal NV7400 M.2 NVMe SSD in Our Exclusive Prime Day Deal: Up to 28% Off!` | ssd, precio, consumo | biwin nv7400 |
| `Sandisk NAS 800 1.92TB SSD Review: Endurance at a premium` | ssd, analisis | |
| `US Listing? Me too says Kioxia` | ssd, mercado (Kioxia solo hace flash) | |
| `Seagate and Toshiba Reportedly Pursue TDK HDD Head Business as Nearline Demand Accelerates` | almacenamiento, rumor | |
| `Distant third HDD maker Toshiba spending $380 million to catch up` | almacenamiento, mercado | |
| `¿Tiene sentido seguir comprando discos duros HDD en 2026?` | almacenamiento, otro | |
| `La CPU, RAM y SSD ya supone el 68% del coste de un portátil de 900 euros` | ssd, precio | |
| `Microsoft 365 Cuts Family OneDrive Storage from 6 TB to 2 TB` | otro (la nube) | |
| `Samsung HBM4E Passes Testing for NVIDIA's "Rubin Ultra" GPU` | otro (memoria) | |
| `Memory gold rush bonanza makes billions for Micron` | otro | |

## Invariantes

- `tema` es `ssd` si nombra un modelo del catálogo, una palabra de SSD o
  flash (SSD, NVMe, NAND, QLC, M.2, U.2, E1.S…) o una empresa que solo hace
  flash (Kioxia, Solidigm, SanDisk, Phison…); `almacenamiento` si va de
  discos duros, NAS o «storage»; la nube (OneDrive, iCloud…) es `otro`.
- Con `tema` `otro`, tipo `otro`, segmento `?` y listas vacías.

## Fuera de dominio (defecto)

- «Storage» junto a memoria (HBM, DRAM, «memory»), sin nada de SSD: «no sé si
  va de almacenamiento».


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
