#!/usr/bin/env node
// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

// forja-mcp en TypeScript: servidor MCP por stdio, cliente fino de la API de
// introspección de la forja. El contrato está en mcp/CONTRATO.md.

type Json = null | boolean | number | string | Json[] | { [k: string]: Json };
type Objeto = { [k: string]: Json };

const VERSIONES = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"];
const FORJA = (process.env["FORJA_URL"] || "http://[b1c1:a2::1]:8090").replace(/\/+$/, "");
const PLAZO_MS = 30_000;
const PATRON_TAREA = /^[a-z0-9-]{1,64}$/;

const log = (m: string): void => void process.stderr.write(`forja-mcp: ${m}\n`);
const esObjeto = (j: unknown): j is Objeto => typeof j === "object" && j !== null && !Array.isArray(j);

// Un error que acaba como respuesta de error JSON-RPC.
class ErrorRpc extends Error {
  constructor(readonly code: number, message: string) {
    super(message);
  }
}
const argumentoMalo = (m: string): ErrorRpc => new ErrorRpc(-32602, m);

// {1 La forja por HTTP}

type Respuesta = { estado: number; texto: string };

// Lanza si la forja no responde; el estado HTTP lo decide quien llama.
async function forja(ruta: string, cuerpo?: Json): Promise<Respuesta> {
  const r = await fetch(FORJA + ruta, {
    method: cuerpo === undefined ? "GET" : "POST",
    headers: cuerpo === undefined ? {} : { "content-type": "application/json" },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
    signal: AbortSignal.timeout(PLAZO_MS),
  });
  return { estado: r.status, texto: await r.text() };
}

const motivo = (e: unknown): string =>
  e instanceof Error ? (e.cause instanceof Error ? `${e.message}: ${e.cause.message}` : e.message) : String(e);

// {1 Resultados de herramienta}

const resultado = (text: string, isError: boolean): Objeto => ({ content: [{ type: "text", text }], isError });

// {1 Validación de argumentos}

function tarea(args: Objeto, campo = "tarea"): string {
  const v = args[campo];
  if (typeof v !== "string") throw argumentoMalo(`falta ${campo} (string)`);
  if (!PATRON_TAREA.test(v)) throw argumentoMalo(`${campo} no cumple ^[a-z0-9-]{1,64}$`);
  return v;
}

function muestras(args: Objeto): number {
  const v = args["muestras"];
  if (v === undefined) return 5;
  if (typeof v !== "number" || !Number.isInteger(v) || v < 0 || v > 1000)
    throw argumentoMalo("muestras tiene que ser un entero entre 0 y 1000");
  return v;
}

// {1 Herramientas fijas}

type Fija = { name: string; description: string; inputSchema: Objeto; ruta: (args: Objeto) => string };

const esquemaTarea = { type: "string", description: "Nombre de la tarea en la forja." };
const soloTarea: Objeto = { type: "object", properties: { tarea: esquemaTarea }, required: ["tarea"] };

const FIJAS: Fija[] = [
  {
    name: "forja_tareas",
    description:
      "Tareas que han pasado por la forja: fase (liquida, mixta o cristalina), muestras en la cantera, contrastes, coincidencias y si ya está madura para nuclear.",
    inputSchema: { type: "object", properties: {} },
    ruta: () => "/forja/tareas",
  },
  {
    name: "forja_tarea",
    description:
      "Detalle de una tarea de la forja: su informe, su plantilla (las instrucciones fijas) y sus últimas muestras de la cantera.",
    inputSchema: {
      type: "object",
      properties: {
        tarea: esquemaTarea,
        muestras: { type: "integer", description: "Cuántas muestras recientes (5 por defecto).", minimum: 0, maximum: 1000 },
      },
      required: ["tarea"],
    },
    ruta: (a) => `/forja/tareas/${tarea(a)}?muestras=${muestras(a)}`,
  },
  {
    name: "forja_semilla",
    description:
      "SEMILLA.md de una tarea: la plantilla y las muestras de la cantera, en el formato con el que se nuclea un cristal.",
    inputSchema: soloTarea,
    ruta: (a) => `/forja/tareas/${tarea(a)}/semilla`,
  },
  {
    name: "forja_nucleacion",
    description:
      "Prompt de nucleación de una tarea: lo que se le pide al LLM para que escriba el cristal (el método, no el resultado).",
    inputSchema: soloTarea,
    ruta: (a) => `/forja/tareas/${tarea(a)}/nucleacion`,
  },
];

async function llamarFija(f: Fija, args: Objeto): Promise<Objeto> {
  const ruta = f.ruta(args); // valida antes de salir a la red
  try {
    const r = await forja(ruta);
    if (r.estado >= 200 && r.estado < 300) return resultado(r.texto, false);
    return resultado(`forja: ${r.estado}: ${r.texto}`, true);
  } catch (e) {
    return resultado(`forja: ${motivo(e)}`, true);
  }
}

// {1 Cristales de la vitrina}

