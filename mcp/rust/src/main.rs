// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

//! forja-mcp: la forja como servidor MCP por stdio. Ver mcp/CONTRATO.md.
//! Una línea JSON-RPC por mensaje, en los dos sentidos; stderr es el log.

mod forja;
mod protocolo;

use std::io::{BufRead, Write};

const FORJA_POR_DEFECTO: &str = "http://[b1c1:a2::1]:8090";

fn main() {
    let url = std::env::var("FORJA_URL").unwrap_or_else(|_| FORJA_POR_DEFECTO.to_string());
    let forja = forja::ForjaHttp::new(&url);
    eprintln!("forja-mcp: sirviendo la forja de {url} por stdio");

    let stdin = std::io::stdin().lock();
    let mut stdout = std::io::stdout().lock();
    for linea in stdin.lines() {
        let linea = match linea {
            Ok(l) => l,
            Err(e) => {
                eprintln!("forja-mcp: stdin: {e}");
                break;
            }
        };
        if linea.trim().is_empty() {
            continue;
        }
        if let Some(respuesta) = protocolo::linea(&forja, &linea) {
            if writeln!(stdout, "{respuesta}").and_then(|_| stdout.flush()).is_err() {
                break;
            }
        }
    }
}
