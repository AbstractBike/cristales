// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

//! El protocolo: de una línea JSON-RPC a, como mucho, una línea de
//! respuesta. Todo lo que hace falta de la forja pasa por el rasgo `Forja`.

use crate::forja::Forja;
use serde_json::{Map, Value, json};

const VERSIONES: [&str; 4] = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"];

const PARSE: i64 = -32700;
const PETICION: i64 = -32600;
const METODO: i64 = -32601;
const PARAMETROS: i64 = -32602;

/// Un error JSON-RPC: código y mensaje.
type Fallo = (i64, String);

fn fallo(codigo: i64, mensaje: impl Into<String>) -> Fallo {
    (codigo, mensaje.into())
}

/// `^[a-z0-9-]{1,64}$`: un nombre de tarea de la forja.
pub fn es_tarea(s: &str) -> bool {
    (1..=64).contains(&s.len())
        && s.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
}

/// Atiende una línea. `None` si no hay que contestar (una notificación).
pub fn linea(forja: &dyn Forja, linea: &str) -> Option<String> {
    let respuesta = match serde_json::from_str::<Value>(linea) {
        Err(_) => error(Value::Null, fallo(PARSE, "la línea no es JSON")),
        Ok(Value::Object(msg)) => {
            let id = msg.get("id")?.clone();
            match msg.get("method").and_then(Value::as_str) {
                None => error(id, fallo(PETICION, "falta method")),
                Some(metodo) => {
                    let params = msg.get("params").cloned().unwrap_or(Value::Null);
                    match despachar(forja, metodo, &params) {
                        Ok(r) => json!({"jsonrpc": "2.0", "id": id, "result": r}),
                        Err(f) => error(id, f),
                    }
                }
            }
        }
        Ok(_) => error(Value::Null, fallo(PETICION, "el mensaje no es un objeto")),
    };
    Some(respuesta.to_string())
}

