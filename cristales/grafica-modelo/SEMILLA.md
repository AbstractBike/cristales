# Semilla: grafica-modelo

Las gráficas de sobremesa que nombra un texto, con sus datos: el título de un
anuncio, lo que alguien escribe que busca («una 3080 o una 6800 XT»), un
titular.

- Entrada: texto libre, en castellano, alemán, inglés, italiano o portugués.
- Salida: JSON `{"modelos": [...], "desconocidos": [...], "antiguas": [...],
  "profesionales": [...]}`. Cada modelo, con su clave (`rtx-3080`), su nombre
  (`GeForce RTX 3080`), su fabricante, la memoria que dice el texto (si es una
  de las suyas; si no, la más común), su año, su precio de lanzamiento en
  dólares y un índice orientativo de rendimiento (RTX 4090 = 100).

Antes era una etapa líquida: «¿qué gráfica es esta?» al LLM en cada anuncio
(graficas.email, tarea `grafica-modelo`). La cristalizó el agente que montó
graficas.email, con anuncios y titulares reales del 2026-10-12 por la forja en
su variante MCP: el cristal está en la vitrina, las apps lo llaman como
herramienta y lo que no sabe les vuelve como defecto.

El catálogo (`catalogo.ml`) va de la GTX 750 Ti (2014) a la RTX 5090 y la RX
9070 XT (2025), con las Arc de Intel. El rendimiento es una cifra de memoria
del modelo que lo escribió sobre las tablas comparativas habituales (1440p,
raster): sirve para «una 3070 o mejor» y para el euro por rendimiento, no
para decimales.

## Ejemplos

| Entrada | Modelos (clave/memoria) |
|---|---|
| `ASUS Dual GeForce RTX 3060 ti V2 OC Edition` | rtx-3060-ti/8 |
| `ASUS ROG Strix GTX 1080 Ti 11GB VRAM` | gtx-1080-ti/11 |
| `Gigabyte Radeon RX 6800 XT 16GB GDDR6 Gaming OC` | rx-6800-xt/16 |
| `Gigabyte RTX 2060 Super Windforce OC 8G` | rtx-2060-super/8 |
| `Nvidia RTX 3060 12GB KFA2` | rtx-3060/12 |
| `Placa Gráfica PowerColor RX 5700 XT 8GB` | rx-5700-xt/8 |
| `Sparkle Intel Arc A770 16GB GDDR6 OC` | arc-a770/16 |
| `Tarjeta Gráfica Asus R9 270X 4GB DDR5` | r9-270x/4 |
| `Tarjeta Gráfica ELSA Rx580 2048sp averiada` | rx-580/8 |
| `Tarjeta Gráfica MSI NVIDIA GeForce GT 710 1GB` | gt-710/1 |
| `GeForce RTX3080 SUPRIM X 10G` | rtx-3080/10 |
| `INNO3D GeForce RTX 3080 X3 12GB Grafikkarte in OVP` | rtx-3080/12 |
| `MSI RTX4070 Ti SUPER VENTUS 2X OC 16Gb` | rtx-4070-ti-super/16 |
| `AMD Radeon RX 7900XTX PowerColor Hellhound  Grafikkarte + OVP` | rx-7900-xtx/24 |
| `RX-580P8D V8.0 GTS XXX ED 8GB OC+ 1386M D5 BP 3xDP HDMI DVI` | rx-580/8 |
| `Rx 6800 bzw 6800xt` | rx-6800/16, rx-6800-xt/16 |
| `PC Gaming Ryzen 7 5800X3D + RTX 3080 10GB` | rtx-3080/10 |
| `PC Gaming I5 10400F + 1660 SUPER + 16GB + 500GB` | gtx-1660-super/6 |
| `PC Gamer RTX 1660 + i5 7500` | gtx-1660/6 (el prefijo equivocado no importa) |
| `HYPERX OMEN 45L - Ultra 7 270K plus + 3080 MSI` | rtx-3080/10 |
| `Radeon VII 16GB` | radeon-vii/16 |
| `Ryzen 5 5500 AMD` | ninguno (es un procesador) |
| `PC Gamer 1080p` | ninguno (es una resolución) |
| `Samsung 970 EVO Plus 1TB` | ninguno (es un disco) |
| `Placa ASUS PRIME B460M-A (1151)` | ninguno (es una placa) |
| `MSI MAG X570 Tomahawk` | ninguno |

Y lo que no está en el catálogo, aparte:

| Entrada | Lista |
|---|---|
| `Tarjeta Gráfica Gigabyte GTX 260 OC` | antiguas: gtx 260 |
| `Gráfica AMD HD 6750M 512MB iMac 21,5 2011` | antiguas: hd 6750 |
| `Soporte Low Profile para Nvidia Quadro P1000` | profesionales: quadro p1000 |
| `RTX 4060 Super 8GB` | desconocidos: rtx 4060 super |
| `Intel Arc B770 spotted in shipping manifests` | desconocidos: arc b770 |

## Invariantes

- Cada modelo del catálogo se lee por su nombre («GeForce RTX 4070 Ti Super»)
  y por su clave con espacios («rtx 4070 ti super»), y por ninguno más.
- La memoria que se da es siempre una de las del modelo.
- Un número es un procesador si va detrás de Ryzen, Core, Xeon, i3/i5/i7/i9 o
  r3/r5/r7 (r9 con cuatro cifras), o lleva pegado X, X3D, K, KF, F, G, HX, H
  o U; una resolución con P; una fuente con W; una placa o un monitor con
  otra letra delante (X570, Z790, KA272).
- Sin prefijo, solo se leen los números que no son de nadie más: los de las
  RTX, las GTX de cuatro cifras y la serie 900, y los de las RX.

## Fuera de dominio (defecto)

- Texto sin ninguna gráfica: «no nombra ninguna gráfica».
- Solo gráficas que no están en el catálogo: «modelo desconocido: …». Es la
  semilla de la versión siguiente (una gráfica nueva).


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
