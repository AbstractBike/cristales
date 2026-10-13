# Semilla: memoria-noticia

De qué va una noticia de hardware para quien sigue la memoria RAM: si va de
memoria (DRAM, módulos, HBM, quien los hace y a cuánto), de almacenamiento
(SSD, NAND, discos), de otro hardware o de otra cosa; y, si va de memoria,
qué tipo de noticia es, de qué segmento, qué fabricantes, generaciones,
formatos y productos nombra, y lo que aún no está en las tiendas.

- Entrada: líneas `Título: …`, `Resumen: …` y `Fuente: …`, como en
  grafica-noticia y nvme-noticia y leídas con su `partes`; sin `Título:`,
  todo es el título.
- Salida: JSON `{"tema": "memoria"|"almacenamiento"|"hardware"|"otro",
  "tipo": "precio"|"mercado"|"fabrica"|"lanzamiento"|"analisis"|"estandar"|"otro",
  "segmento": "consumo"|"servidor"|"movil"|"hbm-ia"|"?", "fabricantes": [...],
  "generaciones": [...], "formatos": [...], "modelos": [...], "nuevos": [...]}`.
  `fabricantes`, claves de marca (`samsung`, `skhynix`, `micron`, `cxmt`,
  `nanya`, `corsair`, `gskill`…); `generaciones`, como se escriben
  plegadas (`ddr5`, `lpddr5x`, `gddr7`, `hbm4e`); `formatos` (`udimm`,
  `sodimm`, `rdimm`, `lrdimm`, `mrdimm`, `cudimm`, `csodimm`, `camm2`,
  `socamm`, `hudimm`, `cxl`); `modelos`, part numbers que lee
  memoria-modelo y líneas de kits («Vengeance», «Trident Z»); `nuevos`, lo
  que aún no se vende (DDR6, LPDDR6, HBM4E, HBM5, SOCAMM2, HUDIMM, zHBM,
  iHBM, NVHBM, XBM) y los part numbers que el catálogo no lee.

Antes era líquida. memorias.email la llama como herramienta con cada titular
de sus feeds; con el defecto, el LLM por la forja con la misma tarea.

Se decide por el título: el resumen solo suma fabricantes, generaciones,
formatos y modelos cuando el título ya va de memoria. La memoria de un
aparato que es el protagonista (va antes en el título: «Surface Laptop … con
128 GiB RAM», «Intel GPU D-Series Packs 480GB LPDDR5X», la VRAM de una
gráfica) es hardware, salvo que la noticia sea de su precio o su escasez.
Las empresas que solo hacen memoria (CXMT, Nanya, Winbond, Micron, SK hynix,
G.Skill…) bastan para que una noticia sin palabras de memoria vaya de
memoria; con SSD o NAND en el título, de almacenamiento.

Muestras: 763 titulares distintos del 2026-10-13 (en 488, de 188, it 40,
es 35, pt 12) de Tom's Hardware (y sus etiquetas memory, dram, ddr5 y ram),
TrendForce, TweakTown, StorageReview, ServeTheHome, Wccftech, KitGuru,
Semiconductor Engineering, ComputerBase, PCGH, Hardwareluxx, igor'sLAB,
HardZone, El Chapuzas Informático, Hardware Upgrade, Tom's Hardware Italia
y Pplware, más Blocks & Files y The Next Platform (solo para la semilla). Se
leen todos sin defecto: 142 de memoria, 47 de almacenamiento, 233 de otro
hardware y 341 de otra cosa.

## Ejemplos

| Título | tema, tipo, segmento | nuevos |
|---|---|---|
| `After jumping 2,200% over the last twelve months, DDR4 spot prices fall 5%…` | memoria, precio | |
| `Corsair's 32GB Vengeance kits are the cheapest DDR5 RAM on the market right now` | memoria, precio, consumo | |
| `Micron projects tightening RAM shortages through 2028 as it generates record profit` | memoria, mercado | |
| `Memory will consume 30% of hyperscaler data center spending this year…` | memoria, mercado, servidor | |
| `China's CXMT hits 12nm-class DRAM milestone` | memoria, fabrica | |
| `China's CXMT beats Western chipmakers to announcement of LPDDR6 mass production` | memoria, fabrica, movil | lpddr6 |
| `Samsung teases new HBM5 with twice the performance of HBM4E` | memoria, lanzamiento, hbm-ia | hbm5, hbm4e |
| `New HUDIMM memory specification debuts with goal of slashing DDR5 prices…` | memoria, estandar | hudimm |
| `G.Skill Trident Z5 NeoX RGB DDR5-6000 C30 2x16GB Review…` | memoria, analisis, consumo | |
| `RAMageddon: Wer hat in den letzten 12 Monaten noch RAM gekauft?` | memoria, mercado | |
| `Micron commits $500 million to GlobalWafers' Texas wafer plant…` | memoria, fabrica (Micron basta) | |
| `Microsoft Maia 300 Puts 288GB of HBM4 at 18TB/s…` | hardware (el chip es el protagonista) | |
| `192 GB Speicher: AMD stellt Gorgon Halo ins Schaufenster` | hardware | |
| `YMTC breaks into the top three NAND makers…` | almacenamiento | |
| `Microsoft 365 Family: OneDrive-Speicher sinkt von 6 auf 2 TB` | otro (la nube) | |
| `Spotifast lets you enjoy Spotify tracks while lowering RAM usage by 5x or more` | otro (la RAM de un programa) | |

## Invariantes

- Con `tema` distinto de `memoria`: `tipo` `otro`, `segmento` `?` y listas
  vacías.
- El tipo es el primero que encaja, en este orden: análisis, estándar,
  precio, fábrica, mercado, lanzamiento.
- `segmento` es `hbm-ia` si nombra HBM, SOCAMM o memoria para IA; si no,
  `servidor` o `consumo` cuando solo hay señales de uno; `movil` con LPDDR
  o teléfonos y nada más; si no, `?`.

## Fuera de dominio (defecto)

- «Speicher» solo, sin nada que diga si es memoria, un disco o un aparato:
  «no sé si va de memoria o de almacenamiento».


## Revisión del 2026-10-13

- El precio de un aparato no hace de su noticia una de memoria: solo el
  precio o la escasez junto a la memoria («precios de la RAM», «DDR5
  shortage»); «A pesar de su alto precio, la Surface Laptop … con 128 GB de
  RAM» es hardware. La memoria que adjetiva un aparato («DDR5 gaming PC»)
  tampoco; «ExpertCenter» y «NUC» son aparatos.
- «capacity» solo es de una fábrica con «production», «wafer», «memory» o
  «DRAM» delante («top RAM capacity in gaming rigs» no).
- Las líneas que son palabras corrientes («Impact», «Elite», «Shadow»…), solo
  con una marca de memoria en el titular o el resumen.
- «for only» es un precio.

---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
