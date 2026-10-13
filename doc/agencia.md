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
| Ejemplos | Los encargos juzgados bien que acompañan al siguiente, y las notas de los mal | `Agencia.Ejemplos` |

El núcleo (`lib/agencia`) es puro salvo el archivo, que se inyecta, como la
cantera en la forja. `lib/agencia-http` habla con los modelos y con
GreptimeDB; `lib/agencia-mcp`, el protocolo; `bin/agencia-mcp`, stdio.
`lib/agencia-vista` pinta agentes, cuentas y encargos en JSON (los mismos
para el MCP y para la web); `bin/agencia-vista`, su API de solo lectura.

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

## Ejemplos y advertencias

Los veredictos no solo eligen modelo: cada encargo lleva como ejemplos
(few-shot) los mejores encargos previos del agente, y como advertencias las
notas de los que salieron mal. Así un modelo barato aprende el formato y los
criterios de quien juzga sin que cambien las instrucciones.

| Qué | Cuáles | Dónde van |
|---|---|---|
| Ejemplos | Hasta `ejemplos` (3) encargos de la versión actual con veredicto `bien` y salida, o con **salida corregida** (cualquier veredicto); los más parecidos a la entrada (Jaccard de palabras) y, a igualdad, los más recientes; sin repetir entrada; 6000 bytes en total | Turnos previos usuario (su entrada) / asistente (su salida, o la corregida), del menos parecido al más, justo antes de la entrada |
| Advertencias | Hasta 3 notas no vacías de veredictos `mal` de la versión actual, las más recientes, sin repetir, de 500 bytes como mucho | Un turno previo, el primero: el usuario las da y el asistente responde que las tendrá en cuenta |

La selección es pura y determinista (`Agencia.Ejemplos.elegir`, y
`Ejemplos.turnos` da los turnos): misma historia y misma entrada, mismos
ejemplos. Una entrada de más de 1500 bytes se corta (y lo dice:
`[… N caracteres omitidos]`) solo si su salida es corta, como en una
extracción; si las dos son largas (traducir, reescribir), un ejemplo cortado
enseñaría a inventar lo que falta, y se salta. Un ejemplo que no cabe en lo
que queda del presupuesto también se salta.

`ejemplos` es un campo del agente (`agencia_crear`, de 0 a 10; 3 si no se
dice; 0 apaga ejemplos y advertencias). Se guarda en `agencia_agentes`; las
filas de antes no lo tienen y valen 3. La columna la añade la ingesta de
`greptime_identity` con el primer agente que la lleva; hasta entonces el
archivo lee sin ella. No cambia la versión del agente: la versión son las
instrucciones.

### Salida corregida

Quien juzga a menudo arregla a mano la salida antes de usarla («retoques: el
glosario, el registro»). `agencia_juzgar` acepta `salida_corregida`: si
está, es la que sirve de ejemplo en vez de la del modelo, y vale también para
un `mal` (con su nota como advertencia). No cambia las cuentas por modelo: el
veredicto es del modelo, la corrección es del ejemplo. Se guarda en
`agencia_veredictos.salida_corregida` (cadena vacía si no hay); los
veredictos de antes no la tienen y el archivo los lee igual.

### La caché de prompts

El orden va de lo más estable a lo que más cambia: system (las
instrucciones, fijas toda la versión), turno de advertencias (cambia solo
cuando llega un `mal` con nota nueva, unas pocas veces en la vida de una
versión), ejemplos (cambian con cada entrada, porque se eligen por parecido)
y la entrada. El prefijo cacheable es system + advertencias y dura de un
`mal` al siguiente. En Messages, con ejemplos o advertencias, el system y el
turno del asistente que acepta las advertencias llevan
`cache_control: ephemeral` (por debajo del mínimo de tokens del modelo no se
cachea, y no pasa nada); llama-server y vLLM cachean el prefijo común sin
marcarlo. Sin ejemplos ni advertencias, la petición es byte a byte la de
siempre.

Las advertencias iban al principio al final del system, que cachea igual;
salieron de él porque el system es la plantilla de la tarea en la forja, y
una plantilla que cambia con cada `mal` no identifica nada (ver abajo).

### Con la forja

