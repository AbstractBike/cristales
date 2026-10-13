# La memoria

> Que el siguiente agente no reinvente lo que el anterior ya pagó.

Ideas tomadas de TencentDB Agent Memory (MIT, leído, no copiado), adaptadas
a nuestras piezas: GreptimeDB como única base, la [agencia](agencia.md) para
cada transformación con LLM, git para lo que una persona debe poder leer y
corregir, y Nix para desplegarlo.

```
 ~/.claude/projects/*/*.jsonl ──ingesta──► memoria_l0  (GreptimeDB, base memoria)
                                              │ destila (agencia: memoria-atomos, memoria-dedup)
                                              ▼
                                           memoria_l1  (átomos vigentes, versionados)
                                              │ consolida (agencia: memoria-escenas, memoria-persona)
                                              ▼
                     repo memoria: escenas/<slug>.md (L2, tope 15) + persona.md (L3)
                                              │
     Claude Code ◄── hook SessionStart: persona + índice de escenas (estable, cacheable)
                 ◄── MCP memoria: buscar átomos, buscar en L0, leer una escena (bajo demanda)
```

## Capas

| Capa | Qué es | Dónde |
|---|---|---|
| L0 | Mensajes limpios de las sesiones de Claude Code: texto del usuario y del asistente; las tool calls como una línea `[herramienta X: descripción]`, **nunca** su entrada ni su salida | tabla `memoria_l0` |
| L1 | Átomos: un hecho, una preferencia, una regla o un método, válidos fuera de la conversación | tabla `memoria_l1` |
| L2 | Escenas: un tema consolidado (Markdown), con trayectoria y contradicciones anotadas | repo `memoria`, `escenas/` |
| L3 | Persona: quién es el usuario y cómo trabajar con él, ≤ 2000 caracteres | repo `memoria`, `persona.md` |

## Contratos entre piezas

Base GreptimeDB `memoria` (por `https://greptime.pin/v1/sql`, como el resto de
la flota; cliente: `Forja_http.Greptime`).

`memoria_l0` — una fila por mensaje; reingerir es idempotente.

| Columna | Tipo | Nota |
|---|---|---|
| `ts` | TIMESTAMP TIME INDEX | el `timestamp` del mensaje en el JSONL |
| `sesion` | STRING PRIMARY KEY | `sessionId` |
| `uuid` | STRING PRIMARY KEY | `uuid` del mensaje; clave `(sesion, "uuid")`: el motor deduplica por clave + `ts`. Palabra reservada: citarla siempre, `"uuid"` |
| `agente` | STRING | `agentId` del subagente (su `sesion` es la del padre); `''` en la sesión principal. Los `user` de un subagente los escribió el agente padre, no el usuario |
| `proyecto` | STRING | el `cwd` de la sesión |
| `nodo` | STRING | hostname |
| `rol` | STRING | `user` \| `assistant` |
| `texto` | STRING FULLTEXT | limpio y **redactado** (sin secretos); índice tantivy, `matches(texto, '…')` |

`memoria_l1` — append-only; la vigente de cada `id` es la de `version` mayor
y `vigente = true`.

| Columna | Tipo | Nota |
|---|---|---|
| `ts` | TIMESTAMP TIME INDEX | el `ts` del último mensaje de L0 del lote que la escribió, más su orden (0, 1…): determinista, para que reescribir un lote sea idempotente. **No** es la hora de escritura |
| `id` | STRING PRIMARY KEY | `a-<hex12>` estable entre versiones |
| `version` | INT | |
| `vigente` | BOOLEAN | `false` = absorbido por un merge o descartado |
| `tipo` | STRING | `persona` \| `regla` \| `hecho` \| `metodo` \| `episodio` |
| `prioridad` | INT | 0-100; -1 = regla global absoluta |
| `escena` | STRING | nombre de escena propuesto al extraer |
| `contenido` | STRING FULLTEXT | una frase autosuficiente |
| `proyecto` | STRING | |
| `origen` | STRING | JSON: ids de L0 (`sesion/uuid`) de los que sale |
| `fechas` | STRING | JSON: unión ordenada de las fechas de actividad (historia del átomo) |
| `escrito` | TIMESTAMP | hora real de escritura de esta versión (null en filas anteriores a la columna). **Los consumidores incrementales avanzan por `escrito`, no por `ts`**: un lote de una sesión vieja destilado hoy lleva un `ts` viejo. Reescribir un lote cambia `escrito` (se reconsolida) |

## Lo que se copia de Tencent, y por qué

1. **Contexto separado de lo nuevo** al extraer L1: N mensajes previos marcados
   como fondo, *prohibido extraer de ellos*, y los nuevos. No se reextrae.
   Escena y átomos en una sola llamada; fechas absolutas sacadas del `ts`.
2. **Dedup por lotes**: candidatos sin LLM (fulltext de GreptimeDB, top 5 por
   átomo nuevo) y un juez por lote que decide `guardar | saltar | actualizar |
   fusionar` con `objetivos[]` (N:1, entre tipos). Al fusionar, unión de
   `fechas` y la prioridad sube. Si el juez devuelve basura, se guarda todo:
   nunca se pierde nada.
3. **L2 acotado**: tope de 15 escenas; a 12 se recomienda actualizar o fusionar,
   a 14 solo actualizar, a 15 fusionar es obligatorio. Así no hace falta un
   algoritmo de olvido. Las contradicciones no se resuelven en código: se
   anotan en la escena (`## Trayectoria`, `## Por confirmar`).
   **Diferencia con Tencent:** el LLM no edita ficheros con herramientas; devuelve
   operaciones (JSON) y las aplica nuestro código, que respeta `bloqueada: true`.
