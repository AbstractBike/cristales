# El shim de Claude Code

> La Messages API de Anthropic, servida con la suscripción.

`claude-shim` recibe `POST /v1/messages` y lo contesta con Claude Code
(`claude -p`), con la identidad de un token de `claude setup-token` en vez
de una clave de pago. Lo usan los `*-kt` (trabajo, buscarcasa, coches) y la
[agencia](agencia.md), a través de la [forja](forja.md) de a2 o directamente.

Dos formas de petición:

| Petición | Qué se le pide a Claude | Respuesta |
|---|---|---|
| Con `tools[0]` (tool use forzado) | Un único JSON conforme a su `input_schema` | Bloque `tool_use`, `stop_reason: tool_use` |
| Sin `tools` | Las instrucciones (`system`) y la entrada, tal cual | Bloque `text`, `stop_reason: end_turn` |

Lo nuestro (`system`, y el esquema) va en `--system-prompt`; lo ajeno (la
oferta, el CV, la entrada del encargo) por stdin, nunca mezclado. El CLI
corre sin herramientas, sin MCP y sin skills: solo puede contestar. Cada
llamada tiene un HOME suyo, que es también su cwd, y se borra al acabar.

Una conversación de varios turnos (los ejemplos y advertencias que la
agencia antepone a la entrada) va entera por stdin como transcripción, cada
turno en `<turno rol="user|assistant">`, con la entrada al final; el sistema
lleva una línea que dice que se responde al último turno. Un solo turno va
tal cual. Hasta 2026-10-14 solo se reenviaba `messages[0]`: con ejemplos o
advertencias, el modelo nunca veía la entrada.

`lib/claude-shim` es puro (la petición, el prompt, la respuesta);
`bin/claude-shim`, el servidor. Es el puerto del `ClaudeCodeShim.kt` de
trabajo-kt, con su misma conducta; desde 2026-10-13 corre como servicio de
NixOS en a2 (`modules/services/claude-shim.nix` de nixos-config) en vez de
como imagen construida a mano.

## Uso

| Variable | Por defecto |
|---|---|
| `SHIM_IP`, `SHIM_PORT` | `::`, `8317` |
| `SHIM_CONCURRENCY` | `3` procesos `claude` a la vez |
| `SHIM_TIMEOUT_S` | `180`: plazo mínimo por llamada |
| `SHIM_TIMEOUT_MAX_S` | `580`: plazo máximo (el cliente de la agencia espera 600) |
| `SHIM_TOKENS_S` | `50`: con el `max_tokens` de la petición, el plazo es `max_tokens / SHIM_TOKENS_S` entre mínimo y máximo |
| `SHIM_DIR` | `$TMPDIR/claude-shim`: los HOME efímeros |
| `SHIM_TOKEN` | sin él, abierto a quien llegue; con él, `x-api-key` |
| `CLAUDE_BIN` | `claude` |
| `CLAUDE_CODE_OAUTH_TOKEN` | la identidad del CLI |

`GET /healthz` contesta `{"ok":true}` sin esperar turno.
