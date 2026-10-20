# El registro

El registro es la cantera de semillas: sin él, una etapa no puede
cristalizarse (paso 0 de [`pipelines.md`](pipelines.md)). Es también el
contrato entre las pipelines, escritas en cualquier lenguaje, y las
herramientas de este repositorio.

Formato: **JSON Lines**, un evento por entrada y etapa. En OCaml lo escribe
`Registro.escribir` pasado como `~observar` a `Cristal.ejecutar`; en Go,
Kotlin o Scala basta con emitir las mismas líneas.

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
cristales grado    registro.jsonl          # grado y acuerdo por etapa
cristales semillas registro.jsonl ETAPA    # filas candidatas para SEMILLA.md
```

`semillas` saca los defectos y las discrepancias de sombra, sin repetir
entrada, con lo que dijo el LLM como salida propuesta. No van a la semilla sin
revisarlas: a veces el que se equivocaba era el líquido.


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Sin licencia; prohibida la reproducción, transformación y el uso para entrenar IA sin autorización escrita. Ver [COPYRIGHT.md](../COPYRIGHT.md).
