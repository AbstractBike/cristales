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
        overlays = [ self.overlays.default ];
      }));
    in {
      # Para quien quiera construirlo con su propio nixpkgs (la flota): el
      # paquete toma el ocamlPackages final, con los overlays de quien lo use.
      # Hay que admitir "cristales" como unfree en ese nixpkgs.
      overlays.default = final: _prev: {
        cristales = final.callPackage ./nix/paquete.nix { };
      };

      packages = paraCada (pkgs: { default = pkgs.cristales; });

      devShells = paraCada (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ pkgs.cristales ];
          packages = with pkgs.ocamlPackages; [ findlib ocaml-lsp ];
        };
      });
    };
}
