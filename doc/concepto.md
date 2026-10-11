# Concepto

La metáfora es física y se toma en serio: cada término nombra una pieza
concreta del proceso.

## Fases

**Líquido.** Cómputo hecho por un LLM en tiempo de ejecución. Se adapta a
cualquier entrada, pero no tiene forma propia: cada llamada es nueva, cuesta,
puede variar y no deja rastro revisable.

**Cristal.** Artefacto determinista que un LLM escribió para resolver una
*clase* de problemas: código, expresión regular, gramática, tabla de reglas,
consulta SQL, esquema de validación. Vive en git, tiene pruebas y no necesita
al modelo para ejecutarse.

**Mixto.** Cristal con respaldo líquido. El cristal intenta primero; si declara
un defecto, la entrada pasa al LLM y el caso queda registrado.

## Ciclo de vida

**Semilla.** Lo mínimo que hace falta para que crezca un cristal: la
descripción del problema, ejemplos de entrada y salida, y las invariantes que
la salida debe cumplir. La semilla se versiona junto al cristal.

**Nucleación.** El momento en que se le pide al LLM *el método*. No "¿qué fecha
es 'el 3 de marzo'?", sino "escribe la función que convierte cualquier fecha en
español a ISO 8601, y dime en qué casos no puede". Ver
[`prompts/cristalizar.md`](../prompts/cristalizar.md).

**Red cristalina.** Las invariantes y pruebas que definen la estructura. Un
cristal sin red es solo código generado; con red, es una pieza en la que se
puede confiar. Los ejemplos de la semilla son el primer trozo de la red.

**Defecto.** Entrada que el cristal reconoce que no sabe tratar. Es un
resultado legítimo, no una excepción: el cristal *dice* que no sabe. Los
defectos se registran con su entrada.

**Impureza.** Lo grave: entrada que el cristal trata *mal* sin darse cuenta.
Se combate engordando la red (más invariantes, más casos), nunca confiando en
el cristal a ciegas.

**Crecimiento / recristalización.** Los defectos acumulados se vuelven
semilla: se añaden a los ejemplos y se vuelve a nuclear. El cristal nuevo debe
pasar toda la red del viejo más los casos nuevos.

**Fusión.** Cuando el dominio cambia tanto que el cristal ya no vale (un
formato nuevo, una regla de negocio distinta), se funde: la etapa vuelve a
líquida, se recogen ejemplos y se cristaliza otra vez.

**Grado de cristalización.** Fracción de entradas de una etapa (o de toda la
pipeline) que resuelve el cristal sin llamar al LLM. Es la métrica que manda:
una pipeline madura tiende a 1.

**Procedencia.** Qué modelo, qué prompt y qué semilla produjeron el cristal.
Es la cristalografía: permite reproducir la nucleación y entender por qué el
cristal es como es.

## Qué cristaliza y qué no

Cristaliza bien lo que tiene **estructura estable**: extraer campos, clasificar
en un conjunto cerrado, normalizar formatos, enrutar por reglas, validar,
transformar entre esquemas, generar a partir de plantillas.

Resiste más lo que es **abierto por naturaleza**: redactar texto libre,
conversar, juzgar calidad subjetiva. Aun así suele cristalizar *parte*: la
plantilla del texto, la rúbrica del juicio, el árbol de decisión de la
conversación. Esas etapas quedan mixtas, con el líquido acotado al hueco que
de verdad lo necesita.

Regla práctica: si al pedirle el resultado al LLM dos veces esperas la misma
respuesta, esa etapa debería ser un cristal.

## Pescado y caña

| Pedir el pescado | Pedir la caña |
|---|---|
| "Clasifica este correo" | "Escribe el clasificador de correos y sus reglas" |
| "Extrae el importe de esta factura" | "Escribe el parser de facturas de este proveedor" |
| "¿Esta config es válida?" | "Escribe el validador de esta config" |
| "Traduce este JSON al esquema nuevo" | "Escribe la migración del esquema viejo al nuevo" |
| "Resume este log de error" | "Escribe el extractor de causas de estos logs" |