4. **Inyección que respeta la caché**: lo estable (persona e índice de
   escenas) una vez al arrancar la sesión; lo fino, bajo demanda por MCP.
5. **Skills con nota** (fase 2): atomicidad 30, frontera 25, reutilización 20,
   flujo ejecutable 25; pasa con ≥ 72 y ninguna dimensión < 12.

Lo que **no** se copia: el proxy delante de la API, la ACL por equipos (somos
uno) y los embeddings (BM25/fulltext primero; vectores solo si el recall lo pide).

## Seguridad

Los transcripts llevan tokens, claves y contraseñas. La ingesta **redacta antes
de escribir** (patrones de claves conocidas, `Bearer`, `-----BEGIN`, asignaciones
`*_TOKEN=`/`*_KEY=`/`password`, cadenas de alta entropía) y no guarda nunca la
salida de las herramientas. Una prueba por patrón.

## Reparto de la primera ronda

| Pieza | Dónde | Binario |
|---|---|---|
| A. Ingesta L0 (lectura del JSONL, limpieza, redacción, cursor) | `lib/memoria-l0` | `bin/memoria-ingesta` |
| B. Destilación L1 (prompts, candidatos, juez, escritura) | `lib/memoria-l1` | `bin/memoria-destila` |
| C. Consolidación L2/L3 e importación de las notas de `~/.claude/projects/*/memory` | `lib/memoria-escenas` | `bin/memoria-consolida` |
| D. Recall: MCP y hook SessionStart; módulo de la flota | `lib/memoria-recall` | `bin/memoria-mcp`, `bin/memoria-hook` |
| E. Ejemplos con nota en la agencia | `lib/agencia-http`, `lib/agencia` | — |

## Recall (pieza D)

- `memoria-hook` (SessionStart): `persona.md` y el índice de escenas (calor
  descendente, luego slug) como `hookSpecificOutput.additionalContext`, ≤ 6000
  bytes, sin nada variable: igual byte a byte mientras el repo no cambie. Sin
  repo, no escribe nada. `MEMORIA_REPO` cambia el checkout.
- `memoria-mcp`: `memoria_buscar`, `memoria_conversacion`, `memoria_escena`.
  `MEMORIA_GREPTIME`, `MEMORIA_GREPTIME_DB`, `MEMORIA_TABLA_L0`/`_L1`.

## Consolidación (pieza C)

`memoria-consolida` lee los átomos L1 desde el cursor (`.estado` del repo,
que se mueve en el mismo commit que las escenas), los consolida por lotes con
`memoria-escenas` y regenera `persona.md` con `memoria-persona` si toca.

- **Su propio clon.** Trabaja en `$MEMORIA_ESTADO/repo` (lo clona del bare
  si falta) o en `MEMORIA_REPO`; se niega a trabajar en el checkout canónico,
  en `/` o en algo sin `escenas/`. Antes de leer, `git pull --rebase`; con
  `--push`, empuja al bare con un reintento (pull --rebase y otra vez) y, si
  no puede, sale con error: nunca diverge en silencio. El canónico se pone al
  día desde el bare como el resto.
- **Reglas vigentes.** El `~/.claude/CLAUDE.md` global y
  `/logical-node/AGENTS.md` van en cada encargo como reglas de máxima
  prioridad (`--reglas` las cambia): lo que las contradiga solo puede ir a
  `## Trayectoria` o `## Por confirmar`, nunca a la persona.
- **Historia.** Los átomos de notas importadas llegan marcados como
  historia; los de una etapa anterior (`--etapa-anterior`, por defecto
  `/home/digger`: marzo-abril, Scala/Temporal/hn1/cn1), como solo
  trayectoria. Manda lo más reciente.
- **Longitudes.** Un cuerpo de hasta un 25 % de más se recorta por líneas
  enteras desde el final; más, se rechaza y se pide condensar (al mismo
  modelo y luego al más capaz).
- **Importación de las notas, solo a mano** (`--importar`): es idempotente,
  pero las notas son un canal heredado que L0/L1 sustituye, se reimporta
  mal (una nota editada conserva su id y no se actualiza) y su riesgo es
  de secretos: cada nota pasa por `Memoria_l0.Redaccion` y las de nombre
  delicado (password, credencial, secret, token) no se abren. Una vez basta.
- Entorno: `MEMORIA_REPO`, `MEMORIA_ESTADO`, `MEMORIA_GREPTIME`,
  `MEMORIA_GREPTIME_DB` y los de la agencia (`AGENCIA_*`); los flags mandan.

Lo que se aprendió de GreptimeDB 1.2 al escribirlo, y vale para A y B:

- `id`, `uuid` y `version` son palabras reservadas: en el SQL, entre comillas
  dobles (`"id"`).
- `matches` filtra distinguiendo mayúsculas aunque el índice diga
  `case_sensitive = 'false'`: se busca con `matches(lower(col), …)`.
- En el patrón de `matches`, `or`/`and`/`not` son operadores aunque vayan en
  minúscula, y los términos sueltos son un O; cada término va entre comillas
  dobles (entonces casa como subcadena).
- La barra invertida escapa dentro de un literal: se quita antes de citar.
- Un timestamp se compara con `'AAAA-MM-DD HH:MM:SS'`; `'AAAA-MM-DD'` solo no
  se convierte.
