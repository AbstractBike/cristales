# Semilla: memoria-modelo

La memoria que nombra un texto: los part numbers que trae (con lo que dicen),
lo que el texto dice de la memoria (cuántos módulos, de cuánto, qué
generación, formato y velocidad) y las placas y servidores que nombra, con la
memoria que admiten. Es lo que alguien escribe al darse de alta en
memorias.email («busco 8 RDIMM de 64 GB DDR4-3200 2Rx4 para mi ROME2D16-2T»,
«tengo un CT32G4DFD832A») y lo que lee memoria-anuncio en cada anuncio.

- Entrada: texto libre, en castellano, alemán, inglés, italiano o portugués.
- Salida: JSON `{"modulos": [...], "especificacion": {...} | null,
  "placas": [...], "desconocidos": [...], "marcas": [...]}`.
  - Cada módulo: `pn` (como se escribe, con su sufijo: `M393A8G40AB2-CWE`),
    `fabricante`, `oem` (`hpe`, `dell`, `lenovo`, `ibm`… si es su etiqueta),
    `equivalentes` (el módulo que lleva la etiqueta, si se sabe), `linea`,
    `generacion` (`sdr`, `ddr`, `ddr2`…`ddr5`), `formato` (`udimm`, `sodimm`,
    `rdimm`, `lrdimm`, `3ds-rdimm`, `ecc-udimm`, `ecc-sodimm`, `cudimm`,
    `csodimm`, `camm2`, `mrdimm`, `fbdimm`), `ecc`, `registrada`,
    `capacidad` (GB por módulo; 0.5 para 512 MB), `modulos` (1, o los del
    kit), `velocidad` (MT/s), `cas`, `rangos`, `anchura` (4, 8, 16) y
    `voltaje`. Lo que el part number no dice, `null`.
  - `especificacion`: lo mismo dicho con palabras (sin los part numbers):
    `generacion`, `formato`, `ecc`, `registrada`, `capacidad`, `modulos`,
    `total` (GB), `velocidad`, `cas`, `rangos`, `anchura`, `voltaje`; `null`
    si el texto no dice nada de la memoria.
  - Cada placa: `clave`, `nombre`, `tipo` (`placa`, `servidor` o
    `plataforma`: un zócalo o un chipset), `generaciones`, `formatos` que
    admite, `ecc` (`si`, `no`, `opcional`), `ranuras`, `canales`,
    `velocidad` (máxima, con un módulo por canal) y `maximo` (GB).

Antes era líquida: «¿qué memoria es esta?» al LLM. La cristalizó el agente que
montó memorias.email, sobre los anuncios y titulares reales del 2026-10-13
(Wallapop ES/IT/PT y Kleinanzeigen Speicher; 22 feeds de hardware), para que
la app la llame como herramienta en la vitrina de la forja.

Los part numbers no se buscan en una lista: se leen con las reglas de cada
fabricante (`catalogo.ml`). Samsung (`M393A8G40AB2-CWE`: la familia da el
formato, la letra la generación, la profundidad la capacidad, la
organización la anchura y el sufijo la velocidad), SK hynix
(`HMAA8GR7AJR4N-XN`, y los rangos salen de la densidad del chip), Micron
(`MTA36ASF8G72PZ-3G2E1`, `MT36KSF2G72PZ`, `MTC40F2046S1RC48BA1`), Crucial
(`CT32G4DFD832A`, `CT2K16G4SFRA32A`, `CT32G56C46S5`, Ballistix
`BL2K32G32C16U4B`), Kingston (`KSM32RD4/64HAR`, `KVR32N22D8/32`,
`KF432C16BBK2/32`, `KCP432SD8/32`, `KTD-PE432/64G`), Corsair
(`CMK32GX4M2E3200C16`), G.Skill (`F4-3200C16D-32GVK`,
`F5-6000J3038F16GX2-TZ5RK`), Synology y OWC. Lo que una regla no cuenta (los
rangos de Samsung dependen del chip) va en una tabla corta de los que se
saben; las etiquetas de HPE, Lenovo e IBM, en otra, con el módulo que llevan
cuando se sabe (`P03053-0A1` es un `HMAA8GR7AJR4N-XN`). Las reglas y las
tablas son de memoria del modelo, contrastadas con lo que dicen los
anuncios.

Las placas, pocas y sabidas: las de la flota (ASRock Rack ROME2D16-2T y
B565D4-V1L), las de EPYC que salen en los portales (ROMED8-2T, H12SSL,
H12DSi, MZ32-AR0, S8030), los Dell PowerEdge R640/R740/R630/R730 y los HPE
DL360/DL380 Gen10. Lo demás, por su zócalo o su chipset (AM4, AM5, LGA1700,
LGA1851, LGA1200, LGA1151, X99, SP3, SP5, LGA3647, LGA4189, LGA4677,
TRX40, WRX80, WRX90).

## Ejemplos

