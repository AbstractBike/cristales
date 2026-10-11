// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

// forja-mcp: servidor MCP por stdio, JSON-RPC 2.0, un mensaje por línea.
// Ver mcp/CONTRATO.md.

import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.io.PrintWriter
import java.nio.charset.StandardCharsets

private val versiones = listOf("2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05")

class Servidor(private val herramientas: Herramientas) {

    /** La respuesta a una línea, o null si no hay que responder (notificación). */
    fun atender(linea: String): Json? {
        val mensaje = try {
            Json.leer(linea)
        } catch (e: JsonInvalido) {
            return error(Json.Nulo, -32700, "no es JSON: ${e.message}")
        }
        if (mensaje !is Json.Obj) return error(Json.Nulo, -32600, "el mensaje no es un objeto")
        val id = mensaje["id"] ?: return null
        val metodo = (mensaje["method"] as? Json.Cad)?.valor
            ?: return error(id, -32600, "falta «method»")
        val params = mensaje["params"] as? Json.Obj ?: Json.obj()
        return try {
            Json.obj("jsonrpc" to Json.Cad("2.0"), "id" to id, "result" to metodo(metodo, params))
        } catch (e: ErrorRpc) {
            error(id, e.codigo, e.message ?: "")
        } catch (e: Exception) {
            System.err.println("forja-mcp: error inesperado: $e")
            error(id, -32603, "error interno: $e")
        }
    }

    private fun metodo(metodo: String, params: Json.Obj): Json = when (metodo) {
        "initialize" -> {
            val pedida = (params["protocolVersion"] as? Json.Cad)?.valor
            Json.obj(
                "protocolVersion" to Json.Cad(if (pedida in versiones) pedida!! else versiones[0]),
                "capabilities" to Json.obj("tools" to Json.obj()),
                "serverInfo" to Json.obj("name" to Json.Cad("forja-mcp"), "version" to Json.Cad("0.2.0")),
            )
        }
        "ping" -> Json.obj()
        "tools/list" -> herramientas.lista()
        "tools/call" -> {
            val nombre = (params["name"] as? Json.Cad)?.valor
                ?: throw ErrorRpc(-32602, "falta «name»")
            val args = when (val a = params["arguments"]) {
                null, Json.Nulo -> Json.obj()
                is Json.Obj -> a
                else -> throw ErrorRpc(-32602, "«arguments» no es un objeto")
            }
            herramientas.llamar(nombre, args)
        }
        else -> throw ErrorRpc(-32601, "método desconocido: $metodo")
    }

    private fun error(id: Json, codigo: Int, mensaje: String): Json = Json.obj(
        "jsonrpc" to Json.Cad("2.0"),
        "id" to id,
        "error" to Json.obj("code" to Json.num(codigo), "message" to Json.Cad(mensaje)),
    )
}

fun main() {
    val url = System.getenv("FORJA_URL")?.takeIf { it.isNotBlank() } ?: "http://[b1c1:a2::1]:8090"
    System.err.println("forja-mcp: forja en $url")
    val servidor = Servidor(Herramientas(Forja(url)))
    val entrada = BufferedReader(InputStreamReader(System.`in`, StandardCharsets.UTF_8))
    val salida = PrintWriter(OutputStreamWriter(System.out, StandardCharsets.UTF_8), false)
    while (true) {
        val linea = entrada.readLine() ?: break
        if (linea.isBlank()) continue
        val respuesta = servidor.atender(linea)
        if (respuesta != null) {
            salida.write(respuesta.escribir())
            salida.write("\n")
            salida.flush()
        }
    }
}
