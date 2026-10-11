#!/usr/bin/env python3
# © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
# Libre para investigación; uso comercial: ver COPYRIGHT.md.

"""forja-mcp en Python: la forja como servidor MCP por stdio (mcp/CONTRATO.md).

Solo la biblioteca estándar. Una línea JSON-RPC por mensaje, en los dos
sentidos; stderr es el log. Excepción a la regla de la flota (sin Python):
existe para quien integra la forja desde el ecosistema Python.
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request

VERSIONES = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
URL_POR_DEFECTO = "http://[b1c1:a2::1]:8090"
NOMBRE_DE_TAREA = re.compile(r"[a-z0-9-]{1,64}")
TIEMPO = 30

# Sin proxies del entorno: la forja está en la malla o en el loopback.
_http = urllib.request.build_opener(urllib.request.ProxyHandler({}))


class Invalido(Exception):
    """Argumentos que no valen: error JSON-RPC -32602."""


def log(m):
    print(f"forja-mcp: {m}", file=sys.stderr, flush=True)


# --- La forja por su API de introspección (/forja/…) ---


class Forja:
    def __init__(self, url):
        self.url = url.rstrip("/")

    def _pedir(self, metodo, ruta, cuerpo=None):
        """(estado, cuerpo); lanza OSError si la forja no responde."""
        datos = None if cuerpo is None else json.dumps(cuerpo, ensure_ascii=False).encode()
        peticion = urllib.request.Request(
            self.url + ruta, data=datos, method=metodo,
            headers={"content-type": "application/json"})
        try:
            with _http.open(peticion, timeout=TIEMPO) as r:
                return r.status, r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode("utf-8", "replace")

    def consultar(self, ruta):
        """El cuerpo si fue 2xx; si no, un error que empieza por «forja: »."""
        try:
            estado, cuerpo = self._pedir("GET", ruta)
        except OSError as e:
            return None, f"forja: {e}"
        if 200 <= estado < 300:
            return cuerpo, None
        return None, f"forja: {estado}: {cuerpo}"

    def cristales(self):
        cuerpo, error = self.consultar("/forja/vitrina")
        if error:
            log(f"sin vitrina: {error}")
            return []
        try:
            return [(c["tarea"], c.get("descripcion") or c["tarea"])
                    for c in json.loads(cuerpo)
                    if isinstance(c.get("tarea"), str) and NOMBRE_DE_TAREA.fullmatch(c["tarea"])]
        except (ValueError, TypeError, KeyError) as e:
            log(f"vitrina ilegible: {e}")
            return []

    def aplicar(self, tarea, entrada):
        """("salida"|"defecto"|"no_existe"|"fallo", texto)."""
        try:
            estado, cuerpo = self._pedir("POST", f"/forja/vitrina/{tarea}", {"entrada": entrada})
        except OSError as e:
            return "fallo", f"forja: {e}"
        if estado == 404:
            return "no_existe", ""
        if estado != 200:
            return "fallo", f"forja: {estado}: {cuerpo}"
        try:
            r = json.loads(cuerpo)
        except ValueError:
            r = None
        if isinstance(r, dict) and isinstance(r.get("salida"), str):
            return "salida", r["salida"]
        if isinstance(r, dict) and isinstance(r.get("defecto"), str):
            return "defecto", r["defecto"]
        return "fallo", f"forja: respuesta sin salida ni defecto: {cuerpo}"


# --- Herramientas ---

CADENA = {"type": "string"}


def esquema(propiedades, requeridos=()):
    e = {"type": "object", "properties": propiedades}
    if requeridos:
        e["required"] = list(requeridos)
    return e


# Nombre, descripción, esquema y ruta de la API a partir de (tarea, muestras).
FIJAS = [
    ("forja_tareas",
     "Tareas que han pasado por la forja: fase (liquida, mixta o cristalina), muestras en la "
     "cantera, contrastes, coincidencias y si ya está madura para nuclear.",
     esquema({}),
     lambda t, n: "/forja/tareas"),
    ("forja_tarea",
     "Detalle de una tarea de la forja: su informe, su plantilla (las instrucciones fijas) y "
     "sus últimas muestras de la cantera.",
     esquema({"tarea": CADENA, "muestras": {"type": "integer"}}, ["tarea"]),
     lambda t, n: f"/forja/tareas/{t}?muestras={n}"),
    ("forja_semilla",
     "SEMILLA.md de una tarea: la plantilla y las muestras de la cantera, en el formato con el "
     "que se nuclea un cristal.",
     esquema({"tarea": CADENA}, ["tarea"]),
     lambda t, n: f"/forja/tareas/{t}/semilla"),
    ("forja_nucleacion",
     "Prompt de nucleación de una tarea: lo que se le pide al LLM para que escriba el cristal "
     "(el método, no el resultado).",
     esquema({"tarea": CADENA}, ["tarea"]),
     lambda t, n: f"/forja/tareas/{t}/nucleacion"),
]


def texto(s, error=False):
    return {"content": [{"type": "text", "text": s}], "isError": error}


def nombre_de_tarea(n):
    if not isinstance(n, str) or not NOMBRE_DE_TAREA.fullmatch(n):
        raise Invalido(f"{n}: no es un nombre de tarea")
    return n


def listar(forja):
    fijas = [{"name": n, "description": d, "inputSchema": e} for n, d, e, _ in FIJAS]
    cristales = [{"name": t, "description": d,
                  "inputSchema": esquema({"entrada": CADENA}, ["entrada"])}
                 for t, d in forja.cristales()]
    return {"tools": fijas + cristales}


def llamar_fija(forja, fija, args):
    nombre, _, _, ruta = fija
    tarea = ""
    if nombre != "forja_tareas":
        if not isinstance(args.get("tarea"), str):
            raise Invalido(f"{nombre}: falta tarea (texto)")
        tarea = nombre_de_tarea(args["tarea"])
    muestras = args.get("muestras")
    if muestras is None:
        muestras = 5
    # bool es un int en Python: no vale como número de muestras.
    elif isinstance(muestras, bool) or not isinstance(muestras, int) or not 0 <= muestras <= 1000:
        raise Invalido("muestras: entero de 0 a 1000")
    cuerpo, error = forja.consultar(ruta(tarea, muestras))
    return texto(error, True) if error else texto(cuerpo)


def llamar_cristal(forja, nombre, args):
    tarea = nombre_de_tarea(nombre)
    if not isinstance(args.get("entrada"), str):
        raise Invalido(f"{tarea}: falta arguments.entrada (texto)")
    clase, s = forja.aplicar(tarea, args["entrada"])
    if clase == "salida":
        return texto(s)
    # Un defecto no es un fallo del protocolo: el modelo lo lee y decide.
    if clase == "defecto":
        return texto(f"defecto: {s}", True)
    if clase == "no_existe":
        raise Invalido(f"{tarea}: no hay tal cristal en la vitrina")
    return texto(s, True)


def llamar(forja, params):
    if not isinstance(params, dict) or not isinstance(params.get("name"), str):
        raise Invalido("falta name")
    args = params.get("arguments")
    if args is None:
        args = {}
    if not isinstance(args, dict):
        raise Invalido("arguments no es un objeto")
    nombre = params["name"]
    fija = next((f for f in FIJAS if f[0] == nombre), None)
    return llamar_fija(forja, fija, args) if fija else llamar_cristal(forja, nombre, args)


# --- JSON-RPC ---


def inicializar(params):
    pedida = params.get("protocolVersion") if isinstance(params, dict) else None
    return {
        "protocolVersion": pedida if pedida in VERSIONES else VERSIONES[0],
        "capabilities": {"tools": {}},
        "serverInfo": {"name": "forja-mcp", "version": "0.2.0"},
    }


def error(id_, codigo, mensaje):
    return {"jsonrpc": "2.0", "id": id_, "error": {"code": codigo, "message": mensaje}}


def responder(forja, linea):
    """La respuesta a una línea, o None si no lleva (notificación, línea vacía)."""
    if not linea.strip():
        return None
    try:
        msg = json.loads(linea)
    except ValueError as e:
        return error(None, -32700, str(e))
    if not isinstance(msg, dict):
        return error(None, -32600, "no es un objeto")
    id_ = msg.get("id")
    if id_ is None:
        return None
    metodo, params = msg.get("method"), msg.get("params") or {}
    if not isinstance(metodo, str):
        return error(id_, -32600, "falta method")
    try:
        if metodo == "initialize":
            resultado = inicializar(params)
        elif metodo == "ping":
            resultado = {}
        elif metodo == "tools/list":
            resultado = listar(forja)
        elif metodo == "tools/call":
            resultado = llamar(forja, params)
        else:
            return error(id_, -32601, f"{metodo}: método desconocido")
    except Invalido as e:
        return error(id_, -32602, str(e))
    return {"jsonrpc": "2.0", "id": id_, "result": resultado}


def main():
    url = os.environ.get("FORJA_URL") or URL_POR_DEFECTO
    log(f"forja en {url}")
    forja = Forja(url)
    entrada = sys.stdin.buffer
    salida = sys.stdout.buffer
    for linea in entrada:
        r = responder(forja, linea.decode("utf-8", "replace"))
        if r is not None:
            salida.write(json.dumps(r, ensure_ascii=False, separators=(",", ":")).encode() + b"\n")
            salida.flush()


if __name__ == "__main__":
    main()
