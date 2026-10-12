# Divulgación técnica: agencia de agentes de IA que elige, para cada agente, el modelo de lenguaje más barato que su histórico juzgado demuestra fiable

**Autor:** Silvio Macías Sánchez
**Primera divulgación pública:** 12 de octubre de 2026, repositorio
`https://github.com/AbstractBike/cristales`, documento
[`doc/agencia.md`](../doc/agencia.md) e implementación en `lib/agencia`,
`lib/agencia-http`, `lib/agencia-mcp` y `bin/agencia-mcp` (commit
`442ba7d`, 2026-10-12T16:22Z; en GitHub a más tardar el
2026-10-12T19:39Z).
**Documento:** versión 1, 12 de octubre de 2026.

> Este documento se publica como **divulgación defensiva**: su fin es que el
> método y sus variantes formen parte del estado de la técnica con fecha
> cierta, de modo que nadie pueda obtener después una patente sobre ellos. No
> concede licencia alguna: el texto y el código siguen sujetos a
> [`COPYRIGHT.md`](../COPYRIGHT.md).

## Abstract (English)

A method and system — an *agency* — through which an artificial-intelligence
agent creates other agents and delegates work to them, while the agency
decides, for every piece of work, which language model performs it. Each
created agent is a named task with fixed instructions and an ordered
*ladder* of candidate models, from the cheapest to the most capable, plus a
default model. Every delegation (an *assignment*: one input given to one
agent) is routed to a model chosen from that agent's own recorded history:
the cheapest model on the ladder that has proven *reliable* for that agent
(enough judged assignments, a sufficient fraction judged good); while none
has, the agent's default, or the next model that has not been *discarded*;
and, periodically, the cheapest model below that one that has not yet been
evaluated (*downward exploration*), so that the agency lowers its cost when
a cheaper model turns out to suffice. Every assignment is recorded in an
append-only archive with the chosen model, the reason for the choice, the
input, the output or error, latency and token counts; the delegating agent
(or a person, or an automatic check) then records a *verdict* (good or bad)
for the assignment, which is what the agency learns from. Model errors count
as bad verdicts without judgment; failures that never reached the model
(network, authorisation, rate limits, server errors) and answers produced by
a deterministic program instead of the model count for no model. The
history used for choosing is scoped to the current version of the agent's
instructions (a digest of them), so redefining an agent restarts its
evaluation without erasing the past. The agency is exposed to agents as a
Model Context Protocol (MCP) server whose tools create agents, list them
with their per-model record and next choice, show an agent's history,
delegate, and judge — and in which every created agent also appears as a
tool of its own. Its calls may pass through a crystallising LLM proxy, which
sees each agent as a task and replaces the model with a program once the
task matures, chaining the two decisions: *which* model, and *whether* a
model is needed at all.

## 1. Campo

Sistemas que usan modelos de lenguaje (LLM) en tiempo de ejecución,
orquestación de agentes de IA, y en particular la selección del modelo que
atiende cada tarea según su coste y su calidad medida.

## 2. Problema

Un agente de IA que delega subtareas (clasificar, extraer, resumir,
redactar con unas instrucciones fijas) suele pedírselas siempre al mismo
modelo, normalmente el más capaz y caro, porque no sabe cuál basta para cada
una. Lo que se sabe de cómo lo hizo cada modelo con cada subtarea se pierde
al acabar la sesión. Los enrutadores de modelos conocidos deciden por
petición con un clasificador entrenado de antemano o con reglas globales, no
por cada agente con el veredicto de quien recibe el trabajo, y no guardan un
histórico auditable de qué se pidió a quién y cómo salió.

## 3. Descripción del método

### 3.1 Componentes

- **Agente.** Un nombre, una descripción, unas instrucciones fijas (el
  *system prompt*), una **escalera** de modelos ordenada del más barato al
  más capaz, un modelo **por defecto** de esa escalera y un límite de
  salida. Lo crea, o lo redefine, otro agente o una persona.
- **Versión.** Un resumen (digest) de las instrucciones. Otras instrucciones
  son otro trabajo: el histórico de las anteriores se conserva pero no
  cuenta para elegir.
- **Encargo.** Una entrada dada a un agente, con su identificador, el modelo
  elegido y el **motivo** de la elección, la fuente de la respuesta, la
  salida o el error, el tiempo, los tokens de entrada y salida, y su
  veredicto y nota cuando los haya.
- **Archivo.** Almacén *append-only* de definiciones de agentes (gana la
  última de cada nombre), encargos y veredictos (gana el último de cada
  encargo). Nada se borra: el histórico es auditable y consultable por SQL.
- **Política.** Juicios mínimos para clasificar un modelo, fracción de
  acierto para darlo por fiable y frecuencia de exploración.
- **Servidor MCP.** Las herramientas para crear, listar, consultar el
  histórico, encargar y juzgar, y una herramienta por agente.

### 3.2 Clasificación de los modelos de un agente

Para cada peldaño de la escalera, con los encargos de la versión actual:

- **por ver** mientras tenga menos juicios que el mínimo;
- **fiable** si la fracción de encargos juzgados bien alcanza el umbral;
- **descartado** si no.

Un error devuelto por el modelo cuenta como mal sin necesidad de juicio. No
cuentan para ningún modelo los encargos que no llegaron a él (sin conexión,
sin autorización, límite de peticiones, error del servidor) ni los que
respondió un programa determinista en su lugar.

### 3.3 Elección del modelo de un encargo

1. La **base** es el modelo fiable más barato.
2. Si no hay ninguno, el modelo por defecto del agente; si está descartado,
   el siguiente más capaz que no lo esté; si no queda ninguno por encima, el
   más capaz por debajo que no lo esté; si lo están todos, el más capaz.
