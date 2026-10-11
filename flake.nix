{
  description = "cristales: pedir al LLM el método, no el resultado";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      sistemas = [ "x86_64-linux" "aarch64-linux" ];
      # El paquete es privativo (todos los derechos reservados): solo él se
      # admite como unfree.
      paraCada = f: nixpkgs.lib.genAttrs sistemas (s: f (import nixpkgs {
        system = s;
        config.allowUnfreePredicate = p: nixpkgs.lib.getName p == "cristales";
      }));
    in {
      packages = paraCada (pkgs: {
        default = pkgs.ocamlPackages.buildDunePackage {
          pname = "cristales";
          version = "0.1.0";
          src = self;
          doCheck = true;
          meta.license = pkgs.lib.licenses.unfree;
        };
      });

      devShells = paraCada (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs.ocamlPackages; [ ocaml dune_3 ocaml-lsp ];
        };
      });
    };
}
