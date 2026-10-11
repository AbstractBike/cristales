{
  description = "cristales: pedir al LLM el método, no el resultado";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      sistemas = [ "x86_64-linux" "aarch64-linux" ];
      # Los forja-mcp de cada lenguaje (mcp/<lenguaje>, mcp/CONTRATO.md); el
      # de OCaml va dentro de cristales (bin/forja-mcp).
      lenguajes = [ "typescript" "go" "rust" "kotlin" "python" ];
      mcp = l: "forja-mcp-${l}";
      # Todo es privativo (COPYRIGHT.md): solo esto se admite como unfree.
      propios = [ "cristales" ] ++ map mcp lenguajes;
      paraCada = f: nixpkgs.lib.genAttrs sistemas (s: f (import nixpkgs {
        system = s;
        config.allowUnfreePredicate = p: builtins.elem (nixpkgs.lib.getName p) propios;
        overlays = [ self.overlays.default ];
      }));
    in {
      # Para quien quiera construirlo con su propio nixpkgs (la flota): el
      # paquete toma el ocamlPackages final, con los overlays de quien lo use.
      # Hay que admitir sus nombres como unfree en ese nixpkgs.
      overlays.default = final: _prev: {
        cristales = final.callPackage ./nix/paquete.nix { };
      } // nixpkgs.lib.genAttrs (map mcp lenguajes)
        (n: final.callPackage (./mcp + "/${nixpkgs.lib.removePrefix "forja-mcp-" n}/default.nix") { });

      packages = paraCada (pkgs: {
        default = pkgs.cristales;
      } // nixpkgs.lib.genAttrs (map mcp lenguajes) (n: pkgs.${n}));

      # Cada forja-mcp contra su contrato: la prueba de conformidad (una forja
      # falsa por HTTP en el loopback del sandbox) con cada implementación.
      checks = paraCada (pkgs: nixpkgs.lib.listToAttrs (map (l: {
        name = "conformidad-${l}";
        value = pkgs.runCommand "conformidad-${l}" { } ''
          ${pkgs.cristales}/bin/forja-mcp-conformidad -- ${pkgs.${mcp l}}/bin/forja-mcp
          touch $out
        '';
      }) lenguajes) // {
        conformidad-ocaml = pkgs.runCommand "conformidad-ocaml" { } ''
          ${pkgs.cristales}/bin/forja-mcp-conformidad -- ${pkgs.cristales}/bin/forja-mcp
          touch $out
        '';
      });

      devShells = paraCada (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ pkgs.cristales ];
          packages = with pkgs.ocamlPackages; [ findlib ocaml-lsp ];
        };
      });
    };
}
