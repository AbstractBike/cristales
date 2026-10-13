# Seguimiento de costes

> Cada commit que escribe un LLM dice qué modelo lo escribió y cuánto
> costó. El historial de git se convierte en la contabilidad del trabajo.

Un commit humano cuesta horas; uno de un agente cuesta tokens, y los tokens
tienen precio. Ese precio se sabe en el momento de commitear (la telemetría
del agente lo ha ido contando) y se pierde después: nadie lo apunta, y una
semana más tarde ya no se sabe qué cambio salió caro, con qué modelo, ni si
mereció la pena. El *tracking costs* lo apunta donde no se pierde: en el
propio commit, como *trailers* de git.

```
  sesión del agente ──► telemetría OTel ──► GreptimeDB (claude_code)
        │                                        │
        │  git commit                            │  tokens, coste, modelo
        ▼                                        ▼  por session_id
  mensaje del commit ◄──────── trailers ◄────────┘
        │
        ▼
  git log --format='%(trailers)' ──► coste por repo, rama, cristal, autor, modelo
```

Es la otra mitad de la [forja](forja.md) y la [agencia](agencia.md): ellas
dicen que un cristal **no gasta tokens** y que la agencia elige el modelo
más barato que hace bien un encargo; el seguimiento de costes dice cuánto
gastaba lo que el cristal sustituye y cuánto costó nuclearlo, y con eso se
sabe si cristalizar salió a cuenta.

## Los trailers

Al final del mensaje, separados del cuerpo por una línea en blanco:

```
Model: claude-opus-5-5
Effort: medium
Tokens: 20, 2684, 38678, 751187 del commit
Cost: 0.51 USD del commit
Session: 39dfdb59-6748-440d-8d1b-fb089f2fe82d
```

| Trailer | Qué dice | Si no se sabe |
|---|---|---|
| `Model` | El id exacto del modelo (`claude-opus-5-5`, no «Opus»). Una línea por modelo si la sesión usó varios (un subagente en otro modelo, un encargo a la agencia, una llamada que pasó por la forja) | Nunca falta: el agente sabe qué modelo es |
| `Effort` | El nivel de razonamiento con que corrió la sesión | Se omite |
| `Tokens` | `<input>, <output>, <cache write>, <cache read>`, en ese orden, sin separador de miles. Si hay varios `Model`, una línea `Tokens` por modelo y en el mismo orden | `n/d` |
| `Cost` | El coste en USD que calcula el propio agente con la tarifa de cada modelo, con dos decimales | `n/d` |
| `Session` | El id de la sesión, para volver a la telemetría y a la transcripción | Se omite |

Los cuatro tipos de token van por separado porque cuestan distinto (la
lectura de caché vale una décima parte de la entrada) y porque dicen cosas
distintas: mucho *cache read* es contexto que se arrastra, mucho *output*
es trabajo escrito. Una sola cifra de «tokens» no distingue una sesión
larga y barata de una corta y cara.

Un valor que no se sabe se escribe `n/d`. **Nunca se inventa ni se
estima**: un trailer con una cifra falsa es peor que uno vacío, porque la
suma del historial deja de valer.

### Del commit, no de la sesión

Una sesión hace varios commits. Si cada uno lleva el total de la sesión,
sumar el historial cuenta lo mismo varias veces. Por eso cada commit lleva
lo gastado **desde el commit anterior de la misma sesión** (o desde su
inicio, si es el primero), y lo dice («del commit»). Así la suma de los
trailers de una rama es exactamente lo que costó la rama.

El trabajo que no acaba en commit (una investigación, una respuesta, un
intento descartado) no aparece en el historial. Es deliberado: el historial
cuenta lo que costó lo que quedó; lo que costó todo lo cuenta la telemetría.

## De dónde salen las cifras

Claude Code exporta su telemetría OpenTelemetry a GreptimeDB, base
`claude_code` (lo declara `modules/observability/claude-telemetry.nix` en el
flake de la flota), en **temporalidad delta**: cada punto es lo gastado
desde el anterior, y sumarlos da la cifra exacta. Cada serie lleva
`session_id`, `model` y, en los tokens, `type`.