fn error(id: Value, (code, message): Fallo) -> Value {
    json!({"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}})
}

fn despachar(forja: &dyn Forja, metodo: &str, params: &Value) -> Result<Value, Fallo> {
    match metodo {
        "initialize" => Ok(inicializar(params)),
        "ping" => Ok(json!({})),
        "tools/list" => Ok(json!({"tools": herramientas(forja)})),
        "tools/call" => llamar(forja, params),
        _ => Err(fallo(METODO, format!("método desconocido: {metodo}"))),
    }
}

fn inicializar(params: &Value) -> Value {
    let pedida = params.get("protocolVersion").and_then(Value::as_str);
    let version = VERSIONES.iter().copied().find(|v| Some(*v) == pedida).unwrap_or(VERSIONES[0]);
    json!({
        "protocolVersion": version,
        "capabilities": {"tools": {}},
        "serverInfo": {"name": "forja-mcp", "version": env!("CARGO_PKG_VERSION")},
    })
}

// {1 Herramientas}

fn herramienta(nombre: &str, descripcion: &str, propiedades: Value, obligatorios: &[&str]) -> Value {
    let mut esquema = json!({"type": "object", "properties": propiedades});
    if !obligatorios.is_empty() {
        esquema["required"] = json!(obligatorios);
    }
    json!({"name": nombre, "description": descripcion, "inputSchema": esquema})
}

fn prop_tarea() -> Value {
    json!({"type": "string", "pattern": "^[a-z0-9-]{1,64}$", "description": "Nombre de la tarea."})
}

fn fijas() -> Vec<Value> {
    vec![
        herramienta(
            "forja_tareas",
            "Tareas que han pasado por la forja: fase (liquida, mixta o cristalina), muestras en la cantera, contrastes, coincidencias y si ya está madura para nuclear.",
            json!({}),
            &[],
        ),
        herramienta(
            "forja_tarea",
            "Detalle de una tarea de la forja: su informe, su plantilla (las instrucciones fijas) y sus últimas muestras de la cantera.",
            json!({
                "tarea": prop_tarea(),
                "muestras": {"type": "integer", "minimum": 0, "maximum": 1000, "default": 5,
                             "description": "Cuántas muestras recientes incluir."},
            }),
            &["tarea"],
        ),
        herramienta(
            "forja_semilla",
            "SEMILLA.md de una tarea: la plantilla y las muestras de la cantera, en el formato con el que se nuclea un cristal.",
            json!({"tarea": prop_tarea()}),
            &["tarea"],
        ),
        herramienta(
            "forja_nucleacion",
            "Prompt de nucleación de una tarea: lo que se le pide al LLM para que escriba el cristal (el método, no el resultado).",
            json!({"tarea": prop_tarea()}),
            &["tarea"],
        ),
    ]
}

/// Las fijas y, detrás, una por cristal de la vitrina, en su orden. Si la
/// forja no responde (o responde algo raro), solo las fijas.
fn herramientas(forja: &dyn Forja) -> Vec<Value> {
    let mut todas = fijas();
    match vitrina(forja) {
        Ok(cristales) => todas.extend(cristales),
        Err(e) => eprintln!("forja-mcp: sin vitrina: {e}"),
    }
    todas
}

fn vitrina(forja: &dyn Forja) -> Result<Vec<Value>, String> {
    let (estado, cuerpo) = forja.get("/forja/vitrina")?;
    if !(200..300).contains(&estado) {
        return Err(format!("GET /forja/vitrina → {estado}"));
    }
    let lista: Vec<Value> = serde_json::from_str(&cuerpo).map_err(|e| e.to_string())?;
    Ok(lista
        .iter()
        .filter_map(|c| {
            let tarea = c.get("tarea")?.as_str().filter(|t| es_tarea(t))?;
            let descripcion = c.get("descripcion").and_then(Value::as_str).unwrap_or(tarea);
            Some(herramienta(
                tarea,
                descripcion,
                json!({"entrada": {"type": "string", "description": "La entrada del cristal."}}),
                &["entrada"],
            ))
        })
        .collect())
}

// {1 Llamadas}

fn llamar(forja: &dyn Forja, params: &Value) -> Result<Value, Fallo> {
    let nombre = params
        .get("name")
        .and_then(Value::as_str)
        .ok_or_else(|| fallo(PARAMETROS, "falta name"))?;
    let vacio = Map::new();
    let args = match params.get("arguments") {
        None | Some(Value::Null) => &vacio,
        Some(Value::Object(a)) => a,
        Some(_) => return Err(fallo(PARAMETROS, "arguments no es un objeto")),
    };
    match nombre {
        "forja_tareas" => Ok(fija(forja.get("/forja/tareas"))),
        "forja_tarea" => {
            let tarea = arg_tarea(args, "tarea")?;
            let muestras = arg_muestras(args)?;
            Ok(fija(forja.get(&format!("/forja/tareas/{tarea}?muestras={muestras}"))))
        }
        "forja_semilla" => {
            let tarea = arg_tarea(args, "tarea")?;
            Ok(fija(forja.get(&format!("/forja/tareas/{tarea}/semilla"))))
        }
        "forja_nucleacion" => {
            let tarea = arg_tarea(args, "tarea")?;
            Ok(fija(forja.get(&format!("/forja/tareas/{tarea}/nucleacion"))))
        }
        tarea if es_tarea(tarea) => {
            let entrada = args
                .get("entrada")
                .and_then(Value::as_str)
                .ok_or_else(|| fallo(PARAMETROS, "entrada: obligatoria, string"))?;
            let cuerpo = json!({"entrada": entrada}).to_string();
            cristal(tarea, forja.post(&format!("/forja/vitrina/{tarea}"), &cuerpo))
        }
        _ => Err(fallo(PARAMETROS, format!("herramienta desconocida: {nombre}"))),
    }
}

fn arg_tarea<'a>(args: &'a Map<String, Value>, clave: &str) -> Result<&'a str, Fallo> {
    match args.get(clave).and_then(Value::as_str) {
        Some(t) if es_tarea(t) => Ok(t),
        Some(_) => Err(fallo(PARAMETROS, format!("{clave}: tiene que cumplir ^[a-z0-9-]{{1,64}}$"))),
        None => Err(fallo(PARAMETROS, format!("{clave}: obligatoria, string"))),
    }
}

fn arg_muestras(args: &Map<String, Value>) -> Result<i64, Fallo> {
    match args.get("muestras") {
        None | Some(Value::Null) => Ok(5),
        Some(v) => v
            .as_i64()
            .filter(|n| (0..=1000).contains(n))
            .ok_or_else(|| fallo(PARAMETROS, "muestras: entero entre 0 y 1000")),
    }
}

fn texto(text: &str, es_error: bool) -> Value {
    json!({"content": [{"type": "text", "text": text}], "isError": es_error})
}

/// Herramienta fija: 2xx, el cuerpo tal cual; si no, `forja: …`.
fn fija(r: crate::forja::Respuesta) -> Value {
    match r {
        Ok((estado, cuerpo)) if (200..300).contains(&estado) => texto(&cuerpo, false),
        Ok((estado, cuerpo)) => texto(&format!("forja: {estado} {cuerpo}"), true),
        Err(e) => texto(&format!("forja: {e}"), true),
    }
}