3. Uno de cada *n* encargos (contados en el histórico de la versión, de forma
   determinista) va al modelo **por ver más barato por debajo de la base**,
   si lo hay: la exploración es siempre hacia abajo en coste.
4. Quien encarga puede imponer un modelo; se respeta y cuenta igual.

La elección es una función pura del histórico y la política, y devuelve el
motivo en lenguaje natural, que se guarda con el encargo y se devuelve a
quien encarga junto con el identificador para juzgarlo.

### 3.4 Ciclo

Crear el agente → encargar → la agencia elige, llama al modelo y archiva →
quien encarga juzga → el veredicto cambia la clasificación y la siguiente
elección. Las instrucciones del servidor MCP piden al agente que delegue las
subtareas repetitivas y que juzgue cada resultado.

### 3.5 Encadenado con la cristalización

Cada llamada lleva el nombre del agente como identificador de tarea y puede
pasar por un proxy que cristaliza tareas (la forja del mismo repositorio,
divulgada en [`divulgacion-tecnica-v2.md`](divulgacion-tecnica-v2.md)): el
proxy acumula muestras de cada agente y, cuando la tarea madura, la atiende
con un programa determinista. La agencia anota esas respuestas como del
programa, sin atribuirlas a ningún modelo. Así, primero se elige el modelo
más barato que sabe hacerlo y después ninguno.

## 4. Variantes y generalizaciones

Las siguientes variantes forman parte de lo divulgado:

- **Candidatos.** Modelos de distintos proveedores, versiones o tamaños;
  modelos locales y remotos; el mismo modelo con distintos parámetros
  (temperatura, razonamiento extendido, longitud), prompts, herramientas o
  presupuestos; agentes completos o cadenas de agentes como peldaños;
  programas deterministas como peldaño cero.
- **Orden de la escalera.** Por precio por token, por coste medido en el
  histórico (tokens o dinero por acierto), por latencia, por consumo de
  energía o por una combinación ponderada; reordenada automáticamente con lo
  medido.
- **Veredictos.** Binarios, graduados o con puntuación; dados por el agente
  que encarga, por una persona, por otro modelo que actúa de juez, por
  pruebas o validaciones automáticas (esquema, tipos, ejemplos conocidos),
  por la coincidencia entre dos modelos o por el uso posterior de la salida
  (se aceptó, se editó, se descartó); veredictos implícitos por silencio
  tras un plazo.
- **Política de clasificación.** Umbrales fijos; intervalos de confianza o
  estimación bayesiana del acierto; ventanas deslizantes o decaimiento
  temporal para que un modelo descartado pueda volver a evaluarse o para
  seguir cambios del proveedor; umbrales distintos por agente.
- **Exploración.** Periódica determinista, aleatoria, por algoritmos de
  bandido (épsilon-voraz, UCB, muestreo de Thompson), hacia abajo o en
  ambos sentidos; exploración en la sombra, pidiendo a la vez al candidato y
  a la base y comparando sin entregar la del candidato; escalado inmediato
  al siguiente peldaño cuando un encargo sale mal.
- **Granularidad.** Por agente, por versión de las instrucciones, por clase
  de entrada (longitud, idioma, rasgos extraídos de la entrada), por
  usuario o por proyecto; agentes que comparten histórico por similitud de
  sus instrucciones.
- **Archivo.** Base de series temporales, base relacional, registro de
  eventos, ficheros; con las entradas completas, resumidas o sustituidas por
  su huella cuando son sensibles; consultable por quien elige y por las
  personas para auditoría y costes.
- **Interfaz.** Servidor MCP por stdio o por HTTP; API HTTP; biblioteca;
  una herramienta por agente o una sola para encargar; creación de agentes
  por otros agentes (agentes que crean agentes), por personas o por
  configuración declarativa.
- **Encadenado.** Con un proxy de cristalización, con una caché, con
  barreras de seguridad o con un proxy de observabilidad delante de los
  modelos; la agencia como fuente de muestras etiquetadas (los encargos
  juzgados bien) para cristalizar, destilar o ajustar un modelo más
  pequeño, que entra después en la escalera.

## 5. Antecedentes conocidos

Son conocidos los enrutadores de modelos de lenguaje que eligen por petición
con un clasificador o con reglas (por ejemplo RouteLLM, los modos
automáticos de agregadores como OpenRouter o Martian), las cascadas que
prueban de menor a mayor coste hasta que una respuesta supera una
puntuación (FrugalGPT), la selección de modelos como problema de bandido de
varios brazos y la orquestación de agentes que se delegan tareas. Lo que
este documento divulga es su combinación: **agentes creados por otros
agentes**, cada uno con su **escalera** y su **histórico propio y
auditable**; la clasificación fiable / descartado / por ver a partir de los
**veredictos de quien recibe el trabajo**, excluyendo los fallos que no
llegaron al modelo y lo que respondió un programa; la elección del **más
barato fiable** con **exploración solo hacia abajo**; el histórico acotado a
la **versión de las instrucciones**; su exposición como **servidor MCP** con
una herramienta por agente; y el **encadenado con la cristalización** de las
tareas en programas deterministas (§3.5).

## 6. Implementación de referencia

Repositorio `https://github.com/AbstractBike/cristales`, documento
[`doc/agencia.md`](../doc/agencia.md): núcleo puro en OCaml 5
(`lib/agencia`), llamadas a la Messages API de Anthropic y a Chat
Completions de OpenAI y archivo en GreptimeDB (`lib/agencia-http`),
servidor MCP (`lib/agencia-mcp`, `bin/agencia-mcp`) y su red de pruebas
(`test/agencia`).

---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Ver
[`COPYRIGHT.md`](../COPYRIGHT.md).
