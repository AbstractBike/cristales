// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

// Las herramientas: cuatro fijas y una por cristal de la vitrina.

/** Un error JSON-RPC: lo que acaba en `{error: {code, message}}`. */
class ErrorRpc(val codigo: Int, mensaje: String) : Exception(mensaje)

private val patronTarea = Regex("^[a-z0-9-]{1,64}$")
private val patronEntero = Regex("^-?[0-9]+$")

private fun log(m: String) = System.err.println("forja-mcp: $m")

private fun propiedad(tipo: String, descripcion: String) =
    Json.obj("type" to Json.Cad(tipo), "description" to Json.Cad(descripcion))

private fun herramienta(nombre: String, descripcion: String, propiedades: Json.Obj, requeridos: List<String>): Json {
    val esquema = linkedMapOf<String, Json>("type" to Json.Cad("object"), "properties" to propiedades)
    if (requeridos.isNotEmpty()) esquema["required"] = Json.Lista(requeridos.map { Json.Cad(it) })
    return Json.obj(
        "name" to Json.Cad(nombre),
        "description" to Json.Cad(descripcion),
        "inputSchema" to Json.Obj(esquema),
    )
}

private val propTarea = "tarea" to propiedad("string", "Nombre de la tarea en la forja.")

private val fijas: List<Json> = listOf(
    herramienta(
        "forja_tareas",
        "Tareas que han pasado por la forja: fase (liquida, mixta o cristalina), muestras en la cantera, contrastes, coincidencias y si ya está madura para nuclear.",
        Json.obj(), emptyList(),
    ),
    herramienta(
        "forja_tarea",
        "Detalle de una tarea de la forja: su informe, su plantilla (las instrucciones fijas) y sus últimas muestras de la cantera.",
        Json.obj(propTarea, "muestras" to propiedad("integer", "Cuántas muestras recientes traer (0–1000, 5 por defecto).")),
        listOf("tarea"),
    ),
    herramienta(
        "forja_semilla",
        "SEMILLA.md de una tarea: la plantilla y las muestras de la cantera, en el formato con el que se nuclea un cristal.",
        Json.obj(propTarea), listOf("tarea"),
    ),
    herramienta(
        "forja_nucleacion",
        "Prompt de nucleación de una tarea: lo que se le pide al LLM para que escriba el cristal (el método, no el resultado).",
        Json.obj(propTarea), listOf("tarea"),
    ),
)

class Herramientas(private val forja: Forja) {

    /** Las fijas y luego los cristales de la vitrina; sin forja, solo las fijas. */
    fun lista(): Json = Json.obj("tools" to Json.Lista(fijas + cristales()))

    private fun cristales(): List<Json> {
        val r = forja.get("/forja/vitrina")
        if (r !is Respuesta.Http || !r.bien) {
            log("vitrina: ${describir(r)}")
            return emptyList()
        }
        return try {
            (Json.leer(r.cuerpo) as Json.Lista).elementos.mapNotNull { c ->
                val nombre = ((c as Json.Obj)["tarea"] as? Json.Cad)?.valor
                if (nombre == null || !patronTarea.matches(nombre)) null
                else herramienta(
                    nombre,
                    (c["descripcion"] as? Json.Cad)?.valor ?: "Cristal $nombre de la vitrina.",
                    Json.obj("entrada" to propiedad("string", "La entrada del cristal.")),
                    listOf("entrada"),
                )
            }
        } catch (e: Exception) {
            log("vitrina ilegible: $e")
            emptyList()
        }
    }

    fun llamar(nombre: String, args: Json.Obj): Json = when (nombre) {
        "forja_tareas" -> fija(forja.get("/forja/tareas"))
        "forja_tarea" -> {
            val tarea = tarea(args)
            fija(forja.get("/forja/tareas/$tarea?muestras=${muestras(args)}"))
        }
        "forja_semilla" -> fija(forja.get("/forja/tareas/${tarea(args)}/semilla"))
        "forja_nucleacion" -> fija(forja.get("/forja/tareas/${tarea(args)}/nucleacion"))
        else -> cristal(nombre, args)
    }

    private fun cristal(nombre: String, args: Json.Obj): Json {
        if (!patronTarea.matches(nombre)) throw ErrorRpc(-32602, "herramienta desconocida: $nombre")
        val entrada = args["entrada"] as? Json.Cad
            ?: throw ErrorRpc(-32602, "falta «entrada» (string)")
        val r = forja.post("/forja/vitrina/$nombre", Json.obj("entrada" to entrada))
        if (r is Respuesta.Http && r.estado == 404) throw ErrorRpc(-32602, "no hay tal cristal: $nombre")
        if (r !is Respuesta.Http || r.estado != 200) return texto("forja: ${describir(r)}", true)
        val cuerpo = try { Json.leer(r.cuerpo) as? Json.Obj } catch (e: JsonInvalido) { null }
        val salida = cuerpo?.get("salida") as? Json.Cad
        val defecto = cuerpo?.get("defecto") as? Json.Cad
        return when {
            salida != null -> texto(salida.valor, false)
            defecto != null -> texto("defecto: ${defecto.valor}", true)
            else -> texto("forja: respuesta inesperada: ${r.cuerpo}", true)
        }
    }

    private fun fija(r: Respuesta): Json =
        if (r is Respuesta.Http && r.bien) texto(r.cuerpo, false)
        else texto("forja: ${describir(r)}", true)

    private fun describir(r: Respuesta): String = when (r) {
        is Respuesta.Http -> "HTTP ${r.estado}: ${r.cuerpo}"
        is Respuesta.SinForja -> "no responde (${r.motivo})"
    }

    private fun texto(t: String, error: Boolean): Json = Json.obj(
        "content" to Json.Lista(listOf(Json.obj("type" to Json.Cad("text"), "text" to Json.Cad(t)))),
        "isError" to Json.Bool(error),
    )

    private fun tarea(args: Json.Obj): String {
        val t = (args["tarea"] as? Json.Cad)?.valor
            ?: throw ErrorRpc(-32602, "falta «tarea» (string)")
        if (!patronTarea.matches(t)) throw ErrorRpc(-32602, "«tarea» no es un nombre de tarea: $t")
        return t
    }

    private fun muestras(args: Json.Obj): Int {
        val m = args["muestras"]?.takeIf { it != Json.Nulo } ?: return 5
        val n = (m as? Json.Num)?.texto?.takeIf { patronEntero.matches(it) }?.toIntOrNull()
        if (n == null || n !in 0..1000) throw ErrorRpc(-32602, "«muestras» tiene que ser un entero entre 0 y 1000")
        return n
    }
}
