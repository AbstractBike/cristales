<!-- © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
     Libre para investigación; uso comercial: ver COPYRIGHT.md. -->

# forja-mcp (TypeScript)

El servidor MCP de la forja en TypeScript, según [`../CONTRATO.md`](../CONTRATO.md).
Sin dependencias: solo Node ≥ 22 (`fetch`, `process.stdin`, `JSON`).

## Compilar

Con Nix (deja `bin/forja-mcp`):

```sh
nix build --impure --expr 'let pkgs = import (builtins.getFlake "nixpkgs") { config.allowUnfree = true; };
                           in pkgs.callPackage ./default.nix {}'
```

O a mano, con el `tsc` de nixpkgs:

```sh
nix shell nixpkgs#typescript nixpkgs#nodejs -c tsc -p .
node dist/forja-mcp.js
```

## Configurar

`FORJA_URL` es la raíz HTTP de la forja (por defecto `http://[b1c1:a2::1]:8090`).
En Claude Code:

```sh
claude mcp add forja -e FORJA_URL=http://[b1c1:a2::1]:8090 -- forja-mcp
```

## Comprobar

```sh
conformidad -- ./result/bin/forja-mcp
```
