# Expediente legal de cristales y la forja

> **No es asesoramiento jurídico.** Es un expediente técnico preparado para
> que lo revise un abogado de propiedad intelectual o un agente de la
> propiedad industrial antes de actuar. Lo marcado como «Tú» son pasos que
> exigen tu identidad, tu firma o un pago, y no se han dado.

## Estrategia decidida: publicación defensiva

Se renuncia a patentar y se busca lo contrario: que el método y sus
variantes sean **estado de la técnica** con fecha cierta, para que nadie pueda
patentarlos después y te los oponga. Se combina con lo que sí protege la
expresión concreta: **derechos de autor**, **licencia** y, si se quiere,
**marca**.

### Lo que ya ha pasado (y condiciona)

- `AbstractBike/cristales` es **público en GitHub** desde el
  **2026-10-11T03:06Z**, y la forja está en él desde las **05:56Z**
  (commit `581d980`). En Europa no hay periodo de gracia: lo divulgado ya no
  es patentable por nadie, tampoco por ti. En EE. UU. habría un año de gracia
  para el autor (hasta el 11 de octubre de 2027), por si cambias de idea solo
  allí; consúltalo antes de que venza.
- La fecha de un commit la escribe quien lo hace: **no prueba nada por sí
  sola**. La prueba fuerte es lo que registran terceros (GitHub, Software
  Heritage, un sello de tiempo, un registro). Por eso los pasos de abajo.
- Esta rama (`forja-mcp-multilenguaje`), con los MCP y este expediente,
  **no se ha publicado**: lo que entra en `main` acaba en GitHub.

## Pasos, en orden

| # | Qué | Para qué | Quién |
|---|---|---|---|
| 1 | Revisar [`divulgacion-tecnica.md`](divulgacion-tecnica.md) con un profesional y ampliar las variantes (§4) | Cuanto más amplio lo divulgado, menos espacio para patentes de terceros | Tú + profesional |
| 2 | Sello de tiempo del commit y del documento (abajo) | Fecha cierta independiente de GitHub | **Hecho** el 2026-10-11 (pendiente de anclar en Bitcoin: `ots upgrade`) |
| 3 | Archivar el repositorio en **Software Heritage** («Save code now») | Copia y fecha en un archivo público e independiente | Tú (gratis) |
| 4 | Publicar la divulgación en un repositorio de prior art: **Technical Disclosure Commons** (gratis, lo leen examinadores) y/o **Zenodo** (DOI) o **arXiv** | Que los examinadores de patentes la encuentren | Tú |
| 5 | Registrar la obra (código y documentación) en el **Registro de la Propiedad Intelectual** (o en un registro privado tipo Safe Creative) | Presunción de autoría y fecha en España | Tú (tasa) |
| 6 | Decidir la **marca** ([`marca.md`](marca.md)) | Que nadie registre el nombre del patrón | Tú |
| 7 | Publicar esta rama (los MCP) | Solo después de 2–4 | Tú |
| 8 | Si entran contribuciones de terceros: acuerdo de cesión o licencia de contribuidor (CLA) | Seguir siendo el único titular para poder licenciar en comercial | Tú |

### Sello de tiempo (paso 2)

**Hecho el 2026-10-11T06:46Z.** [`sellos/huellas-2026-10-11.txt`](sellos/huellas-2026-10-11.txt)
recoge el commit de `main` ya público (`662aeda`), el de esta rama sin
publicar (`af5955d`), cada uno con el SHA-256 de su contenido, y el de
[`divulgacion-tecnica.md`](divulgacion-tecnica.md). Ese manifiesto y la
divulgación están sellados (`.ots` al lado). La etiqueta
`divulgacion-2026-10-11` marca el commit público; el de la rama no se
etiqueta, porque subir las etiquetas a GitHub lo publicaría. Para completar
los sellos cuando Bitcoin los confirme (unas horas) y comprobarlos:

```bash
nix shell nixpkgs#opentimestamps-client -c ots upgrade legal/sellos/huellas-2026-10-11.txt.ots legal/divulgacion-tecnica.md.ots
```

```bash
nix shell nixpkgs#opentimestamps-client -c ots verify legal/sellos/huellas-2026-10-11.txt.ots
```

Cómo se hizo, por si hay que repetirlo con otra versión:

Sin enviar el contenido a nadie: solo su huella.

```bash
git -C /logical-node/repositories/logical-license/cristales tag -a divulgacion-2026-10-11 -m "Divulgación defensiva de la forja" origin/main
```

```bash
git -C /logical-node/repositories/logical-license/cristales rev-parse divulgacion-2026-10-11^{commit} > huella-commit.txt
```

```bash
nix shell nixpkgs#opentimestamps-client -c ots stamp huella-commit.txt legal/divulgacion-tecnica.md
```

`ots stamp` manda **solo los SHA-256** a los calendarios de OpenTimestamps,
que los anclan en la cadena de Bitcoin; los `.ots` resultantes se guardan
junto a los ficheros y se verifican con `ots verify`. Con firma GPG del tag
(`git tag -s`) la autoría queda además ligada a tu clave.

## Derechos de autor y licencia

[`COPYRIGHT.md`](../COPYRIGHT.md) ya cubre lo esencial: todos los derechos
reservados, uso libre en investigación y docencia sin ánimo de lucro con
cita, uso comercial con autorización escrita, reserva de minería de textos y
datos (art. 4.3 Directiva 2019/790; art. 67.3 LPI) y derechos morales.
Puntos a revisar con el profesional:

- **Las ideas no tienen copyright**, solo su expresión. El copyright protege
  el código, los textos y los prompts tal como están escritos; el *método* lo
  protege, frente a patentes ajenas, la divulgación. Que alguien reimplemente
  la idea desde cero no lo impide el copyright.
- **«Investigación sin ánimo de lucro»** es un concepto con zonas grises
  (laboratorios de empresa, universidades con contratos). Conviene definirlo
  o dar ejemplos.
- **Paquetes.** Cada implementación lleva la cabecera de copyright y su
  paquete declara licencia privativa (`unfree`, `SEE LICENSE IN
  COPYRIGHT.md`, `publish = false`). Si se publican en registros (npm,
  crates.io, Maven), hay que copiar `COPYRIGHT.md` dentro de cada paquete.
- **Reserva de minería** legible por máquina: además del texto, un
  `robots.txt`/`ai.txt` o metadatos TDMRep en cualquier web que lo sirva.
- **Código generado por IA.** Partes del código y de los textos se
  escribieron con asistencia de modelos de lenguaje. La protección por
  derechos de autor exige aportación creativa humana; conviene documentar la
  dirección, selección y revisión humanas (los commits y este expediente
  ayudan) y que el profesional valore el alcance.

## Lo que no se ha hecho

Nada que publique, registre, firme o pague: ni el tag, ni el sello, ni
Software Heritage, ni TDCommons, ni registros, ni la marca. Todo queda listo
para que lo hagas tú o lo encargues.