La forja trataba una petición de varios turnos como conversación y la dejaba
pasar sin muestra (`paso`): con ejemplos, los encargos dejarían de alimentar
la cantera y de recibir el cristal. Ahora, **con `x-forja-tarea` explícita**
(la agencia siempre la pone), los turnos previos usuario/asistente alternos,
de texto y acabados en usuario, son ejemplos: el último turno es la entrada y
la plantilla sigue siendo el system (y la herramienta o el esquema), que son
las instrucciones limpias. Sin tarea explícita, una conversación sigue siendo
`paso`. La tarea es el nombre del agente: la madurez no se fragmenta.

Pero una salida con ejemplos se parece a ellos: si el LLM contesta igual dos
veces puede ser porque copia, no porque haya un método en la plantilla, y
eso inflaría la madurez. Por eso:

- **El contraste se pide sin ejemplos**, las dos veces (`sin_ejemplos`: el
  system y el último turno). Mide la plantilla sola, que es lo que el cristal
  tendrá que reproducir. Quien encargó recibe esa respuesta sin ejemplos: uno
  de cada `contrastar_cada` encargos (10) pierde la ayuda, a cambio de que la
  madurez signifique algo.
- **El resto de muestras van marcadas** (`ejemplos = true`, columna
  `ejemplos` de `forja_cantera`; las filas de antes, sin ella, son `false`).
  Cuentan como muestra para el mínimo y para la semilla, porque son pares
  entrada → salida buenos de la misma tarea (a menudo mejores: aprendidos de
  lo juzgado bien), pero si alguna trajera contraste no contaría para la
  estabilidad.
- El cristal, cuando responde, no ve ni ejemplos ni advertencias: solo la
  entrada.

En la prueba con gemma se ve el sesgo: con un ejemplo corregido a
`negativo-fuerte`, seis encargos seguidos copiaron `negativo-fuerte`; el
contraste sin ejemplos dio `negativo` las dos veces.

La agencia aún no pide salida estructurada; si la pidiera (herramienta
forzada o `json_schema`), los turnos de ejemplo del asistente tendrían que ir
en esa forma (un `tool_use` con su `tool_result`, o el JSON), no en texto.

### Cifras (2026-10-13)

De los dos agentes de producción, uno tiene al menos 3 `bien`:
`traductor-markdown` (17 en la versión actual). Sus encargos son documentos
de 3-15 KB con traducciones igual de largas: ningún ejemplo cabe entero ni
se puede cortar, así que lleva 0 ejemplos y 1 advertencia (unos 50 tokens).
`agencia-humo` lleva 1 ejemplo (24 bytes). La prueba de punta a punta
(agente de prueba con gemma-4-12b, archivo y forja locales) pasó de 45 a 152
tokens de entrada con 3 ejemplos y una advertencia, la forja la contó como
`liquido` con la entrada y la plantilla limpias, y la advertencia cambió la
salida en el sentido que pedía la nota.

## Herramientas

| Herramienta | Qué hace |
|---|---|
| `agencia_crear` | Crea o redefine un agente (`nombre`, `instrucciones`, `descripcion`, `escalera`, `defecto`, `max_tokens`, `ejemplos`) |
| `agencia_agentes` | Los agentes, cómo le va a cada modelo con cada uno y a quién irá su siguiente encargo |
| `agencia_historico` | Un agente con sus instrucciones, sus cuentas por modelo y sus últimos encargos |
| `agencia_encargar` | Un encargo (`agente`, `entrada`, `modelo` opcional): salida e id |
| `agencia_juzgar` | El veredicto de un encargo (`agente`, `id`, `bien`/`mal`, `nota`, `salida_corregida`) |
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

## A la vista

`agencia-vista` lee el mismo archivo de GreptimeDB que escriben los
`agencia-mcp` y lo sirve por HTTP, solo GET: no llama a ningún modelo ni
escribe nada. Es de donde tira `agencia.pin` en la flota
(`modules/services/agencia-ui.nix` de nixos-config): los agentes, cómo le va
a cada modelo con cada uno, a quién irá su siguiente encargo y sus últimos
encargos con su veredicto.

```
GET /agencia/politica                       juicios, acierto, explorar_cada
GET /agencia/agentes                        los agentes con sus cuentas y su siguiente
GET /agencia/agentes/{agente}?encargos=20   uno, con instrucciones y últimos encargos
```

| Variable | Por defecto |
|---|---|
| `AGENCIA_IP`, `AGENCIA_PUERTO` | `127.0.0.1`, `8092` |
| `AGENCIA_GREPTIME` | obligatoria |
| `AGENCIA_GREPTIME_DB` | `agencia` |

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
