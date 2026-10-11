// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

//! El cliente HTTP de la API de introspección de la forja (`/forja/…`).
//! Lo único que sabe hacer es GET y POST; qué significa cada estado lo
//! decide `protocolo`.

use std::time::Duration;

/// Lo que contesta la forja: estado HTTP y cuerpo. Un `Err` es que no
/// contestó (conexión rechazada, plazo agotado…), nunca un 4xx/5xx.
pub type Respuesta = Result<(u16, String), String>;

/// Lo que el protocolo necesita de la forja. Un rasgo, para poder probar
/// el despacho sin red.
pub trait Forja {
    fn get(&self, ruta: &str) -> Respuesta;
    fn post(&self, ruta: &str, cuerpo: &str) -> Respuesta;
}

pub struct ForjaHttp {
    raiz: String,
    agente: ureq::Agent,
}

impl ForjaHttp {
    pub fn new(raiz: &str) -> Self {
        let agente = ureq::Agent::config_builder()
            .timeout_global(Some(Duration::from_secs(30)))
            .http_status_as_error(false)
            .proxy(None)
            .build()
            .into();
        ForjaHttp { raiz: raiz.trim_end_matches('/').to_string(), agente }
    }

    fn leer(r: Result<ureq::http::Response<ureq::Body>, ureq::Error>) -> Respuesta {
        let mut r = r.map_err(|e| e.to_string())?;
        let estado = r.status().as_u16();
        let cuerpo = r.body_mut().read_to_string().map_err(|e| e.to_string())?;
        Ok((estado, cuerpo))
    }
}

impl Forja for ForjaHttp {
    fn get(&self, ruta: &str) -> Respuesta {
        Self::leer(self.agente.get(format!("{}{}", self.raiz, ruta)).call())
    }

    fn post(&self, ruta: &str, cuerpo: &str) -> Respuesta {
        Self::leer(
            self.agente
                .post(format!("{}{}", self.raiz, ruta))
                .header("content-type", "application/json")
                .send(cuerpo),
        )
    }
}
