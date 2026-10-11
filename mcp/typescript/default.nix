# © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
# Libre para investigación; uso comercial: ver COPYRIGHT.md.

# forja-mcp en TypeScript: se compila con tsc y corre en node, sin dependencias.
{ lib, stdenv, nodejs, typescript, makeWrapper }:

stdenv.mkDerivation {
  pname = "forja-mcp-typescript";
  version = "0.2.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./src ./tsconfig.json ./package.json ];
  };

  nativeBuildInputs = [ typescript makeWrapper ];

  buildPhase = ''
    runHook preBuild
    tsc -p .
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/forja-mcp $out/bin
    cp -r dist package.json $out/lib/forja-mcp/
    makeWrapper ${lib.getExe nodejs} $out/bin/forja-mcp \
      --add-flags $out/lib/forja-mcp/dist/forja-mcp.js
    runHook postInstall
  '';

  meta = {
    description = "Servidor MCP de la forja de cristales (TypeScript)";
    license = lib.licenses.unfree;
    mainProgram = "forja-mcp";
  };
}
