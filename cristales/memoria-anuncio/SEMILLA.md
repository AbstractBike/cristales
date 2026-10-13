# Semilla: memoria-anuncio

Qué se vende en un anuncio de segunda mano de memoria RAM: memoria suelta (un
módulo, un kit de iguales o un lote, con cuántos y de cuánto) o un PC, un
portátil, un servidor entero, una placa o una CPU que la lleva, otra pieza,
alguien que busca. Y, de la memoria, todo lo que hace falta para saber si
vale para una placa: generación, formato, ECC, registro, capacidad por
módulo, velocidad, CAS, rangos, anchura, voltaje, fabricante y part number;
y lo que dice el anuncio de su estado, su procedencia, si está probada, la
garantía, la factura, el envío, si se vende por separado y a cuánto sale
cada módulo.

- Entrada: el anuncio en líneas `Título: …`, `Categoría: …` (la del portal,
  si la hay), `Precio: …` (el del portal: `185`, `9.95`, `1.250 €`),
  `Portal: …`, `País: …` y `Descripción: …` (hasta el final), como en
  nvme-anuncio y grafica-anuncio. Las que no sean `Descripción` van antes de
  ella. `Portal` y `País` se aceptan y no cambian la lectura. Sin `Título:`,
  todo el texto es el título. Las etiquetas de dato ajeno (`<posting>`) y
  las palabras clave de una tienda (`Tags: …`) no cuentan.
- Salida: JSON, siempre con las mismas claves y en este orden:
  - `tipo`: `modulo`, `kit` (de 2 a 4 iguales sin ECC ni registro),
    `lote` (los de servidor, los de 5 o más, los «lote», «Konvolut»,
    «pack» y los mezclados), `pc`, `portatil`, `servidor`, `placa` (con lo
    que lleve: CPU, RAM), `cpu` (sola o con RAM), `componente` (otra pieza:
    gráfica, disco, fuente, riser), `busca` u `otro`.
  - La memoria, `null` fuera de `modulo`, `kit` y `lote`: `modulos` (1 en un
    módulo; los que se venden juntos), `disponibles` (unidades sueltas: «4
    Stück verfügbar», «32 units in stock»), `iguales`, `capacidad` (GB por
    módulo), `total` (GB), `generacion`, `formato` (los de memoria-modelo),
    `ecc`, `registrada`, `velocidad` (MT/s), `cas`, `rangos`, `anchura`,
    `voltaje`, `fabricante`, `pn`, `oem` y `equivalentes` (lista; vacía
    fuera de la memoria).
  - Lo que dice el anuncio (`si`, `no` o `?`; fuera de la memoria, `?`):
    `disipador`, `rgb`, `procedencia` (`servidor`, `pc`, `portatil` o `?`:
    de dónde se desmontó), `probado` (`memtest`, `si`, `no` o `?`),
    `divisible`; y siempre `estado` (`nueva`, `usada`, `averiada`),
    `garantia`, `factura`, `envio` y `cambio`.
  - `precio` (el de la entrada, o `null`) y `precioModulo`: el que dice el
    anuncio por unidad («55€/ud», «600 € VB pro Riegel», «Festpreis / Stk.
    400», «5,50€ pro Stück», «Precio unitario: 90 €»); si dice que el precio
    es por módulo («price for 1 memory module»), el precio; si no, el precio
    entre los módulos.

Antes era líquida: el anuncio al LLM. memorias.email la llama como
herramienta (la forja en su variante MCP) en cada anuncio que trae un portal;
con el defecto decide la app y, si no le basta, el LLM por la forja con la
misma tarea.

Lo que es se decide por el título y la categoría, mirando qué va antes: «HP
Z440 Workstation 128GB RAM» es un PC; «Server RAM Kingston 16GB», memoria
(«Server», «Laptop», «für PC» delante de la RAM son adjetivos); «Ryzen 7
5800X + 32 GB DDR4», una CPU con RAM; «Combo Ryzen 9 5900X + B550M + 64GB»,
una placa; «2x 32GB SK Hynix ECC (64GB) +Xeon gratis», memoria (lo que va de
regalo no cuenta). La memoria la lee memoria-modelo en el título; la
descripción completa lo que el título calla (la generación, el formato, la
velocidad, el part number si da uno solo, y cuántos módulos si el título no
dice capacidad). En un cambio («Tausch 2x 64GB … gegen 8x 16GB»), lo que se
ofrece es lo de antes de «gegen», «vs», «por». El estado es el de
grafica-anuncio más las averías de la memoria («Fehler im Memtest»,
«pantallazos azules»), sin las advertencias de compatibilidad («NON funziona
sui normali PC»).

