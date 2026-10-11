# © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
# Libre para investigación; uso comercial: ver COPYRIGHT.md.

# forja-mcp en Rust: pkgs.callPackage ./default.nix { }
{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "forja-mcp-rust";
  version = "0.2.0";

  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: _type: baseNameOf path != "target";
  };
  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "La forja como servidor MCP por stdio (Rust, mcp/CONTRATO.md)";
    license = lib.licenses.unfree;
    mainProgram = "forja-mcp";
  };
}
