# La forja

> Un proxy de LLM que cristaliza las tareas que va atendiendo.

[`pipelines.md`](pipelines.md) describe cómo cristalizar una pipeline que
conoces, etapa a etapa. La forja es lo mismo **sin saber de antemano cuáles
son las etapas**: se pone delante del LLM, ve pasar el tráfico, descubre qué
tareas se repiten, avisa cuando una está madura para cristalizar y, una vez
cristalizada, la atiende sin llamar al modelo.

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
| MCP | La vitrina como herramientas para Claude Desktop o Claude Code | `Forja_mcp`, `bin/forja-mcp` |

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

## La vitrina como servidor MCP

El proxy pone la forja *delante* del LLM. `forja-mcp` hace lo contrario: el
LLM llama al cristal cuando lo necesita. Cada cristal de la vitrina es una
herramienta MCP con el nombre de su tarea, un argumento `entrada` (texto) y
la descripción con que se registró en `lib/vitrina/vitrina.ml`:

```ocaml
|> con (tarea "fecha-es") `Mixta fecha_es ~descripcion:"Convierte una fecha …"
```

No hay respaldo líquido: quien llama ya es un LLM. Un defecto vuelve como
resultado con `isError` y el motivo (`defecto: fuera de dominio: …`), y el
modelo decide qué hacer con él. El estado `Mixta`/`Cristalina` no cambia
nada aquí.

Es la forma de usar los cristales desde clientes que no hablan la Messages
API a través de una URL base propia, como el chat de Claude Desktop, que
no se puede poner detrás del proxy. Va por stdio, una línea JSON-RPC por
mensaje:

```json
{ "mcpServers": { "cristales": { "command": "forja-mcp" } } }
```

en `claude_desktop_config.json` (en la flota, lo declara home-manager), o
`claude mcp add cristales -- forja-mcp` en Claude Code. Un cristal nuevo en
la vitrina aparece en los dos sitios a la vez: el proxy y el MCP leen la
misma lista.

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
- **Salida textual.** La forja ve la respuesta como texto. Si la tarea pide
  JSON, el cristal devuelve el JSON como texto; validarlo es trabajo de su red.


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../COPYRIGHT.md).
