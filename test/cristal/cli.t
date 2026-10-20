Grado y acuerdo por etapa sobre un registro de ejemplo:

  $ cristales grado registro.jsonl
  | Etapa | Entradas | Grado | Acuerdo en sombra |
  |---|---:|---:|---:|
  | idioma | 2 | 100.0% | — |
  | regimen | 3 | 0.0% | 33.3% |
  | responder | 1 | 0.0% | — |
  | tipo | 3 | 33.3% | — |
  | **pipeline** | 9 | 33.3% | |

Semillas candidatas: defectos con lo que dijo el líquido, sin repetir entrada:

  $ cristales semillas registro.jsonl tipo
  | Entrada | Salida (propuesta del líquido) | Nota |
  |---|---|---|
  | `hi there` | consulta | defecto: sin palabras clave |
  1 semillas candidatas en tipo

En sombra también cuentan las discrepancias:

  $ cristales semillas registro.jsonl regimen
  | Entrada | Salida (propuesta del líquido) | Nota |
  |---|---|---|
  | `rsi=50 atr=alto` | HIGH_VOLATILITY | el cristal dio RANGING |
  | `rsi=? \| sin datos` | RANGING | defecto: faltan indicadores |
  2 semillas candidatas en regimen

Un registro roto dice dónde:

  $ echo '{"v":1,"etapa":"x"}' > roto.jsonl
  $ cristales grado roto.jsonl
  roto.jsonl:1: falta el campo de texto "entrada"
  [1]
