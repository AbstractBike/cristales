# El paquete de cristales (librerías y el binario `forja`) sobre el
# ocamlPackages que le den. Lo usan el flake de este repo y, por
# overlays.default, la flota, que trae su propio ocamlPackages (con
# mirage-crypto al día).
{ lib, ocamlPackages }:

ocamlPackages.buildDunePackage {
  pname = "cristales";
  version = "0.1.0";
  src = lib.cleanSource ../.;
  propagatedBuildInputs = with ocamlPackages; [
    eio_main cohttp-eio tls-eio ca-certs mirage-crypto-rng yojson uri
  ];
  doCheck = true;
  # Sin caché de dune: en el sandbox HOME no es escribible.
  env.DUNE_CACHE = "disabled";
  meta = {
    description = "Cristalizar pipelines de IA, y la forja: proxy de LLM que cristaliza las tareas que atiende";
    # Privativo: todos los derechos reservados (COPYRIGHT.md).
    license = lib.licenses.unfree;
    mainProgram = "forja";
  };
}
