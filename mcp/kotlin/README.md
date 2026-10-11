<!-- © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
     Libre para investigación; uso comercial: ver COPYRIGHT.md. -->

# forja-mcp (Kotlin/JVM)

El servidor MCP de la forja en Kotlin, según [`../CONTRATO.md`](../CONTRATO.md).
Solo el JDK: `java.net.http.HttpClient` para hablar con la forja y un JSON
propio (`src/Json.kt`), sin Gradle ni dependencias.

- `src/Json.kt`: lector y escritor de JSON.
- `src/Forja.kt`: cliente HTTP de `/forja/…` (`FORJA_URL`).
- `src/Herramientas.kt`: las cuatro fijas y una por cristal; validación.
- `src/Main.kt`: JSON-RPC por stdio, un mensaje por línea.

```sh
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --expr 'with (builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux; callPackage ./default.nix {}'
conformidad -- ./result/bin/forja-mcp
```
