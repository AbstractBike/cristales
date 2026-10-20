# El registro

El registro es la cantera de semillas: sin él, una etapa no puede
cristalizarse (paso 0 de [`pipelines.md`](pipelines.md)). Es también el
contrato entre las pipelines, escritas en cualquier lenguaje, y las
herramientas de este repositorio.

Un evento por entrada y etapa: una fila de la tabla `cristal_registro` de
GreptimeDB (abajo) o, fuera de la flota, una línea de **JSON Lines**. Los
campos son los mismos en los dos.

## Campos

Comunes a todo evento:

| Campo | Tipo | Qué es |
|---|---|---|
| `v` | entero | Versión del contrato. Hoy `1`. |
| `etapa` | texto | Nombre de la etapa (el del cristal, si lo tiene). |
| `evento` | texto | `cristal`, `liquido`, `defecto` o `comparado`. |
| `entrada` | texto | La entrada **completa**, tal como la recibió la etapa. |

Según el evento:

| `evento` | Fase | Campos | Significado |
|---|---|---|---|
| `cristal` | mixta, cristalina | `salida` | Resolvió el cristal. |
| `liquido` | líquida | `salida` | Resolvió el LLM. |
| `defecto` | mixta, cristalina | `motivo`, `liquido` (texto o `null`) | El cristal no supo. En mixta, `liquido` es lo que respondió el LLM después; en cristalina es `null` y la pipeline falla. |
| `comparado` | sombra | `liquido`, y `cristal` o `motivo` | Respondió el LLM; el cristal corrió al lado y dio `cristal`, o declaró un defecto con `motivo`. |

Cualquier otro campo se ignora al leer. Los recomendados son `ts` (RFC 3339) y
`modelo` (el del LLM, si lo hubo). El cristal es puro y no sabe la hora, así
que los añade quien escribe el registro.

```json
{"v":1,"etapa":"fecha-es","evento":"defecto","entrada":"el próximo martes","motivo":"fuera de dominio: el próximo martes","liquido":"2026-10-13","modelo":"claude-haiku-4-5","ts":"2026-10-11T09:00:00Z"}
```

## Dónde vive: GreptimeDB

La única base de la flota es GreptimeDB, y el registro es una tabla suya con
las columnas llamadas como los campos (más `ts`):

```sql
CREATE TABLE IF NOT EXISTS cristal_registro (
  ts TIMESTAMP(3) NOT NULL DEFAULT current_timestamp(),
  etapa STRING NOT NULL,
  evento STRING NOT NULL,
  entrada STRING NOT NULL,
  salida STRING NULL,
  motivo STRING NULL,
  liquido STRING NULL,
  cristal STRING NULL,
  modelo STRING NULL,
  v INT NOT NULL,
  TIME INDEX (ts),
  PRIMARY KEY (etapa, evento)
) WITH (append_mode = 'true');
```

`append_mode` porque dos eventos de la misma etapa en el mismo milisegundo son
dos filas, no una que pisa a la otra.

**En la flota la cantera es la forja**, no esta tabla. Las apps (los `*.email`)
mandan su LLM por la forja ([`forja.md`](forja.md)), que guarda cada entrada y
su salida en `forja_cantera` (base `forja`); lo que resuelve su vitrina sin
LLM no deja muestra y se cuenta en `forja_vitrina_aplicaciones_total{tarea,
resultado}`. Hasta el 2026-10-20 buzon-kt escribía además `cristal_registro`
en la base de cada app, y era lo mismo dos veces. Esta tabla queda para las
pipelines que no pasan por la forja: `Registro.escribir` como `~observar` da
JSON Lines, y para GreptimeDB el mismo evento va en un `INSERT` a ella.

Leerlo no pide convertir nada: `cristales` lee la respuesta de `/v1/sql` tal
cual.

```sh
curl -s "$GREPTIME_URL/v1/sql?db=coches" \
  --data-urlencode "sql=SELECT * FROM cristal_registro WHERE ts > now() - INTERVAL '7 days'" \
  > registro.json
cristales grado registro.json
cristales semillas registro.json SearchAgent
```

## Reglas

- **Se registra la entrada, no su hash.** Un hash sirve de clave de caché,
  pero no de semilla.
- **Un evento por entrada y etapa.** Así el grado de cristalización es
  `cristal / total` y no hay que reconstruir qué pasó.
- **La salida se escribe igual que se compara.** En sombra, dos salidas
  coinciden si su texto es idéntico. Si el orden de las claves JSON o los
  espacios pueden variar, se normalizan antes de escribirlas.
- **El registro no se edita.** Es un hecho, no una opinión: lo que se revisa a
  mano son las semillas que salen de él.

## Herramientas

```sh
cristales grado    REGISTRO          # grado y acuerdo por etapa
cristales semillas REGISTRO ETAPA    # filas candidatas para SEMILLA.md
```

`REGISTRO` es la respuesta de GreptimeDB o un fichero JSON Lines.

`semillas` saca los defectos y las discrepancias de sombra, sin repetir
entrada, con lo que dijo el LLM como salida propuesta. No van a la semilla sin
revisarlas: a veces el que se equivocaba era el líquido.


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Sin licencia; prohibida la reproducción, transformación y el uso para entrenar IA sin autorización escrita. Ver [COPYRIGHT.md](../COPYRIGHT.md).
