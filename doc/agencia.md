# La agencia

> Agentes que saben a qué modelo pedir cada cosa, y que no olvidan cómo les fue.

La [forja](forja.md) pregunta **si** hace falta un LLM para una tarea y,
cuando deja de hacer falta, la cristaliza. La agencia pregunta **cuál**:
mientras una tarea siga siendo líquida, que la haga el modelo más barato que
la hace bien. Y para saberlo guarda el histórico de cada encargo.

`agencia-mcp` es un servidor MCP: un agente (Claude Code, Claude Desktop)
crea con él otros agentes, les hace encargos y juzga lo que devuelven.

```
 Claude ──agencia_crear──► agente: nombre, instrucciones, escalera de modelos
        ──<agente>───────► ¿qué modelo? ◄── histórico del agente (GreptimeDB)
                               │
                               ▼
                         modelo elegido ──► forja ──► cristal o LLM
                               │
        ◄── salida + id ───────┴──► encargo al histórico
        ──agencia_juzgar─► veredicto (bien / mal) al histórico
```

## Piezas

| Pieza | Qué es | Dónde |
|---|---|---|
| Agente | Nombre (`[a-z0-9-]+`), instrucciones fijas (system), escalera de modelos y uno por defecto | `Agencia.Agente` |
| Escalera | Los modelos que puede usar, del más barato al más capaz | `Agente.escalera` |
| Encargo | Una entrada dada al agente: modelo, motivo, fuente, salida o error, ms, tokens y veredicto | `Agencia.Encargo` |
| Archivo | Agentes, encargos y veredictos; nada se borra | `Agencia.Archivo`, `Archivo_greptime` |
| Política | Cuándo un modelo es fiable o queda descartado, y cada cuánto se explora | `Agencia.Politica` |
| Elección | El modelo del siguiente encargo, con su motivo | `Agencia.elegir` |

El núcleo (`lib/agencia`) es puro salvo el archivo, que se inyecta, como la
cantera en la forja. `lib/agencia-http` habla con los modelos y con
GreptimeDB; `lib/agencia-mcp`, el protocolo; `bin/agencia-mcp`, stdio.

## Cómo elige

Para cada modelo de la escalera, con los encargos de la versión actual de
las instrucciones (otras instrucciones son otro trabajo):

- **por ver** mientras tenga menos de `juicios` juzgados;
- **fiable** si al menos una fracción `acierto` está bien;
- **descartado** si no.

Un error del modelo cuenta como mal sin que haga falta juzgarlo. Lo que no
llegó al modelo (sin conexión, 401, 403, 429, 5xx) no cuenta ni a favor ni
en contra; y lo que respondió un cristal de la forja tampoco: el modelo no
lo vio.

El siguiente encargo va a:

1. el **más barato fiable**; si no hay ninguno,
2. el **de por defecto** del agente (el más capaz de la escalera si no se
   dijo otro) o, si está descartado, el siguiente más capaz que no lo esté
   (y, si no queda ninguno por encima, el más capaz por debajo);
3. pero uno de cada `explorar_cada` encargos va al **más barato por ver**
   por debajo de ese, si lo hay. Así baja de precio cuando puede.

| Parámetro | Valor |
|---|---|
| `juicios` | 3 |
| `acierto` | 0,8 |
| `explorar_cada` | 5 |

Quien encarga puede pedir un modelo (`modelo`): se respeta y cuenta igual.

Sin veredictos la agencia no aprende: por eso cada resultado lleva el id
del encargo y las instrucciones del servidor piden juzgarlos.

## Con la forja

Cada encargo lleva `x-forja-tarea: <agente>`. Por defecto la agencia pide a
los modelos a través de la forja de a2, así que cada agente es también una
tarea de la forja: sus muestras van a la cantera y, si el LLM se repite,
madura y se nuclea. Desde entonces responde el cristal (`fuente: cristal`)
y la agencia lo anota sin cargárselo a ningún modelo. Los dos patrones se
encadenan: primero el modelo más barato que sabe, luego ninguno.

## Herramientas

| Herramienta | Qué hace |
|---|---|
| `agencia_crear` | Crea o redefine un agente (`nombre`, `instrucciones`, `descripcion`, `escalera`, `defecto`, `max_tokens`) |
| `agencia_agentes` | Los agentes, cómo le va a cada modelo con cada uno y a quién irá su siguiente encargo |
| `agencia_historico` | Un agente con sus instrucciones, sus cuentas por modelo y sus últimos encargos |
| `agencia_encargar` | Un encargo (`agente`, `entrada`, `modelo` opcional): salida e id |
| `agencia_juzgar` | El veredicto de un encargo (`agente`, `id`, `bien`/`mal`, `nota`) |
| `<agente>` | Una por agente: `agencia_encargar` para él |

Los modelos se nombran como en su API: `claude-haiku-5-5` va por Messages;
`openai:<modelo>`, por Chat Completions (llama-server, vLLM…).

## Mediciones

El archivo guarda cada encargo entero, para releerlo; además, con
`AGENCIA_GREPTIME`, cada encargo y cada veredicto se mide como un punto con
etiquetas en la misma base (`Medidas`, protocolo de línea de InfluxDB), que
se puede agrupar por PromQL. No hay `/metrics` que scrapear: agencia-mcp es
un proceso por sesión, y cada encargo se mide al hacerse.

| Tabla | Etiquetas | Campos |
|---|---|---|
| `agencia_encargo` | `agente`, `version`, `modelo`, `fuente` (`directo` o la de la forja), `resultado` (`ok`, `error`) | `n` (1), `ms`, `tokens_entrada`, `tokens_salida` |
| `agencia_veredicto` | `agente`, `modelo`, `veredicto` (`bien`, `mal`) | `n` (1) |

Por PromQL se elige el campo con `__field__`, y como son sucesos se suma la
ventana: `sum by (modelo) (sum_over_time(agencia_encargo{__field__="n"}[1h]))`
son los encargos por modelo en la última hora, y el acierto de cada modelo,
los `bien` entre todos los veredictos. Es lo que pinta el dashboard «Agencia»
de Perses (nixos-config, `modules/observability/cristales.nix`).

## Uso

```sh
agencia-mcp
```

| Variable | Por defecto |
|---|---|
| `AGENCIA_ANTHROPIC` | `http://[b1c1:a2::1]:8090` (la forja) |
| `AGENCIA_OPENAI` | sin ella, no hay modelos `openai:` |
| `AGENCIA_ESCALERA` | `claude-haiku-5-5,claude-sonnet-5-5,claude-opus-5-5` |
| `AGENCIA_GREPTIME` | sin ella, el archivo vive en memoria y se pierde al salir |
| `AGENCIA_GREPTIME_DB` | `agencia` |
| `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `OPENAI_API_KEY` | pasan tal cual |

### Archivo en GreptimeDB

Tres tablas append-only, escritas con `greptime_identity`:
`agencia_agentes` (gana la última definición de cada nombre),
`agencia_encargos` y `agencia_veredictos` (gana el último de cada encargo).
El histórico se puede consultar por SQL tal cual, por ejemplo qué modelo
cuesta menos tokens por acierto en cada agente.

---

Divulgado como estado de la técnica: [`legal/divulgacion-agencia.md`](../legal/divulgacion-agencia.md),
sellado con OpenTimestamps el 2026-10-12.
