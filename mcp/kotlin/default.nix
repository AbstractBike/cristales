# © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
# Libre para investigación; uso comercial: ver COPYRIGHT.md.

# forja-mcp en Kotlin/JVM: solo el JDK, sin Gradle ni dependencias.
{ lib, stdenv, kotlin, jdk, makeWrapper }:

stdenv.mkDerivation {
  pname = "forja-mcp-kotlin";
  version = "0.2.0";
  src = ./.;

  nativeBuildInputs = [ kotlin makeWrapper ];

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    kotlinc src/*.kt -include-runtime -jvm-target 17 -d forja-mcp.jar
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 forja-mcp.jar $out/share/forja-mcp/forja-mcp.jar
    makeWrapper ${jdk}/bin/java $out/bin/forja-mcp \
      --add-flags "-XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Xshare:auto" \
      --add-flags "-jar $out/share/forja-mcp/forja-mcp.jar"
    runHook postInstall
  '';

  meta = {
    description = "Servidor MCP de la forja (Kotlin/JVM)";
    license = lib.licenses.unfree;
    mainProgram = "forja-mcp";
  };
}