El id de la sesión es el nombre de su transcripción
(`~/.claude/projects/<proyecto>/<session_id>.jsonl`) y forma parte de la ruta
de su *scratchpad*.

Tokens del commit, por modelo y tipo:

```sql
SELECT model, type, sum(greptime_value)
FROM claude_code_token_usage_tokens_total
WHERE session_id = '<session_id>'
  AND greptime_timestamp > '<fecha del commit anterior de la sesión>'
GROUP BY model, type
```

Coste del commit (el nombre de la tabla lleva mayúsculas y va entre
comillas):

```sql
SELECT model, sum(greptime_value)
FROM "claude_code_cost_usage_USD_total"
WHERE session_id = '<session_id>'
  AND greptime_timestamp > '<fecha del commit anterior de la sesión>'
GROUP BY model
```

La fecha del commit anterior de la sesión se saca del propio historial,
buscando el trailer `Session`:

```bash
git log -1 --format=%cI --grep='^Session: <session_id>$'
```

Los `type` de GreptimeDB se mapean al trailer así: `input` → input,
`output` → output, `cacheCreation` → cache write, `cacheRead` → cache read.

Hay que tener en cuenta el retraso de la exportación: Claude Code manda las
métricas cada cierto intervalo, y lo gastado en los últimos segundos antes
del commit puede no haber llegado. Ese resto cae en el commit siguiente de
la sesión, así que la suma de la rama sigue cuadrando.

Sin telemetría (otro agente, otro ordenador, GreptimeDB caída), la
transcripción tiene el `usage` de cada respuesta del modelo y sirve igual
para los tokens; el coste, entonces, `n/d`.

### Lo que gasta la sesión por otros caminos

Un encargo a la [agencia](agencia.md) o una llamada que pasa por la
[forja](forja.md) gasta tokens de otro modelo, que no cuenta la telemetría
de Claude Code. La agencia y la forja guardan su propio gasto en GreptimeDB
(bases `agencia` y la de la cantera); si la sesión los usó para el commit,
su modelo y sus tokens van en su propia línea `Model`/`Tokens`. Un cristal
no lleva línea: no gasta tokens, que es su razón de ser.

## Leerlo

Los trailers son de git, y git sabe leerlos:

```bash
git log --format='%h %(trailers:key=Model,valueonly,separator=%x2C) %(trailers:key=Cost,valueonly)'
```

Con eso se responde, sin infraestructura nueva:

- **Qué costó una rama o un cristal**: la suma de `Cost` de sus commits.
- **Qué modelo hace qué**: el coste por commit agrupado por `Model`.
- **Si cristalizar salió a cuenta**: lo que costó nuclear y revisar el
  cristal (sus commits) contra lo que gastaba la tarea en la forja antes de
  él (la cantera).
- **Dónde se va el contexto**: commits con mucho *cache read* y poco
  *output* son sesiones que arrastran contexto para escribir poco.

## Configurarlo

En Claude Code, el texto de atribución de los commits es una plantilla
(`attribution.commit` en `~/.claude/settings.json`, declarada en
`modules/core/claude-code.nix` de la flota) que el agente rellena al
commitear con las consultas de arriba. Las instrucciones del agente le
dicen que nunca invente un valor.

## Límites

- **Lo escribe el agente.** Un trailer es texto del mensaje: un agente que
  se equivoca de consulta o de sesión pone una cifra mala, y nada la
  comprueba. Lo verificable es el `Session`, que lleva a la telemetría.
- **Precio de tarifa.** El coste es el de la tarifa pública por token. Con
  una suscripción, lo que se paga de verdad es otra cosa; la cifra sigue
  sirviendo para comparar.
- **No es todo el gasto.** Lo que no acaba en commit no está (ver arriba).
- **Commits de varias manos.** Si un humano edita el commit de un agente,
  los trailers siguen diciendo lo que gastó el agente, no lo que costó el
  commit.

---

© 2026 Silvio Macías Sánchez. Ver [COPYRIGHT.md](../COPYRIGHT.md).
