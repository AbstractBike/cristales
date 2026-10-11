// © 2026 Silvio Macías Sánchez. Todos los derechos reservados.
// Libre para investigación; uso comercial: ver COPYRIGHT.md.

// JSON mínimo y completo: el JDK no trae uno. Los números se guardan con su
// texto original, para devolver el `id` de una petición tal cual llegó.

sealed interface Json {
    data object Nulo : Json
    data class Bool(val valor: Boolean) : Json
    data class Num(val texto: String) : Json
    data class Cad(val valor: String) : Json
    data class Lista(val elementos: List<Json>) : Json
    data class Obj(val campos: Map<String, Json>) : Json {
        operator fun get(clave: String): Json? = campos[clave]
    }

    companion object {
        fun obj(vararg campos: Pair<String, Json>): Obj = Obj(linkedMapOf(*campos))
        fun num(n: Int): Num = Num(n.toString())
        fun leer(texto: String): Json = Lector(texto).documento()
    }
}

class JsonInvalido(mensaje: String) : Exception(mensaje)

private class Lector(private val s: String) {
    private var i = 0

    fun documento(): Json {
        val v = valor()
        blancos()
        if (i != s.length) falla("sobra texto")
        return v
    }

    private fun falla(que: String): Nothing = throw JsonInvalido("$que en la posición $i")

    private fun blancos() {
        while (i < s.length && s[i] in " \t\n\r") i++
    }

    private fun valor(): Json {
        blancos()
        if (i >= s.length) falla("fin inesperado")
        return when (s[i]) {
            '{' -> objeto()
            '[' -> lista()
            '"' -> Json.Cad(cadena())
            't' -> literal("true", Json.Bool(true))
            'f' -> literal("false", Json.Bool(false))
            'n' -> literal("null", Json.Nulo)
            else -> numero()
        }
    }

    private fun literal(palabra: String, v: Json): Json {
        if (!s.startsWith(palabra, i)) falla("literal desconocido")
        i += palabra.length
        return v
    }

    private fun objeto(): Json.Obj {
        i++
        val campos = LinkedHashMap<String, Json>()
        blancos()
        if (i < s.length && s[i] == '}') { i++; return Json.Obj(campos) }
        while (true) {
            blancos()
            if (i >= s.length || s[i] != '"') falla("se esperaba una clave")
            val clave = cadena()
            blancos()
            if (i >= s.length || s[i] != ':') falla("se esperaba ':'")
            i++
            campos[clave] = valor()
            blancos()
            if (i >= s.length) falla("objeto sin cerrar")
            when (s[i++]) {
                ',' -> continue
                '}' -> return Json.Obj(campos)
                else -> { i--; falla("se esperaba ',' o '}'") }
            }
        }
    }

    private fun lista(): Json.Lista {
        i++
        val elementos = ArrayList<Json>()
        blancos()
        if (i < s.length && s[i] == ']') { i++; return Json.Lista(elementos) }
        while (true) {
            elementos.add(valor())
            blancos()
            if (i >= s.length) falla("lista sin cerrar")
            when (s[i++]) {
                ',' -> continue
                ']' -> return Json.Lista(elementos)
                else -> { i--; falla("se esperaba ',' o ']'") }
            }
        }
    }

    private fun cadena(): String {
        i++ // la comilla de apertura
        val sb = StringBuilder()
        while (true) {
            if (i >= s.length) falla("cadena sin cerrar")
            val c = s[i++]
            when {
                c == '"' -> return sb.toString()
                c == '\\' -> escape(sb)
                c < ' ' -> { i--; falla("carácter de control en una cadena") }
                else -> sb.append(c)
            }
        }
    }

    private fun escape(sb: StringBuilder) {
        if (i >= s.length) falla("escape sin terminar")
        when (val e = s[i++]) {
            '"' -> sb.append('"')
            '\\' -> sb.append('\\')
            '/' -> sb.append('/')
            'b' -> sb.append('\b')
            'f' -> sb.append('\u000C')
            'n' -> sb.append('\n')
            'r' -> sb.append('\r')
            't' -> sb.append('\t')
            // \uXXXX: los pares sustitutos llegan como dos escapes seguidos y
            // quedan juntos en el StringBuilder, que es UTF-16 como Java.
            'u' -> sb.append(hex4())
            else -> { i--; falla("escape desconocido '\\$e'") }
        }
    }

    private fun hex4(): Char {
        if (i + 4 > s.length) falla("\\u incompleto")
        val n = s.substring(i, i + 4).toIntOrNull(16) ?: falla("\\u no hexadecimal")
        i += 4
        return n.toChar()
    }

    private fun numero(): Json.Num {
        val inicio = i
        if (i < s.length && s[i] == '-') i++
        if (i < s.length && s[i] == '0') i++
        else if (i < s.length && s[i] in '1'..'9') digitos()
        else falla("número inválido")
        if (i < s.length && s[i] == '.') { i++; if (!digitos()) falla("número inválido") }
        if (i < s.length && s[i] in "eE") {
            i++
            if (i < s.length && s[i] in "+-") i++
            if (!digitos()) falla("número inválido")
        }
        return Json.Num(s.substring(inicio, i))
    }

    private fun digitos(): Boolean {
        val inicio = i
        while (i < s.length && s[i] in '0'..'9') i++
        return i > inicio
    }
}

/** Una línea de JSON: sin saltos de línea, no ASCII tal cual (se escribe en UTF-8). */
fun Json.escribir(): String = StringBuilder().also { escribirEn(it, this) }.toString()

private fun escribirEn(sb: StringBuilder, v: Json) {
    when (v) {
        Json.Nulo -> sb.append("null")
        is Json.Bool -> sb.append(v.valor)
        is Json.Num -> sb.append(v.texto)
        is Json.Cad -> cadenaEn(sb, v.valor)
        is Json.Lista -> {
            sb.append('[')
            v.elementos.forEachIndexed { k, e -> if (k > 0) sb.append(','); escribirEn(sb, e) }
            sb.append(']')
        }
        is Json.Obj -> {
            sb.append('{')
            var primero = true
            for ((k, e) in v.campos) {
                if (!primero) sb.append(',')
                primero = false
                cadenaEn(sb, k); sb.append(':'); escribirEn(sb, e)
            }
            sb.append('}')
        }
    }
}

private fun cadenaEn(sb: StringBuilder, s: String) {
    sb.append('"')
    for ((k, c) in s.withIndex()) {
        when {
            c == '"' -> sb.append("\\\"")
            c == '\\' -> sb.append("\\\\")
            c == '\n' -> sb.append("\\n")
            c == '\r' -> sb.append("\\r")
            c == '\t' -> sb.append("\\t")
            c == '\b' -> sb.append("\\b")
            c.code == 0x0C -> sb.append("\\f")
            // Controles, los separadores de línea de Unicode (por si algún
            // lector parte líneas con ellos) y los sustitutos sueltos, que no
            // caben en UTF-8.
            c < ' ' || c.code == 0x2028 || c.code == 0x2029 ||
                c.isHighSurrogate() && !(k + 1 < s.length && s[k + 1].isLowSurrogate()) ||
                c.isLowSurrogate() && !(k > 0 && s[k - 1].isHighSurrogate()) ->
                sb.append(String.format("\\u%04x", c.code))
            else -> sb.append(c)
        }
    }
    sb.append('"')
}
