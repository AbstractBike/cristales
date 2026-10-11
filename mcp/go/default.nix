# © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
# Libre para investigación; uso comercial: ver COPYRIGHT.md.

# forja-mcp en Go: solo biblioteca estándar, sin dependencias que vendorizar.
{ lib, buildGoModule }:

buildGoModule {
  pname = "forja-mcp-go";
  version = "0.2.0";
  src = ./.;
  vendorHash = null;

  postInstall = ''
    mv $out/bin/go $out/bin/forja-mcp
  '';

  meta = {
    description = "Servidor MCP de la forja (Go, biblioteca estándar)";
    license = lib.licenses.unfree;
    mainProgram = "forja-mcp";
  };
}
