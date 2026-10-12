# Semilla: nvme-modelo

Los SSD que nombra un texto, con sus datos: el título de un anuncio, lo que
alguien escribe que busca («una 990 Pro o una SN850X», «PM9A3 o Micron
7450»), un titular.

- Entrada: texto libre, en castellano, alemán, inglés, italiano o portugués.
- Salida: JSON `{"modelos": [...], "desconocidos": [...], "capacidades":
  [...], "interfaz": ..., "formato": ..., "marcas": [...]}`. Cada modelo, con
  su clave (`samsung-990-pro`), su nombre, su marca, su segmento (`consumo`,
  `enterprise`), su interfaz (`pcie3`, `pcie4`, `pcie5`, `sata`, `sas`),
  su formato (el que dice el texto si es de los suyos: `m2-2280`, `m2-22110`,
  `u2`, `u3`, `e1s`…), DRAM o HMB, la NAND (`tlc`, `qlc`, `mlc`,
  `xpoint`), la controladora, si tiene PLP, la capacidad que dice el texto
  (en GB nominales: 2048 GB es 2 TB; 1,92 TB sigue siendo 1920) y la TBW de
  esa capacidad, su año y su lectura secuencial.

Antes era líquida: «¿qué SSD es este?» al LLM en cada anuncio. La cristalizó
el agente que montó nvme.email, con anuncios reales del 2026-10-12 (Wallapop
y Kleinanzeigen, Festplatten & Laufwerke) por la forja en su variante MCP: el
cristal está en la vitrina, las apps lo llaman como herramienta y lo que no
sabe les vuelve como defecto.

El catálogo (`catalogo.ml`) tiene los NVMe de consumo de la 960 EVO (2016) a
la 9100 Pro y la T710 (2025), los enterprise que salen de los servidores
(PM963, PM983, PM9A3, PM1733, Micron 7300/7400/7450/7500/9300/9400 PRO y
MAX, Intel P4500/P4510/P4610, Solidigm P5510/P5520/P5620, Optane, Ultrastar
SN640/SN840, Kioxia CD6/CM6/CD8, Kingston DC1500M…) y los SATA y SAS más
vendidos, para saber que no son NVMe. Las TBW son las de las fichas, de
memoria del modelo que lo escribió; las de los enterprise, de sus DWPD y sus
años de garantía. La plana del texto y las listas de palabras son las de
grafica-modelo (`Grafica_modelo.Texto`), salvo el «+», que aquí no es «Plus».

## Ejemplos

| Entrada | Modelos (clave/capacidad en GB) |
|---|---|
| `SSD Kingston NV3 2TB PCIe 4.0 NVMe M.2` | kingston-nv3/2000 |
| `SSD WD Black SN850P 1TB NVMe para PS5` | wd-black-sn850x/1000 (la SN850P es la SN850X con licencia de PS5) |
| `WD black sn 850 x 2tb nvme` | wd-black-sn850x/2000 |
| `Gaming  ssd m.2  nvme Samsung pro 990 2TB` | samsung-990-pro/2000 |
| `2 TB Kingston KC3000 2048GB M.2 NVMe Interne SSD (SKC3000D/2048G)` | kingston-kc3000/2000 |
| `Crucial P3 Plus 4TB NVMe M.2 SSD (CT4000P3PSSD8) – PCIe 4.0` | crucial-p3-plus/4000 (la «P3» de la referencia no es otra) |
| `2TB WD_Black SN850X NVMe M.2 SSD 7300 MB/s & 6600 MB/s inkl OVP` | wd-black-sn850x/2000 (7300 MB/s no es una Micron 7300) |
| `Samsung PM9A3 7.68TB U.2 NVMe SSD PCIe 4.0 x4 MZQL27T6HBLA-00A07` | samsung-pm9a3/7680 |
| `Samsung PM983 Enterprise SSD 4TB M.2 NVMe inkl. PCIe-Adapter` | samsung-pm983/3840 (los de 3,84 TB se anuncian como de 4) |
| `2x Micron/HP 7450 MAX U.3 6,4TB SSD, neuwertig` | micron-7450-max/6400 |
| `Micron 7450 Enterprise NVMe SSD 3.84 TB` | micron-7450-pro/3840 (PRO o MAX, por la capacidad) |
| `Intel Optane SSD DC D4800X 750GB U.2 NVMe – Neu im Blister` | intel-optane-p4800x/750 |
| `Samsung PM1643 7,68 TB SAS 12G Enterprise SSD – 87 %` | samsung-pm1643/7680 (SAS) |
| `Disco duro SSD Samsung 870 EVO 4TB sólo 71 horas` | samsung-870-evo/4000 (SATA) |
| `SSD 1TB NVMe M.2 Gen3x4` | ninguno (genérico: capacidad 1000, pcie3, m2) |
| `PC Gaming Ryzen 7 + RTX 3060 Ti + 1TB NVMe` | ninguno |

Y lo que no está en el catálogo, aparte (una marca y algo con letras y cifras
detrás): `FIKWOT FX991 500GB NVMe` da «fikwot fx991»; `Acer Predator GM7
4TB`, «acer gm7»; `Samsung PM9A Enterprise SSD 1,92 TB U2`, «samsung pm9a».

## Invariantes

- Cada modelo del catálogo se lee por su nombre, y solo como él; las claves
  no se repiten y las capacidades van en orden.
- Un alias empieza donde empieza una palabra; un alias de un solo número
  («7450», «980») necesita su marca en el texto y no vale detrás de «bis»,
  «hasta», «up to» ni delante de MB/s, GB, W o rpm.
- Entre los que comparten alias (Micron 7450 PRO y MAX), el que tiene la
  capacidad del texto; sin capacidad, el primero del catálogo (el PRO).
- La capacidad es la del texto; si es una de las del modelo (a un 5 %), esa,
  con su TBW. No cuentan la memoria («16GB RAM»), la resistencia («600TBW»)
  ni lo de menos de 100 GB.
- En la medida del 2026-10-12, 223 de 232 anuncios de Kleinanzeigen
  (Festplatten & Laufwerke) y 173 de 178 de Wallapop se leen sin LLM (con
  nvme-anuncio, que lo usa); el resto son modelos que el catálogo no tiene.

## Fuera de dominio (defecto)

- Texto sin ningún modelo del catálogo ni nada que lo parezca: «no nombra
  ningún modelo de SSD».
- Solo modelos que no están en el catálogo: «modelo desconocido: …». Es la
  semilla de la versión siguiente (WD Blue SN5000, Acer GM7, Kioxia BG4…).


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
