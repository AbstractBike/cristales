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
      # Lo que necesita la forja (proxy HTTP con Eio).
      dependencias = o: with o; [
        eio_main cohttp-eio tls-eio ca-certs mirage-crypto-rng yojson uri
      ];
    in {
      packages = paraCada (pkgs: {
        default = pkgs.ocamlPackages.buildDunePackage {
          pname = "cristales";
          version = "0.1.0";
          src = self;
          propagatedBuildInputs = dependencias pkgs.ocamlPackages;
          doCheck = true;
          meta = {
            license = pkgs.lib.licenses.unfree;
            mainProgram = "forja";
          };
        };
      });

      devShells = paraCada (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs.ocamlPackages;
            [ ocaml dune_3 findlib ocaml-lsp ] ++ dependencias pkgs.ocamlPackages;
        };
      });
    };
}