| Entrada | Lectura |
|---|---|
| `M393A8G40AB2-CWE` | samsung, ddr4 rdimm, 64 GB, 3200, 2Rx4 (lo que lleva a2) |
| `HMAA8GR7CJR4N-XN`, `MTA36ASF8G72PZ-3G2E1`, `KSM32RD4/64HAR`, `CT64G4RFD432A`, `M393A8G40BB4-CWE` | lo mismo: sus equivalentes exactos |
| `HPE P03053-0A1` | hpe, ddr4 rdimm 64 GB 3200 2Rx4, equivalente `HMAA8GR7AJR4N-XN` |
| `CT32G4DFD832A.M16FF` | crucial, ddr4 udimm 32 GB 3200 2Rx8 (el que le falta a a1) |
| `MTA8ATF2G64AZ-3G2F1`, `CT16G4DFRA32A.C8FE` | ddr4 udimm 16 GB 3200 1Rx8 (los de a1) |
| `M386A8K40BM1-CRC` | ddr4 lrdimm 64 GB 2400 4Rx4 |
| `HMAA8GR7A2R4N-VN` | ddr4 3ds-rdimm 64 GB 2666 |
| `CMK32GX4M2E3200C16` | corsair, ddr4 udimm, 2 × 16 GB, 3200 CL16 |
| `Busco 8 módulos RDIMM de 64GB DDR4-3200 2Rx4 ECC (M393A8G40AB2-CWE) para mi ASRockRack ROME2D16-2T` | el módulo, la especificación (8 × 64 = 512 GB, rdimm, 3200, 2Rx4) y la placa (16 ranuras, 16 canales, rdimm/lrdimm/3ds, 3200, 4 TB) |
| `Corsair Vengeance LPX 64GB (2x32GB) DDR4-3200 CL16` | 2 × 32 GB, no un módulo de 64 |
| `Corsair Vengeance RGB Pro 64GB DDR4 3600MHz RAM Kit` | un kit de 64 GB sin desglose (`capacidad` y `modulos` nulos) |
| `Kingston FURY Beast DDR4 16GB 3600MHz (16x4) 64gb` | 4 × 16 GB |
| `64GB Server-RAM "Mushkin Proline" DDR4 (PC4-17000) ECC/REG 2Rx4` | ddr4 rdimm 64 GB, 2133 (de PC4-17000), 2Rx4 |
| `Módulo RAM Samsung 512MB PC2-3200U` | ddr2 udimm, 0.5 GB, 400 (PC2-3200 es un ancho de banda) |
| `SK Hynix 8GB 1Rx8 PC4-3200AA-SA2-11` | ddr4 sodimm (la «S» de la etiqueta), 3200, 1Rx8; el «11» no es una cuenta |
| `16GB-DDR3L / 1600 MHz {2 x 8 GB}` | ddr3, 2 × 8 GB, 1600, 1,35 V |
| `Dell PowerEdge R740xd` | servidor, 24 ranuras, 12 canales, rdimm/lrdimm/3ds, 2933, 3 TB |

## Invariantes

- Cada etiqueta de OEM se lee como ella misma y cada alias de placa como su
  placa; las claves de las placas no se repiten.
- La capacidad del texto es de un módulo salvo que el texto diga cuántos o
  que pase de lo que puede ser un módulo de esa generación y ese formato
  (un DDR4 sin registro no pasa de 32 GB; un RDIMM DDR4, de 64; un LRDIMM o
  un 3DS, de 256): entonces es el total, repartido si se puede.
- La velocidad es la primera que dice el texto: «3200MHz», «DDR4-3200»,
  «3200AA», «2933Y», «PC4-25600» (ancho de banda, ÷ 8), «PC3-12800R». No
  cuentan los procesadores («Ryzen 5 3600»), los precios ni lo que va detrás
  de «PC4» si no es una velocidad de DDR4.
- El formato: el que se dice; si no, el de la etiqueta JEDEC (la letra tras
  la velocidad o la primera del código de placa: R, L, U, S, E, F); si no,
  el del part number; si no, lo que se deduce (registrada o con chips x4 es
  RDIMM; para portátil, SO-DIMM; un kit de juego o un sobremesa, DIMM). Con
  ECC dicho, el de ECC. Si el texto nombra varios formatos (una tienda), ninguno.
- El ECC del texto: ni el «on-die ECC» de DDR5 ni las palabras clave de una
  tienda que dicen «ECC, non-ECC».
- En la medida del 2026-10-13, 1.244 de los 1.266 títulos que memoria-anuncio
  lee como memoria suelta se leen sin defecto; los 22 restantes no dicen
  nada de la memoria («Memoria RAM Servidor HP Samsung», «Konvolut RAM»).

## Fuera de dominio (defecto)

- Un texto sin part numbers, sin placas y sin nada de la memoria: «no nombra
  ningún módulo de memoria».
- Solo un part number que ninguna regla lee: «part number desconocido: …».
  Es la semilla de la versión siguiente.


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