Muestras: 1.664 anuncios del 2026-10-13, de Wallapop (API de búsqueda en
Componentes y piezas de ordenador: 816 de España, 153 de Italia, 46 de
Portugal, 2 de Andorra) y Kleinanzeigen (Speicher, c225, y sin categoría:
647). Sin LLM se leen 1.002 de los 1.017 de Wallapop y 635 de los 647 de
Kleinanzeigen.

## Ejemplos

| Título | Lectura (tipo, módulos × GB, generación, formato, velocidad) |
|---|---|
| `Crucial 32GB DDR4 UDIMM CT32G4DFD832A` | modulo, 1 × 32, ddr4, udimm, 3200 (lo que busca a1) |
| `4× Samsung 64GB DDR4-3200 ECC REG RDIMM RAM M393A8G40AB2-CWECO` | lote, 4 × 64, ddr4, rdimm, 3200 (lo que busca a2: un lote no es un descarte) |
| `HPE P03053-0A1 64GB DDR4 3200 Hynix HMAA8GR7AJR4N-XN REG ECC RAM` + «price for 1 memory module, 32 units in stock» | modulo, 1 × 64, rdimm, 3200, oem hpe, disponibles 32, precioModulo 800 |
| `50x SK Hynix DDR4 3200AA 64GB 2Rx4 Módulos RAM` | lote, 50 × 64, rdimm (chips x4: registrada), 3200 |
| `Samsung DDR4 M393A8G40MB2-CVF 64GB PC4-2933Y` | modulo, 1 × 64, rdimm, 2933 (para a2, más lento) |
| `Samsung 64GB (2x32GB) DDR4 2400MHz PC4-2400T-LA0-11-MC0` | lote, 2 × 32, lrdimm (la «L» de la etiqueta), 2400 |
| `Corsair Vengeance LPX 64GB (2x32GB) DDR4-3200 CL16` | kit, 2 × 32, udimm, 3200, CL16, disipador |
| `Kingston FURY Beast DDR4 16GB 3600MHz (16x4) 64gb` | kit, 4 × 16 |
| `SK Hynix 8GB 1Rx8 PC4-3200AA-SA2-11 RAM Arbeitsspeicher` | modulo, 1 × 8, sodimm, 3200 (el «11» no son once módulos) |
| `Hynix 16GB DDR4 2400T RDIMM Server RAM bis zu 4 Stück` | modulo, disponibles 4 |
| `Lote 11 Memorias RAM DDR2 DDR3 DDR3L DDR4` | lote, iguales false |
| `HP Z420 128GB RAM Xeon 1650 512GB Quadro K4200 WLAN Workstation` | pc |
| `IBM 96 Core, 512 GB RAM 19" HP Serverschrank` | servidor |
| `Kit Servidor Huananzhi X99 + Xeon E5-2670 V3` | placa |
| `AMD Ryzen 7 5800X + 32 GB Corsair DDR4 3200 MHz RAM` | cpu |
| `M654T Dell PowerEdge RAM Memory Riser Board` | componente |
| `「Precio Más Alto」DDR4 Interesado RDIMM ECC RAM` | busca (los compradores de Wallapop) |

## Invariantes

- `tipo` es uno de los once; fuera de `modulo`, `kit` y `lote`, los campos
  de la memoria van a `null` (y `equivalentes` a `[]`).
- Con `capacidad`, `modulos` y `total`, `capacidad × modulos = total`.
- «2x32GB» son dos módulos de 32, no uno de 64; «64GB Kit», un kit que hay
  que desglosar; «4 x 16 GB», «16GB (x2)», «(16 cada una)», «Lote 5x 8GB»,
  «8 Módulos … 16GB (128GB Total)», cuentas. No son cuentas el «4» de «DDR
  4», el «11» de «PC4-3200AA-SA2-11» ni el «55» de «55€/ud».
