# © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
# Libre para investigación; uso comercial: ver COPYRIGHT.md.

# forja-mcp en Python: un solo módulo, solo la biblioteca estándar.
{ lib, stdenv, python3 }:

stdenv.mkDerivation {
  pname = "forja-mcp-python";
  version = "0.2.0";
  src = lib.fileset.toSource { root = ./.; fileset = ./forja_mcp.py; };

  buildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall
    install -Dm755 forja_mcp.py $out/bin/forja-mcp
    patchShebangs $out/bin/forja-mcp
    runHook postInstall
  '';

  meta = {
    description = "Servidor MCP de la forja (Python, biblioteca estándar)";
    license = lib.licenses.unfree;
    mainProgram = "forja-mcp";
  };
}
