# Semilla: fecha-es

Convierte una fecha escrita en español a ISO 8601 (`AAAA-MM-DD`).

- Entrada: texto corto con una fecha, y la fecha de hoy como contexto.
- Salida: fecha de calendario `(año, mes, día)`.

Antes era una etapa líquida: "¿qué fecha es esto?" al LLM en cada correo.

## Ejemplos

| Entrada (hoy = 2026-10-11) | Salida |
|---|---|
| `3 de marzo de 2024` | 2024-03-03 |
| `el 1 de enero del 2025` | 2025-01-01 |
| `29 de Febrero de 2024` | 2024-02-29 |
| `15 de agosto` | 2026-08-15 |
| `lunes, 5 de octubre de 2026` | 2026-10-05 |
| `03/03/2024` | 2024-03-03 |
| `3-3-24` | 2024-03-03 |
| `2024-03-03` | 2024-03-03 |
| `hoy` | 2026-10-11 |
| `mañana` | 2026-10-12 |
| `pasado mañana` | 2026-10-13 |
| `ayer` | 2026-10-10 |
| `anteayer` | 2026-10-09 |
| `1º de mayo de 2026` | 2026-05-01 |

## Invariantes

- La fecha existe en el calendario gregoriano (nada de 30 de febrero).
- Formato numérico ambiguo: se lee siempre día/mes/año (convención española).
- Años de dos cifras: `00`–`69` → 20xx, `70`–`99` → 19xx.
- El resultado no depende de nada más que la entrada y la fecha de hoy.

## Fuera de dominio (defecto)

- Fechas imposibles: `30 de febrero de 2024`, `31/04/2024`.
- Expresiones relativas no listadas: `el próximo martes`, `dentro de tres semanas`.
- Rangos o fechas múltiples: `del 3 al 5 de marzo`.
- Texto sin fecha.


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../../COPYRIGHT.md).