- Un anuncio que nombra varias generaciones o dice «verschiedene», «varios»,
  «mix» es un lote mezclado (`iguales: false`).
- Las negaciones (sin, nunca, ohne, kein, keine, never, non…) en las dos
  palabras de antes dan la vuelta a garantía, factura, envío, disipador,
  probado y avería.

## Fuera de dominio (defecto)

- El part number contra el texto (otra capacidad, o un formato de otra familia):
  «el part number M393B1K70CH0-CH9 es de 8 GB y el anuncio dice 32 GB».
- Memoria sin capacidad en el título ni en la descripción: «no dice la
  capacidad».
- Una capacidad que puede ser de un módulo o de un kit, sin cuántos («Ddr4
  64gb 3200mhz», «Corsair Vengeance RGB Pro 64GB DDR4 Kit»): «no se sabe si
  es un módulo o un kit: 64 GB».
- Varias capacidades sueltas en el título (una tienda): «varias capacidades:
  16, 32, 64 GB».


## Revisión del 2026-10-13

Lo que encontró la revisión de memorias.email sobre la semilla, y cómo se lee
ahora (los casos, en la red):

- **Un kit no es un módulo del total.** «Crucial 32gb DDR4 RAM» con «2x16GB»
  en la descripción (#300, #396) es un kit de 2 × 16; «4 Módulos … 32GB» con
  «4 módulos de 8 GB cada uno» (#861), 4 × 8. El part number de un kit
  (CMK32GX4M2E3200C16, KF432C16BBK2/32, CT2K16G4DFRA32A) dice la cuenta:
  «32GB» son los dos. Lo que el título ya desglosa («64GB (4x 16GB)») no se
  relee con la descripción.
- **El part number contra el texto, defecto.** Si su capacidad no es la que
  dice el anuncio (M393B1K70CH0, de 8 GB, en «32GB Samsung … DDR3») o su
  formato es de otra familia que el dicho (M393 con la etiqueta «LA0»), no se
  afirma ninguno: «el part number … es de 8 GB y el anuncio dice 32 GB». Un
  part number de LRDIMM o 3DS gana a la palabra «RDIMM» (#468); la letra de
  la etiqueta JEDEC, a la palabra («PC4-2400T-RD1» y «Formato: ECC UDIMM»:
  RDIMM, #705).
- **El formato manda sobre el ECC y el registro**: un RDIMM es registrado y
  con ECC aunque diga «Unbuffered»; el ECC deducido de «Bauform: DIMM» no
  gana al del part number (#464). Un lote mezclado no tiene capacidad por
  módulo.
- **Precios.** Por unidad también «8 Stück X 399€» (#185), «1 St. = 1550€»
  (#167), «gilt für jeweils» (#149), «per ogni singolo banco» (#1470), «cada
  una por 400 €» (#809, antes que el «800 €» de los dos); «Stock: 2 uds» no
  es un precio (#900). La capacidad («16 GB pro Riegel», «64GB por módulo») y
  los LEDs («10 RGB-LEDs pro Modul») no hacen del precio uno por módulo
  (#460, #1074, #323). El precio de todos («2.000 € für alle vier zusammen»)
  da el de cada uno comprando el lote; y si el anuncio es un pack más barato
  por módulo que el precio de uno («65€ 1 módulo, 115€ 2 módulos»), el del
  pack. «N Stock» con «Capacidad total» de los N y sin precio de cada uno
  (#1362): un lote de N al precio del anuncio.
  - Fusión: el anuncio de Langgöns («600 € VB pro Riegel / 2.000 € für alle
    vier zusammen»), que la red daba a 600 por módulo, ahora da 500: lo que
    sale cada uno comprando los cuatro, que es lo que se compra.
- **Garantía negada**: «Unter Ausschluss jeglicher Gewährleistung», «keine
  Garantie» son `no` aunque luego la nombren (#617).
- **Compradores**: «Ich suche …» al principio de la descripción, sin que el
  título diga que vende (#140), y «Acquisto» (#1508).

---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