async function cristales(): Promise<Objeto[]> {
  try {
    const r = await forja("/forja/vitrina");
    if (r.estado !== 200) throw new Error(`vitrina: ${r.estado}`);
    const lista: unknown = JSON.parse(r.texto);
    if (!Array.isArray(lista)) throw new Error("vitrina: no es una lista");
    return lista.filter(esObjeto).flatMap((c) =>
      typeof c["tarea"] === "string"
        ? [
            {
              name: c["tarea"],
              description: typeof c["descripcion"] === "string" ? c["descripcion"] : c["tarea"],
              inputSchema: {
                type: "object",
                properties: { entrada: { type: "string", description: "Entrada del cristal." } },
                required: ["entrada"],
              },
            },
          ]
        : [],
    );
  } catch (e) {
    log(`sin vitrina (${motivo(e)}); solo las herramientas fijas`);
    return [];
  }
}

async function llamarCristal(nombre: string, args: Objeto): Promise<Objeto> {
  if (!PATRON_TAREA.test(nombre)) throw argumentoMalo(`herramienta desconocida: ${nombre}`);
  const entrada = args["entrada"];
  if (typeof entrada !== "string") throw argumentoMalo("falta entrada (string)");
  let r: Respuesta;
  try {
    r = await forja(`/forja/vitrina/${nombre}`, { entrada });
  } catch (e) {
    return resultado(`forja: ${motivo(e)}`, true);
  }
  if (r.estado === 404) throw argumentoMalo(`no hay tal cristal: ${nombre}`);
  if (r.estado !== 200) return resultado(`forja: ${r.estado}: ${r.texto}`, true);
  let j: unknown;
  try {
    j = JSON.parse(r.texto);
  } catch {
    return resultado(`forja: respuesta que no es JSON: ${r.texto}`, true);
  }
  if (esObjeto(j) && typeof j["salida"] === "string") return resultado(j["salida"], false);
  if (esObjeto(j) && typeof j["defecto"] === "string") return resultado(`defecto: ${j["defecto"]}`, true);
  return resultado(`forja: respuesta inesperada: ${r.texto}`, true);
}

// {1 Métodos}

async function toolsCall(params: Objeto): Promise<Objeto> {
  const nombre = params["name"];
  const args = params["arguments"] ?? {};
  if (typeof nombre !== "string") throw argumentoMalo("falta name");
  if (!esObjeto(args)) throw argumentoMalo("arguments tiene que ser un objeto");
  const fija = FIJAS.find((f) => f.name === nombre);
  return fija ? llamarFija(fija, args) : llamarCristal(nombre, args);
}

async function atender(metodo: string, params: Objeto): Promise<Objeto> {
  switch (metodo) {
    case "initialize": {
      const pedida = params["protocolVersion"];
      return {
        protocolVersion: typeof pedida === "string" && VERSIONES.includes(pedida) ? pedida : VERSIONES[0]!,
        capabilities: { tools: {} },
        serverInfo: { name: "forja-mcp", version: "0.2.0" },
      };
    }
    case "ping":
      return {};
    case "tools/list":
      return { tools: [...FIJAS.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })), ...(await cristales())] };
    case "tools/call":
      return toolsCall(params);
    default:
      throw new ErrorRpc(-32601, `método desconocido: ${metodo}`);
  }
}

// {1 JSON-RPC por líneas}

const enviar = (m: Objeto): void => void process.stdout.write(JSON.stringify(m) + "\n");
const fallo = (id: Json, code: number, message: string): void => enviar({ jsonrpc: "2.0", id, error: { code, message } });

async function linea(texto: string): Promise<void> {
  if (texto.trim() === "") return;
  let m: unknown;
  try {
    m = JSON.parse(texto);
  } catch {
    return fallo(null, -32700, "la línea no es JSON");
  }
  if (!esObjeto(m)) return fallo(null, -32600, "el mensaje no es un objeto");
  const tieneId = "id" in m;
  const id: Json = m["id"] ?? null;
  if (typeof m["method"] !== "string") return tieneId ? fallo(id, -32600, "falta method") : undefined;
  const params = esObjeto(m["params"]) ? m["params"] : {};
  if (!tieneId) return; // notificación: no se contesta
  try {
    enviar({ jsonrpc: "2.0", id, result: await atender(m["method"], params) });
  } catch (e) {
    if (e instanceof ErrorRpc) fallo(id, e.code, e.message);
    else {
      log(`error interno: ${motivo(e)}`);
      fallo(id, -32603, motivo(e));
    }
  }
}

// Un mensaje detrás de otro, en orden; al cerrarse stdin se termina.
async function main(): Promise<void> {
  log(`forja en ${FORJA}`);
  const decodificador = new TextDecoder();
  let resto = "";
  for await (const trozo of process.stdin) {
    resto += decodificador.decode(trozo, { stream: true });
    let i: number;
    while ((i = resto.indexOf("\n")) >= 0) {
      const l = resto.slice(0, i);
      resto = resto.slice(i + 1);
      await linea(l);
    }
  }
  await linea(resto + decodificador.decode());
}

void main();
