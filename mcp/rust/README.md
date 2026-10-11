<!-- © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
     Libre para investigación; uso comercial: ver COPYRIGHT.md. -->

# forja-mcp (Rust)

El servidor MCP de la forja, en Rust: cumple [`../CONTRATO.md`](../CONTRATO.md).
Es un cliente fino de la API `/forja/…` del proxy; no reimplementa nada.

- `src/main.rs`: el bucle de stdio, una línea JSON-RPC por mensaje.
- `src/protocolo.rs`: métodos, herramientas, validación y resultados.
- `src/forja.rs`: el cliente HTTP (`ureq`, sin TLS, 30 s de plazo).

Dependencias: `serde_json` y `ureq`. Sin runtime asíncrono ni SDK de MCP.

## Construir y comprobar

```sh
nix build --impure --expr \
  'let pkgs = (builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux;
   in pkgs.callPackage ./default.nix {}'
conformidad -- ./result/bin/forja-mcp
cargo test        # pruebas del despacho y la validación
```

## Usarlo

```sh
claude mcp add forja -e FORJA_URL=http://[b1c1:a2::1]:8090 -- forja-mcp
```

`FORJA_URL` por defecto: `http://[b1c1:a2::1]:8090`. Los logs, por stderr.
