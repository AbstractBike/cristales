<!-- © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
     Libre para investigación; uso comercial: ver COPYRIGHT.md. -->

# forja-mcp en Go

Servidor MCP de la forja escrito en Go, solo con la biblioteca estándar.
Cumple [`../CONTRATO.md`](../CONTRATO.md): stdio, un mensaje JSON-RPC por
línea, cliente fino de la API `/forja/…` del proxy.

## Construir

```sh
go build -o forja-mcp .        # o, con Nix:
nix build --impure --expr 'let pkgs = (builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux; in pkgs.callPackage ./default.nix {}'
```

Pruebas: `go test ./...`. Conformidad: `conformidad -- ./forja-mcp`.

## Configurar

`FORJA_URL` es la raíz HTTP de la forja (por defecto
`http://[b1c1:a2::1]:8090`). Los logs van a stderr.

En Claude Code:

```sh
claude mcp add forja -e FORJA_URL=http://[b1c1:a2::1]:8090 -- /ruta/a/forja-mcp
```

En Claude Desktop (`claude_desktop_config.json`):

```json
{ "mcpServers": { "forja": { "command": "/ruta/a/forja-mcp",
                             "env": { "FORJA_URL": "http://[b1c1:a2::1]:8090" } } } }
```
