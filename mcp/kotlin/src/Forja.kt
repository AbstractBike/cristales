// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

// Cliente fino de la API de introspección de la forja (`/forja/…`).

import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.time.Duration

/** Lo que contesta la forja: un estado y un cuerpo, o que no contestó. */
sealed interface Respuesta {
    data class Http(val estado: Int, val cuerpo: String) : Respuesta {
        val bien: Boolean get() = estado in 200..299
    }
    data class SinForja(val motivo: String) : Respuesta
}

class Forja(raiz: String) {
    private val raiz = raiz.trimEnd('/')
    private val espera = Duration.ofSeconds(30)
    private val cliente: HttpClient = HttpClient.newBuilder()
        .version(HttpClient.Version.HTTP_1_1)
        .connectTimeout(espera)
        .build()

    fun get(ruta: String): Respuesta = pedir(peticion(ruta).GET())

    fun post(ruta: String, cuerpo: Json): Respuesta =
        pedir(
            peticion(ruta)
                .header("content-type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(cuerpo.escribir(), StandardCharsets.UTF_8)),
        )

    private fun peticion(ruta: String): HttpRequest.Builder =
        HttpRequest.newBuilder(URI.create(raiz + ruta)).timeout(espera)

    private fun pedir(p: HttpRequest.Builder): Respuesta =
        try {
            val r = cliente.send(p.build(), HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8))
            Respuesta.Http(r.statusCode(), r.body())
        } catch (e: Exception) {
            if (e is InterruptedException) Thread.currentThread().interrupt()
            Respuesta.SinForja(e.toString())
        }
}
