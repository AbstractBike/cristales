# Semilla: tv-modelo

Los televisores que nombra un texto: los códigos que trae («OLED77C6ELB»,
«75U7SE», «GQ65S95BAT», «XR-65A95K», «TX-65Z95A», «65OLED856/12»), las series
que nombra sin código («LG C5», «Sony BRAVIA 8 II», «Xiaomi TV S Mini LED»),
con lo que el catálogo sabe de cada una; y lo que pide quien se da de alta en
smarttv.email: tamaños, tecnologías, marcas, Hz. Es lo que alguien escribe al
darse de alta («una OLED de 77 o una mini-LED de 75, LG C6 o Hisense U7»,
«75 pulgadas o más, 120 Hz») y lo que leen tv-anuncio y tv-noticia.

- Entrada: texto libre, en castellano, alemán, italiano, portugués, francés o
  inglés.
- Salida: JSON `{"modelos": [...], "desconocidos": [...], "pulgadas": [...],
  "pulgadas_min": int|null, "tecnologias": [...], "marcas": [...],
  "hz_min": int|null}`.
  - Cada modelo: `marca` (clave: `lg`, `samsung`, `sony`, `tcl`,
    `hisense`, `philips`, `panasonic`, `xiaomi`…), `modelo` (canónico,
    ver abajo), `serie`, `anio`, `pulgadas`, `tecnologia` (`oled`,
    `qd-oled`, `mini-led`, `rgb-mini-led`, `qled`, `led`), `gama`
    (`alta`, `media-alta`, `media`, `entrada`), `precio_lanzamiento`,
    y además `precio_nuevo` (idealo.es, 2026-10-23, nueva, no de
    lanzamiento), `hz`, `sistema` y `en_catalogo`.
  - `desconocidos`: los modelos que lee de un código pero no están en el
    catálogo («Samsung TQ77S99H»); también van en `modelos`, con lo que dice
    el código (tamaño, año por la letra, tecnología por la familia).
  - `pulgadas_min`: el menor de `pulgadas` si dice «o más», «mínimo», «ab»,
    «at least»; `hz_min`, los Hz que dice.

## El modelo canónico

La marca y el código del modelo sin variantes de mercado: el mismo para la
misma tele venga de donde venga.

| Marca | Con tamaño | Sin tamaño | Serie |
|---|---|---|---|
| LG OLED | `LG OLED77C6` | `LG OLED C6` | `C6` (letra + año: 9, X, 1…6) |
| LG LCD | `LG 65QNED86`, `LG 55UP77` | | `QNED86` |
| Samsung | `Samsung TQ77S95H` (TQ: OLED, QLED, Neo QLED, The Frame; UE: Crystal UHD; GQ, QE y QN se escriben TQ) | `Samsung S95H` | `S95H` (S92/S93/S94 son la S90) |
| Sony | `Sony 75XR90`, `Sony 65A95K` (sin KD-, XR-, K-) | `Sony BRAVIA 9` | `BRAVIA 9`, `A95K` |
| Hisense | `Hisense 75U7SE`, `Hisense 75U7S PRO`, `Hisense 55U7KQ` (la variante) | `Hisense U7SE` | `U7` (la familia) |
| TCL | `TCL 75C8L` | `TCL C8L` | `C8L` |
| Philips | `Philips 65OLED809` | `Philips OLED809` | `OLED809` |
| Panasonic | `Panasonic TX-65Z95A` | `Panasonic Z95A` | `Z95A` |
| Xiaomi | `Xiaomi TV S Mini LED 75 2025` (el año, si el catálogo lo sabe) | `Xiaomi TV S Mini LED 2025` | `S Mini LED` |

Una familia nombrada sin año («Hisense U7», que son U7SE, U7S PRO, U7Q…) da
`Hisense 75U7`, serie `U7`, sin año ni precio.

## El catálogo

`catalogo.ml`: las series de 2024, 2025 y 2026 de LG (B, C, G, M; y las OLED
desde 2017), Samsung (S85/S90/S95, QN70–QN95 y QN700–QN990, Q6x–Q8x, Q6F–Q8F,
M70H/M80H, The Frame, Crystal UHD y U7000F/U8000F), Sony (BRAVIA 3/5/7/8/9, 8 II
y 9 II, y A75–A95, X75–X95 de 2021–2023 y las de antes), TCL (C6K–C8L,
QM6K–QM9K, QM6L–QM8L, P6K–P8L, T69, T8B, X11K/L y las C/P de 2022–2024),
Hisense (U6/U7/U8/UX de 2023–2026 con U7SE y U7S PRO, E7, A85), Philips
(OLED7xx–9xx, PML, PUS por su cifra), Panasonic (Z80A–Z95B, W80A–W95B,
MZ/LZ/JZ/HZ/GZ) y Xiaomi (S Mini LED 2025, S Pro Mini LED 2026, A Pro, F Pro,
F, A, Max, Q1E, P1E…). Lo que no se sabía con seguridad va a `null` (los Hz
de las series de 2026, la tecnología de la BRAVIA 9 II, de las P8L). Ningún
precio de lanzamiento: no se conocían con seguridad.

