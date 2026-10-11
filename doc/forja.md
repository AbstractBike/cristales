# La forja

> Un proxy de LLM que cristaliza las tareas que va atendiendo.

[`pipelines.md`](pipelines.md) describe cómo cristalizar una pipeline que
conoces, etapa a etapa. La forja es lo mismo **sin saber de antemano cuáles
son las etapas**: se pone delante del LLM, ve pasar el tráfico, descubre qué
tareas se repiten, avisa cuando una está madura para cristalizar y, una vez
cristalizada, la atiende sin llamar al modelo.

El patrón tiene dos variantes, sobre el mismo núcleo y la misma vitrina:

- **Proxy: la forja delante del LLM.** Las aplicaciones le hablan a la forja
  como si fuera el modelo; ella decide si responde un cristal o el LLM, y
  aprende de lo que responde el LLM. Es la que cristaliza: el resto del
  documento hasta [la variante MCP](#variante-mcp-el-llm-delante-de-la-forja).
- **MCP: el LLM delante de la forja.** Un agente (Claude Code, Claude
  Desktop) tiene la forja como herramientas: llama a los cristales cuando le
  hacen falta y la observa (qué tareas pasan, cuáles están maduras, sus
  semillas y su prompt de nucleación). Es la que cierra el ciclo: el agente
  que la consulta puede nuclear el cristal que la forja le señala.

```
                      ┌──────────────────── forja ─────────────────────┐
 cliente ──/v1/messages──► ¿tarea? ──► vitrina ──► cristal ──► respuesta (x-forja-fuente: cristal)
 (cualquiera                 │            │ defecto
  que hable                  │ paso       ▼
  la Messages API)           │         LLM real ──► respuesta (liquido / defecto)
                             │            │
                             ▼            ▼
                          LLM real     cantera ──► ¿madura? ──► horno/<tarea>/SEMILLA.md
                                                                      nucleacion.md
                      └────────────────────────────────────────────────┘
                                         │ nucleación + revisión + commit (fuera del camino caliente)
                                         ▼
                              cristales/<tarea>/ ──► vitrina (se recompila el proxy)
```

## Caña, no pescado

La tentación de un proxy así es **cachear respuestas**: si ya vi esta
entrada, devuelvo lo que dijo el LLM. Eso es guardar pescado. Solo acierta con
entradas idénticas, crece sin fin y congela tanto los aciertos como los
errores del modelo.

La forja no guarda respuestas para devolverlas. Guarda **muestras** para
pedir, cuando haya bastantes, *el programa* que las produce. Lo que atiende
después es código: generaliza a entradas que nunca vio, se revisa en un
`git diff` y dice cuándo no sabe.

## Piezas

| Pieza | Qué es | Dónde |
|---|---|---|
| Tarea | Instrucciones fijas (la *plantilla*) aplicadas a una *entrada* que varía | `Forja.Tarea` |
| Vitrina | Cristales ya nucleados, revisados y commiteados, por tarea | `Forja.Vitrina`, `lib/vitrina/vitrina.ml` |
| Cantera | Registro de lo que resolvió el LLM: plantilla, entrada, salida, contraste, defecto | `Forja.Cantera`, `Cantera_greptime` |
| Madurez | Política que decide cuándo una tarea está lista para nuclear | `Forja.Madurez` |
| Horno | Directorio donde quedan la semilla y el prompt de nucleación de cada tarea madura | `Horno`, `$FORJA_HORNO` |
| Proxy | Messages API de Anthropic por los dos lados | `Proxy`, `bin/forja` |
| Introspección | La API de solo lectura `/forja/…`: vitrina, tareas, semillas, nucleación | `Introspeccion` |
| MCP | La forja como herramientas para un agente, en seis lenguajes | `mcp/`, `bin/forja-mcp` |

El núcleo (`lib/forja`) es puro salvo la cantera, que se inyecta: decide
(`decidir`) y aprende (`aprender`), pero no habla HTTP ni llama al LLM. La
capa `lib/forja-http` pone el transporte (Eio, cohttp, TLS).

## Qué es una tarea

Una petición es una **tarea cristalizable** si es una función del texto de
entrada con instrucciones fijas:

- un único turno de usuario, solo texto;
- las instrucciones en `system`;
- sin streaming;
- sin herramientas, y la salida es el texto; o con **una herramienta
  forzada** (`tool_choice: {type: tool, name}`), y la salida es el JSON de su
  `input`. Es la forma de las pipelines con salida estructurada (las de
  buzon-kt: trabajo, buscarcasa, coches) y la que mejor cristaliza: el
  esquema de la herramienta ya es medio contrato. El cristal devuelve el JSON
  y la forja lo envuelve en un bloque `tool_use`; si lo que devuelve no es un
  objeto JSON, cuenta como defecto.

La plantilla es el `system` más, si la hay, la definición de la herramienta:
mismo prompt con otra herramienta es otra tarea. El JSON se compara en forma
canónica (claves ordenadas) al contrastar.

La tarea se identifica por la cabecera `x-forja-tarea` si el cliente la pone
(`[a-z0-9-]+`, el nombre que tendrá el cristal), o si no por el digest del
system prompt: misma plantilla, misma tarea (`t-712d41d0978b`).

Lo demás (conversaciones, agentes con herramientas libres, streaming) pasa al LLM
sin tocar, con `x-forja-fuente: paso`. Es lo que [`concepto.md`](concepto.md)
llama abierto por naturaleza: la forja no intenta cristalizarlo.

## Ciclo de una tarea

1. **Líquida.** No hay cristal: la petición va al LLM y el par entrada →
   salida se guarda en la cantera. Una de cada `contrastar_cada` llamadas se
   pide **dos veces** (en paralelo) para medir si el LLM repite la respuesta.
2. **Madura.** Cuando hay `minimo` muestras, al menos `contrastes` contrastes
   y el LLM repitió la respuesta en una fracción `≥ estabilidad` de ellos, la
   forja escribe en el horno `SEMILLA.md` (plantilla + muestras) y
   `nucleacion.md` ([`prompts/cristalizar.md`](../prompts/cristalizar.md)
   relleno). Es la regla práctica de `concepto.md` hecha medida: *si al
   pedirle el resultado dos veces esperas la misma respuesta, esa etapa
   debería ser un cristal*. Un LLM que no se repite no madura, y está bien.
3. **Nucleación.** Fuera del proxy: se le pasa `nucleacion.md` al LLM, se
   revisa lo que devuelve, se completan invariantes y fuera de dominio en la
   semilla y se crea `cristales/<tarea>/` según [`anatomia.md`](anatomia.md).
   La forja no compila ni carga código generado en caliente: el cristal es
   tuyo desde que se commitea, no antes.
4. **Mixta.** El cristal se registra en la vitrina como `` `Mixta `` y se
   despliega el proxy. Lo que sabe lo responde él (`cristal`, sin coste, sin
   red); lo que no, cae al LLM (`defecto`) y queda en la cantera con su
   motivo: son las semillas de la recristalización.
5. **Cristalina.** Con el grado de cristalización en ~1 se pasa a
   `` `Cristalina ``. Un defecto ya no llama al LLM: es un `422` con el
   motivo. El LLM ha salido del camino.

## Política por defecto

| Parámetro | Valor | Por qué |
|---|---|---|
| `minimo` | 20 | El mínimo de ejemplos de [`pipelines.md`](pipelines.md) |
| `contrastar_cada` | 10 | Un 10 % más de llamadas solo mientras la tarea es líquida |
| `contrastes` | 2 | Para no juzgar la estabilidad con un solo dato |
| `estabilidad` | 0,9 | Un modelo que se contradice no tiene un método que dar |

## Uso

```sh
nix run .#default                       # o: forja
```

Se configura por entorno (lo fija el módulo NixOS que lo despliegue):

| Variable | Por defecto |
|---|---|
| `FORJA_IP` | `127.0.0.1` |
| `FORJA_PUERTO` | `8090` |
| `FORJA_UPSTREAM` | `https://api.anthropic.com` |
| `FORJA_HORNO` | `./horno` |
| `FORJA_GREPTIME` | sin ella, cantera en memoria |
| `FORJA_GREPTIME_DB` | `public` |

Los clientes solo cambian la URL base (`ANTHROPIC_BASE_URL=http://…:8090`).
Las cabeceras de autenticación pasan tal cual: la forja no guarda claves.

### En la flota

`fleet.forja` (`nixos-config/modules/services/forja.nix`) la despliega con
el overlay de este flake (`overlays.default`). Corre en a2 para toda la malla:
`ANTHROPIC_BASE_URL=http://[b1c1:a2::1]:8090`, cantera en la GreptimeDB de
la flota (DB `forja`) y horno en `/var/lib/forja/horno`. Un cristal nuevo
llega a la flota con `nix flake update cristales` y un apply.

### Cantera en GreptimeDB

Con `FORJA_GREPTIME` (raíz HTTP, puerto 4000) cada muestra se escribe por
`/v1/ingest` con el pipeline `greptime_identity` en la tabla
`forja_cantera` (append-only, JSON tal cual) y se lee por `/v1/sql`. Al ver
una tarea por primera vez la forja recupera su informe de la cantera, así que
la madurez sobrevive a los reinicios.

La columna `respondida` dice si la salida es del LLM (`false` en los
defectos directos, ver abajo). Las filas de antes de que existiera la tienen
a `null` y cuentan como respondidas; al arrancar se añade a una tabla vieja
(`ADD COLUMN IF NOT EXISTS`) para que el `SELECT` no falle antes de la
primera ingesta que la traiga.

### Un cristal nuevo en la vitrina

```ocaml
(* lib/vitrina/vitrina.ml *)
let vitrina =
  Forja.Vitrina.(vacia
    |> con (tarea "fecha-es") `Mixta fecha_es
    |> con (tarea "t-712d41d0978b") `Mixta Mayus.cristal)
```

Los cristales tipados se adaptan a texto → texto al registrarlos; el contexto
que necesiten (la fecha de hoy para `fecha-es`) lo pone el adaptador, el
cristal sigue puro.

## Variante MCP: el LLM delante de la forja

El proxy pone la forja *delante* del LLM: el modelo es el respaldo de los
cristales. `forja-mcp` le da la vuelta: el LLM es un agente que tiene la
forja entre sus herramientas, y la usa de dos maneras.

```
                    ┌──────────── agente (Claude Code, Claude Desktop…) ────────────┐
                    │                                                              │
   usa los cristales│  fecha-es("pasado mañana") ──► "2026-10-13"                  │
                    │                    defecto ──► isError: el agente decide     │
                    │                                                              │
   observa la forja │  forja_tareas ──► t-712d… líquida, 23 muestras, madura        │
                    │  forja_semilla / forja_nucleacion ──► escribe el cristal ─┐   │
                    └───────────────────────────────────────────────────────────┼───┘
                         │ stdio (MCP)                                          │ commit + revisión
                         ▼                                                      ▼
                    forja-mcp ──HTTP──► forja (/forja/…) ◄──────── vitrina ◄── cristales/<tarea>/
```

**Los cristales como herramientas.** Cada cristal de la vitrina es una
herramienta con el nombre de su tarea, un argumento `entrada` (texto) y la
descripción con que se registró en `lib/vitrina/vitrina.ml`:

```ocaml
|> con (tarea "fecha-es") `Mixta fecha_es ~descripcion:"Convierte una fecha …"
```

No hay respaldo líquido: quien llama ya es un LLM. Un defecto vuelve como
resultado con `isError` y su motivo (`defecto: fuera de dominio: …`), y el
modelo decide qué hacer con él. El estado `Mixta`/`Cristalina` no cambia
nada aquí. El defecto sí queda en la cantera del proxy, que es quien
ejecuta el cristal (`POST /forja/vitrina/<tarea>`): la entrada y el motivo,
sin plantilla y sin salida, porque nadie le pidió la respuesta al LLM. Son
semillas de la recristalización como las del proxy, pero no cuentan para la
madurez: no dicen nada de si el LLM se repite. Con `--local` el cristal
corre en el propio proceso, sin red, y el defecto no se guarda. Es la forma de usar los cristales desde clientes que no se pueden
poner detrás del proxy, como el chat de Claude Desktop.

**La forja como objeto de trabajo.** Cuatro herramientas fijas la hacen
observable:

| Herramienta | Qué da |
|---|---|
| `forja_tareas` | Cada tarea con su fase, muestras, contrastes, coincidencias y si está madura |
| `forja_tarea` | El detalle de una: informe, plantilla y últimas muestras |
| `forja_semilla` | Su `SEMILLA.md`, como la deja el horno |
| `forja_nucleacion` | El prompt de nucleación relleno: lo que se le pide al LLM para que escriba el cristal |

Con ellas el ciclo se cierra sin salir del agente. La forja (variante proxy)
recoge muestras de lo que pasa por ella; el agente (variante MCP) ve qué
tarea ha madurado, lee su prompt de nucleación, escribe el cristal y su red
según [`anatomia.md`](anatomia.md) y propone el commit. La revisión y el
commit siguen siendo la frontera: la forja no carga código generado en
caliente, y el cristal aparece como herramienta (y en el proxy) cuando entra
en la vitrina y se despliega.

### Cómo está hecho

- **Una sola lógica.** Los servidores no reimplementan la forja: son clientes
  finos de su API de introspección, que sirve el proxy junto a
  `/v1/messages` (`Introspeccion`, de solo lectura salvo la ejecución directa
  de un cristal):

  ```
  GET  /forja/vitrina                       los cristales y su descripción
  POST /forja/vitrina/{tarea}               {"entrada"} → {"salida"} | {"defecto"}
  GET  /forja/politica                      con qué se juzga la madurez
  GET  /forja/tareas                        fase, muestras, contrastes, madura
  GET  /forja/tareas/{tarea}?muestras=5     detalle y últimas muestras
  GET  /forja/tareas/{tarea}/semilla        SEMILLA.md
  GET  /forja/tareas/{tarea}/nucleacion     prompt de nucleación
  ```

- **Un contrato, seis lenguajes.** [`mcp/CONTRATO.md`](../mcp/CONTRATO.md)
  fija el transporte (stdio, una línea JSON-RPC por mensaje), las
  herramientas, la validación (`tarea` es `^[a-z0-9-]{1,64}$`, así no hay
  forma de colarse en otra ruta) y los errores. Lo implementan OCaml
  (`bin/forja-mcp`), TypeScript, Go, Rust, Kotlin y Python (`mcp/<lenguaje>/`),
  sin dependencias salvo `serde_json` y `ureq` en Rust.
- **Una prueba para todos.** [`mcp/conformidad`](../mcp/conformidad/) levanta
  una forja falsa, lanza el servidor y le hace 41 comprobaciones por stdio;
  `nix flake check` la pasa contra los seis (`checks.conformidad-<lenguaje>`).

- **A la vista.** La misma API es la que pinta `vitrina.pin` en la flota
  (`modules/services/vitrina-ui.nix` de nixos-config): los cristales, las
  tareas camino de la madurez (con `/forja/politica` para saber cuánto les
  falta) y un campo para probar cada cristal.

### Uso

```json
{ "mcpServers": { "forja": { "command": "forja-mcp",
                             "env": { "FORJA_URL": "http://[b1c1:a2::1]:8090" } } } }
```

en `claude_desktop_config.json`, o
`claude mcp add forja -e FORJA_URL=http://[b1c1:a2::1]:8090 -- forja-mcp` en
Claude Code. Cada lenguaje es un paquete del flake
(`nix build .#forja-mcp-go`, `.#forja-mcp-python`…); el de OCaml viene con
`.#default`.

`forja-mcp --local` (solo el de OCaml) sirve los cristales compilados en el
propio proceso, sin red ni herramientas fijas: para un Claude Desktop fuera
de la malla. Un cristal nuevo en la vitrina aparece en el proxy y en los MCP a
la vez: todos leen la misma lista.

### Cuándo cada variante

| | Proxy | MCP |
|---|---|---|
| Quién llama | Una aplicación, como si la forja fuera el modelo | Un agente, que decide cuándo |
| Sin cristal | Responde el LLM y se guarda la muestra | No hay herramienta: el agente lo resuelve él |
| Defecto | Mixta: el LLM; cristalina: `422` | `isError`: el agente decide |
| Aprende | Sí: cantera, contraste, madurez, horno | Solo los defectos, en la cantera del proxy |
| Nuclea | Deja la semilla en el horno | El agente puede escribir el cristal |

Las dos se usan juntas: el proxy en el camino de las pipelines, el MCP en el
agente que las cuida.

## Cabeceras de respuesta

| `x-forja-fuente` | Significado |
|---|---|
| `cristal` | Respondió el cristal. `usage` a cero: no hubo tokens. |
| `liquido` | Tarea sin cristal; respondió el LLM y se guardó la muestra |
| `defecto` | El cristal no supo. Mixta: respondió el LLM. Cristalina: `422` |
| `paso` | No es una tarea cristalizable; la forja no la tocó |

`x-forja-tarea` dice qué tarea vio la forja: es el nombre a usar para el
cristal.

## Límites conocidos

- **Streaming.** Un cliente que pide `stream: true` siempre pasa. Para que
  una tarea cristalice tiene que pedirse sin streaming (las pipelines lo
  hacen; las CLI interactivas no, y tampoco son tareas).
- **Una sola fibra de estado.** El estado en memoria de la forja (contadores,
  avisos) no está protegido para varios dominios: el proxy corre en uno, con
  fibras de Eio.
- **Salida estructurada, sin esquema.** Con herramienta forzada, la forja
  comprueba que el cristal da un objeto JSON, pero no lo valida contra el
  `input_schema` de la herramienta: eso es trabajo de la red del cristal.
- **Introspección sin autenticación.** `/forja/…` enseña las muestras de la
  cantera (las entradas de las pipelines) a quien llegue al puerto: en la
  flota, solo la malla.


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../COPYRIGHT.md).
