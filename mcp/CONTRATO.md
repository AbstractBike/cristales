# forja-mcp: el contrato

Un servidor MCP que pone la forja al alcance de un agente (Claude Code, Claude
Desktop, cualquier cliente MCP): ver qué tareas pasan por ella, cuánto les
falta para cristalizar, leer sus semillas y el prompt para nuclearlas, y
llamar a los cristales de la vitrina como herramientas.

Hay una implementación por lenguaje (`mcp/<lenguaje>/`, la de OCaml en
`bin/forja-mcp`). Todas cumplen **este** contrato, y
[`conformidad`](conformidad/) lo comprueba: arranca una forja falsa, lanza el
servidor y le habla por stdio.

Ninguna reimplementa la forja: son clientes finos de la API de
introspección que sirve el proxy (`/forja/…`, abajo). La lógica está una sola
vez, en OCaml.

## Transporte

- **stdio**, JSON-RPC 2.0, **un mensaje por línea** (UTF-8, sin saltos de
  línea dentro del mensaje) en los dos sentidos.
- Por stdout solo salen respuestas. Los logs van a stderr.
- Configuración por entorno: `FORJA_URL`, raíz HTTP de la forja. Por defecto
  `http://[b1c1:a2::1]:8090`.
- Se atiende un mensaje detrás de otro, en orden.

## Métodos

| Método | Respuesta |
|---|---|
| `initialize` | `{protocolVersion, capabilities: {tools: {}}, serverInfo: {name: "forja-mcp", version: "0.2.0"}}` |
| `ping` | `{}` |
| `tools/list` | `{tools: [...]}` (abajo) |
| `tools/call` | `{content: [{type: "text", text}], isError}` (abajo) |
| cualquier mensaje sin `id` | nada (es una notificación, p. ej. `notifications/initialized`) |

`protocolVersion`: si el cliente pide una de `2025-11-25`, `2025-06-18`,
`2025-03-26`, `2024-11-05`, se le devuelve esa; si no, `2025-11-25`.

El `id` de la respuesta es el de la petición, tal cual (número o cadena).

Errores JSON-RPC (`{jsonrpc, id, error: {code, message}}`):

| Código | Cuándo |
|---|---|
| `-32700` | La línea no es JSON. `id: null`. |
| `-32600` | No es un objeto, o le falta `method`. |
| `-32601` | Método desconocido. |
| `-32602` | Herramienta desconocida, o argumentos que faltan o no valen. |

## Herramientas

`tools/list` devuelve primero las cuatro fijas, en este orden, y después
una por cristal de la vitrina, en el orden en que los da
`GET /forja/vitrina`. Si la forja no responde, devuelve solo las cuatro
fijas (y lo cuenta por stderr).

| Nombre | Argumentos | Llama a |
|---|---|---|
| `forja_tareas` | ninguno | `GET /forja/tareas` |
| `forja_tarea` | `tarea` (string, obligatorio), `muestras` (integer, opcional, 5 por defecto) | `GET /forja/tareas/{tarea}?muestras={muestras}` |
| `forja_semilla` | `tarea` (string, obligatorio) | `GET /forja/tareas/{tarea}/semilla` |
| `forja_nucleacion` | `tarea` (string, obligatorio) | `GET /forja/tareas/{tarea}/nucleacion` |
| `{tarea}` de cada cristal | `entrada` (string, obligatorio) | `POST /forja/vitrina/{tarea}` con `{"entrada": …}` |

Cada herramienta lleva `name`, `description` e `inputSchema`
(`{type: "object", properties: {...}, required: [...]}`); `forja_tareas`,
`properties: {}` y sin `required`. La descripción de un cristal es la que da
la vitrina.

Descripciones de las fijas (literales):

- `forja_tareas`: «Tareas que han pasado por la forja: fase (liquida, mixta o cristalina), muestras en la cantera, contrastes, coincidencias y si ya está madura para nuclear.»
- `forja_tarea`: «Detalle de una tarea de la forja: su informe, su plantilla (las instrucciones fijas) y sus últimas muestras de la cantera.»
- `forja_semilla`: «SEMILLA.md de una tarea: la plantilla y las muestras de la cantera, en el formato con el que se nuclea un cristal.»
- `forja_nucleacion`: «Prompt de nucleación de una tarea: lo que se le pide al LLM para que escriba el cristal (el método, no el resultado).»

### Validación

- `tarea` tiene que cumplir `^[a-z0-9-]{1,64}$` (es un nombre de tarea de la
  forja; así no hay forma de colarse en otra ruta). Si no: `-32602`.
- `muestras`, si viene, es un entero entre 0 y 1000. Si no: `-32602`.
- Falta un argumento obligatorio o no es del tipo: `-32602`.
- Una herramienta que no es fija y cuyo nombre no cumple el patrón: `-32602`.

### Resultados

- **Fijas.** 2xx: `isError: false` y el cuerpo de la respuesta tal cual como
  `text`. Cualquier otro estado, o la forja no responde: `isError: true` y un
  texto que empieza por `forja: `.
- **Cristales.** `POST /forja/vitrina/{tarea}`:
  - 200 `{"salida": s}` → `isError: false`, `text: s`.
  - 200 `{"defecto": m}` → `isError: true`, `text: "defecto: " + m`. Un
    defecto no es un fallo del protocolo: el modelo lo lee y decide.
  - 404 → error JSON-RPC `-32602` (no hay tal cristal).
  - otro estado, o la forja no responde → `isError: true`, texto que empieza
    por `forja: `.

## La API de introspección de la forja

La sirve el proxy (`lib/forja-http/proxy.ml`) junto a `/v1/messages`. Todo
JSON salvo las semillas (`text/markdown`).

```
GET  /forja/vitrina
  200 [{"tarea": "fecha-es", "estado": "mixta", "descripcion": "…"}]

POST /forja/vitrina/{tarea}        {"entrada": "3 de marzo de 2024"}
  200 {"salida": "2024-03-03"}  |  200 {"defecto": "…"}  |  404  |  400

GET  /forja/politica
  200 {"minimo": 20, "contrastar_cada": 10, "contrastes": 2, "estabilidad": 0.9}

GET  /forja/tareas
  200 [{"tarea": "t-712d41d0978b", "fase": "liquida", "muestras": 23,
        "contrastes": 2, "coincidencias": 2, "madura": true}]

GET  /forja/tareas/{tarea}?muestras=5
  200 {"tarea", "fase", "muestras", "contrastes", "coincidencias", "madura",
       "plantilla": "…",
       "ultimas": [{"entrada", "salida", "contraste": null, "defecto": null}]}
  404

  "salida" es null en el defecto de un POST /forja/vitrina/{tarea}: queda en
  la cantera con su motivo, pero nadie le pidió la respuesta al LLM. Esas
  muestras no cuentan en "muestras".

GET  /forja/tareas/{tarea}/semilla       200 text/markdown | 404
GET  /forja/tareas/{tarea}/nucleacion    200 text/markdown | 404
```

## Usarlo

```json
{ "mcpServers": { "forja": { "command": "forja-mcp",
                             "env": { "FORJA_URL": "http://[b1c1:a2::1]:8090" } } } }
```

o `claude mcp add forja -e FORJA_URL=http://[b1c1:a2::1]:8090 -- forja-mcp`.
