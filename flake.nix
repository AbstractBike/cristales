{
  description = "cristales: pedir al LLM el método, no el resultado";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      sistemas = [ "x86_64-linux" "aarch64-linux" ];
      paraCada = f: nixpkgs.lib.genAttrs sistemas (s: f nixpkgs.legacyPackages.${s});
    in {
      packages = paraCada (pkgs: {
        default = pkgs.ocamlPackages.buildDunePackage {
          pname = "cristales";
          version = "0.1.0";
          src = self;
          doCheck = true;
        };
      });

      devShells = paraCada (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs.ocamlPackages; [ ocaml dune_3 ocaml-lsp ];
        };
      });
    };
}
