# forja-mcp en Python

La forja como servidor MCP por stdio, según [`../CONTRATO.md`](../CONTRATO.md).
Un solo módulo, [`forja_mcp.py`](forja_mcp.py), con la biblioteca estándar
(`json`, `urllib`, `re`): sin dependencias. Es una excepción a la regla de la
flota (nada en Python), para quien integra la forja desde ese ecosistema.

```bash
nix build .#forja-mcp-python
```

```bash
claude mcp add forja -e FORJA_URL=http://[b1c1:a2::1]:8090 -- ./result/bin/forja-mcp
```

Sin Nix basta con Python ≥ 3.9: `python3 forja_mcp.py`.

La conformidad con el contrato la comprueba `nix flake check`
(`checks.conformidad-python`), o a mano:

```bash
forja-mcp-conformidad -- ./result/bin/forja-mcp
```