Precios nuevos (idealo.es, 2026-10-23): Hisense 75U7SE 999 €, 75U7S PRO
1.161 €, LG OLED77B6 1.499 €, OLED77C6 2.249 €, Samsung TQ77S95H 2.379 €, Sony
BRAVIA 9 II 75" 3.499 €, TCL 75C7L 1.139 €, 75C8L 1.739 €, 75P8L 708 €; Xiaomi
TV S Mini LED 75 (2025) desde 689 €. Referencia de mercado (RTINGS,
2026-09-15): las mejores de 75-77", Samsung S95H, LG C6, LG B6, Hisense U7
(U7SE / U7S PRO en Europa), Hisense U6; y LG G6, Sony BRAVIA 9 II, TCL QM7K.

## Las pulgadas

De las unidades («75"», «75”», «75''», «75 pulgadas», «75 Zoll», «75zoll»,
«75 pollici», «75 polegadas», «75 pouces», «75 inch»; «31,5 Zoll» es 32;
«55, 65, 75 Zoll» son tres), de los cm («189 cm», «1,89 m»: la pulgada de los
tamaños que se fabrican más cercana), del código (OLED77C6, 75U7SE, TQ77S95H,
KD-75X85L, 75PUS8909, TX-65Z95A, L75MA-SME; y, de cualquier marca, un prefijo
corto, el tamaño y una letra: H65M80FUX, K24DLX10H) y de un número suelto de
los tamaños que se fabrican («OLED de 77», «TV Samsung 55 4K»). No son
tamaños: 120 Hz, HDMI 2.1, 4K, 1500 €, «PS 5», ni los de un soporte («hasta
75"», «bis 85 Zoll», «für 77 Zoll»).

Una serie nombrada sin código toma el tamaño de justo detrás («LG C6 77»); si
no, el que va con su tecnología («una OLED de 77 … LG C6»); si no, el único
del texto; si no, el de justo delante.

## Ejemplos

| Texto | modelo, serie, año, pulgadas, tecnología |
|---|---|
| `LG OLED77C6ELB` | LG OLED77C6, C6, 2026, 77, oled |
| `Hisense 75U7SE` | Hisense 75U7SE, U7, 2026, 75, mini-led |
| `TCL 75C8L` | TCL 75C8L, C8L, 2026, 75, mini-led |
| `Samsung TQ77S95HATXXC` | Samsung TQ77S95H, S95H, 2026, 77, qd-oled |
| `Samsung OLED 55S90C (S93C) QD-OLED TV` | Samsung TQ55S90C, S90C, 2023, 55, qd-oled |
| `Sony BRAVIA 8 II [K55XR8M2] 55”` | Sony 55XR8M2, BRAVIA 8 II, 2025, 55, qd-oled |
| `Sony Bravia 85 Zoll 4k (KE-85XH9096)` | Sony 85XH90, XH90, 2020, 85, led |
| `Hisense 85U7Q PRO – 85 Zoll ULED Mini-LED` | Hisense 85U7Q PRO, U7, 2025, 85, mini-led |
| `Hisense E77Q 43 Zoll` | Hisense 43E7Q, E7, 2025, 43, qled |
| `Philips 65OLED856/12` | Philips 65OLED856, OLED856, 2021, 65, oled |
| `Panasonic TX-42MZ800E` | Panasonic TX-42MZ800, MZ800, 2023, 42, oled |
| `Xiaomi TV S Mini 75 2025 75 Pulgadas` | Xiaomi TV S Mini LED 75 2025, S Mini LED, 2025, 75, mini-led (144 Hz) |
| `LG OLED C5 77 Zoll` | LG OLED77C5, C5, 2025, 77, oled |
| `una OLED de 77 o una mini-LED de 75, LG C6 o Hisense U7` | LG OLED77C6 y Hisense 75U7; pulgadas [77, 75]; tecnologías [oled, mini-led] |
| `75 pulgadas o más, 120 Hz` | sin modelos; pulgadas [75], pulgadas_min 75, hz_min 120 |

## Invariantes

- `pulgadas` está entre 13 y 120; `tecnologia`, `gama` y `sistema` son de
  sus conjuntos; `modelo` empieza por el nombre de la marca.
- Lo que el catálogo dice manda sobre lo que deduce el código.
- Una serie sin código solo cuenta con su marca nombrada, la más cercana de
  antes («Sony A1» no es la LG A1).

## Fuera de dominio (defecto)

- Un texto que no nombra ni modelos, ni tamaños, ni tecnología, ni marca:
  «no nombra ninguna tele, ni tamaño, ni tecnología, ni marca».


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
