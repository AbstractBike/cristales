// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

// Lo poco de Node que se usa, sin @types/node (no hay npm en la compilación).
// fetch, AbortSignal y TextDecoder vienen de la lib DOM.

interface FlujoDeEntrada extends AsyncIterable<Uint8Array> {}

interface FlujoDeSalida {
  write(datos: string): boolean;
}

declare const process: {
  readonly stdin: FlujoDeEntrada;
  readonly stdout: FlujoDeSalida;
  readonly stderr: FlujoDeSalida;
  readonly env: Record<string, string | undefined>;
};