/// Cristal: salida, defecto, 404 (no hay tal cristal) u otra cosa.
fn cristal(tarea: &str, r: crate::forja::Respuesta) -> Result<Value, Fallo> {
    match r {
        Ok((200, cuerpo)) => {
            let v: Value = serde_json::from_str(&cuerpo).unwrap_or(Value::Null);
            Ok(match (v.get("salida").and_then(Value::as_str), v.get("defecto").and_then(Value::as_str)) {
                (Some(s), _) => texto(s, false),
                (None, Some(m)) => texto(&format!("defecto: {m}"), true),
                _ => texto(&format!("forja: respuesta inesperada: {cuerpo}"), true),
            })
        }
        Ok((404, _)) => Err(fallo(PARAMETROS, format!("no hay cristal {tarea} en la vitrina"))),
        Ok((estado, cuerpo)) => Ok(texto(&format!("forja: {estado} {cuerpo}"), true)),
        Err(e) => Ok(texto(&format!("forja: {e}"), true)),
    }
}

#[cfg(test)]
mod pruebas {
    use super::*;
    use crate::forja::Respuesta;
    use std::cell::RefCell;

    /// Una forja de mentira que apunta las rutas que le piden.
    struct Falsa {
        rutas: RefCell<Vec<String>>,
    }

    impl Forja for Falsa {
        fn get(&self, ruta: &str) -> Respuesta {
            self.rutas.borrow_mut().push(ruta.to_string());
            match ruta {
                "/forja/vitrina" => Ok((200, r#"[{"tarea":"mayus","descripcion":"M."},{"tarea":"Mal/../x"}]"#.into())),
                _ => Ok((404, "{}".into())),
            }
        }
        fn post(&self, ruta: &str, _: &str) -> Respuesta {
            match ruta {
                "/forja/vitrina/mayus" => Ok((200, r#"{"defecto":"d"}"#.into())),
                _ => Ok((404, "{}".into())),
            }
        }
    }

    fn falsa() -> Falsa {
        Falsa { rutas: RefCell::new(vec![]) }
    }

    fn pedir(f: &Falsa, l: &str) -> Value {
        serde_json::from_str(&linea(f, l).expect("respuesta")).unwrap()
    }

    fn codigo(v: &Value) -> i64 {
        v["error"]["code"].as_i64().unwrap_or(0)
    }

    #[test]
    fn patron_de_tarea() {
        assert!(es_tarea("t-712d41d0978b"));
        assert!(es_tarea(&"a".repeat(64)));
        for mal in ["", "Mayus", "../x", "a_b", &"a".repeat(65)] {
            assert!(!es_tarea(mal), "{mal}");
        }
    }

    #[test]
    fn errores_jsonrpc() {
        let f = falsa();
        let r = pedir(&f, "no es json");
        assert_eq!((codigo(&r), r["id"].clone()), (PARSE, Value::Null));
        assert_eq!(codigo(&pedir(&f, "[1]")), PETICION);
        assert_eq!(codigo(&pedir(&f, r#"{"id":1}"#)), PETICION);
        assert_eq!(codigo(&pedir(&f, r#"{"id":1,"method":"x"}"#)), METODO);
        assert!(linea(&f, r#"{"method":"notifications/initialized"}"#).is_none());
    }

    #[test]
    fn id_tal_cual() {
        let f = falsa();
        assert_eq!(pedir(&f, r#"{"id":"abc","method":"ping"}"#)["id"], "abc");
        assert_eq!(pedir(&f, r#"{"id":1.5,"method":"ping"}"#)["id"], 1.5);
    }

    #[test]
    fn lista_salta_nombres_que_no_son_de_tarea() {
        let f = falsa();
        let r = pedir(&f, r#"{"id":1,"method":"tools/list"}"#);
        let nombres: Vec<&str> =
            r["result"]["tools"].as_array().unwrap().iter().map(|t| t["name"].as_str().unwrap()).collect();
        assert_eq!(nombres, ["forja_tareas", "forja_tarea", "forja_semilla", "forja_nucleacion", "mayus"]);
    }

    #[test]
    fn validacion_de_argumentos() {
        let f = falsa();
        let llama = |args: &str| {
            codigo(&pedir(&f, &format!(
                r#"{{"id":1,"method":"tools/call","params":{{"name":"forja_tarea","arguments":{args}}}}}"#
            )))
        };
        assert_eq!(llama(r#"{}"#), PARAMETROS);
        assert_eq!(llama(r#"{"tarea":"x","muestras":1001}"#), PARAMETROS);
        assert_eq!(llama(r#"{"tarea":"x","muestras":2.5}"#), PARAMETROS);
        assert_eq!(llama(r#"{"tarea":"x"}"#), 0);
        assert_eq!(f.rutas.borrow().last().unwrap(), "/forja/tareas/x?muestras=5");
    }

    #[test]
    fn cristales() {
        let f = falsa();
        let r = pedir(&f, r#"{"id":1,"method":"tools/call","params":{"name":"mayus","arguments":{"entrada":"a"}}}"#);
        assert_eq!(r["result"], texto("defecto: d", true));
        let r = pedir(&f, r#"{"id":1,"method":"tools/call","params":{"name":"otro","arguments":{"entrada":"a"}}}"#);
        assert_eq!(codigo(&r), PARAMETROS);
    }
}
