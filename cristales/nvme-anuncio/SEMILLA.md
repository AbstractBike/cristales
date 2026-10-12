# Semilla: nvme-anuncio

Qué se vende en un anuncio de segunda mano de discos y componentes: un SSD
NVMe suelto (y cuál, de cuánto y en qué estado de salud), o un SATA, un disco
duro, un SSD externo, una caja sin disco, un adaptador, un PC, un portátil,
una consola, un componente, un lote, alguien que busca.

- Entrada: el anuncio en líneas `Título: …`, `Categoría: …` (la del portal,
  si la hay) y `Descripción: …` (hasta el final), como en grafica-anuncio y
  leída con su `partes`. Sin `Título:`, todo el texto es el título.
- Salida: JSON con `tipo` (`ssd`, `sata`, `hdd`, `externo`, `caja`,
  `adaptador`, `pc`, `portatil`, `consola`, `componente`, `lote`, `busca`,
  `otro`), el disco (`modelo`, `nombre` y `tbw` del catálogo de nvme-modelo,
  o `null` si es genérico; `marca`, `segmento`, `interfaz`, `formato`,
  `dram`, `nand`, `plp` y `capacidad`, del catálogo o de lo que dice el
  texto), su `estado` (`nueva`, `usada`, `averiada`), su salud (`horas`,
  `escritos` en TB, `vida` en %, `smart`) y lo que dice de `garantia`,
  `factura`, `caja` (la original, OVP), `disipador` y `cambio` (`si`, `no`,
  `?`). Fuera de `ssd` y `sata`, los campos del disco van a `null`.

Antes era líquida: el anuncio al LLM. nvme.email la llama como herramienta
(la forja en su variante MCP) en cada anuncio que trae un portal; con el
defecto decide la app y, si no le basta, el LLM por la forja con la misma
tarea.

Lo que es se decide por el título y la categoría mirando qué va antes: «PC
Gaming Ryzen 7 + RTX 3060 Ti + 1TB NVMe» es un PC; «Kingston KC3000 1TB NVMe
SSD + Delock USB-C Gehäuse», un SSD (con caja); «Carcasa M.2 NVMe USB C», una
caja. La descripción da el estado, la salud y el modelo si el título no lo
dice. El estado es el de grafica-anuncio (`Grafica_anuncio.estado`) más lo
que es avería en un disco («wird nicht erkannt», «solo lectura», «bad
sectors»). Muestras: Wallapop (API de búsqueda, con su taxonomía) y
Kleinanzeigen (Festplatten & Laufwerke), 2026-10-12.

## Ejemplos

| Título | Categoría | Salida (tipo, modelo, capacidad) |
|---|---|---|
| `SSD Kingston NV3 2TB PCIe 4.0 NVMe M.2` | Computer components & parts | ssd, kingston-nv3, 2000 |
| `SSD Samsung 1TB NVMe Gen4 OEM - De HP ProDesk 400` | Computer components & parts | ssd, genérico samsung, 1000 |
| `Lexar NM790 SSD 2TB PCIe Gen4x4 NVMe` | External hard drives | ssd, lexar-nm790, 2000 (la categoría no manda) |
| `Samsung PM9A3 1.92TB 2.5 Zoll SSD PCIe Gen4` | Festplatten & Laufwerke | ssd, samsung-pm9a3, 1920 (enterprise, PLP) |
| `Dell EMC 960GB U.2 NVMe Enterprise SSD + PCIe x4 Adapter` | Festplatten & Laufwerke | ssd, genérico dell, 960, u2, enterprise |
| `Western Digital Red SN700 NVMe SSD 1TB -  2x verfügbar Gebraucht` | | ssd (dos sueltas, no un lote) |
| `Disco duro SSD Samsung 870 EVO 4TB sólo 71 horas` | | sata, samsung-870-evo, horas 71 |
| `Kingston 512 GB M.2 2280 SSD SATAIII 6 Gb/s` | | sata |
| `(NUEVO) SSD 2tb PS5` | Accessories & spare parts for consoles | sata (un SSD sin rastro de NVMe) |
| `Seagate IronWolf 6TB NAS Festplatte 3.5"` | | hdd |
| `CORSAIR EX400U 2TB Externe USB 4 SSD` | | externo |
| `ACASIS 80Gbps M.2 NVMe Enclosure` | | caja |
| `Placa ASUS Hyper M.2 x16 Gen 4` | | adaptador |
| `Consola Xbox Series X 1TB SSD` | Consoles | consola |
| `ASUS ROG Zephyrus G14 Ryzen 7 32GB 2TB SSD` | Gaming laptops | portatil |
| `Supermicro Rackserver mit 4 × Samsung PM983 3,84 TB NVMe SSD` | | pc |
| `2x Samsung PM9A3 SSD 2,5“ 1,92 TB - PCIe Gen4  - Neu u. Unbenutzt` | | lote |
| `NVMe 500gb + kit i5 10400` | | lote (un combo) |
| `Ankauf SSD / M.2 / NVMe / Speicher - Preisliste Oktober 2026` | | busca |

Y la salud por lo que dicen título y descripción: «100% Zustand (kaum
genutzt)» da `vida: 100` (manda la palabra más cercana); «0% Verschleiß»,
`vida: 100`; «Betriebsstunden: 1.234, 12 TB geschrieben, SMART-Werte im Bild
(CrystalDiskInfo). Privatverkauf, keine Garantie.» da `horas: 1234`,
`escritos: 12`, `smart: si`, `garantia: no`; «Neu & OVP», `estado: nueva` y
`caja: si`; «wie neu», usada.

## Invariantes

- `tipo` es uno de los trece; si es `ssd` o `sata` y hay `modelo`, es una
  clave de nvme-modelo con la interfaz que le toca (NVMe para `ssd`).
- PC, portátil, consola, adaptador, caja y componente lo son si su palabra va
  antes que la del disco (y no detrás de «para», «für», «for»), o si la
  categoría del portal lo dice y el título no empieza por el disco.
- Un lote es «lote», «pack», «Paket», «Konvolut» o «2x», «3×», «(2 Stück)»,
  salvo «verfügbar», «disponibles» (unidades sueltas).
- Un SSD sin señal de NVMe (NVMe, PCIe, Gen, U.2, M.2) es SATA.
- Las negaciones (sin, nunca, ohne, kein, keine, never…) en las dos palabras
  de antes dan la vuelta a garantía, factura, caja y avería.

## Fuera de dominio (defecto)

- Un disco de una marca con un modelo que el catálogo no tiene: «modelo
  desconocido: wd sn5000».
- Varios modelos en el título: «varios modelos: wd-black-sn850x,
  samsung-990-pro».


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
