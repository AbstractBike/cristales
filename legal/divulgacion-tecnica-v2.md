# Divulgación técnica: cristalización de tareas de un modelo de lenguaje a través de un proxy

**Autor:** Silvio Macías Sánchez
**Primera divulgación pública:** 11 de octubre de 2026, repositorio
`https://github.com/AbstractBike/cristales` (público desde 2026-10-11T03:06Z;
la forja, desde 2026-10-11T05:56Z, commit `581d980`).
**Documento:** versión 2, 11 de octubre de 2026. Sustituye a la versión 1
([`divulgacion-tecnica.md`](divulgacion-tecnica.md)), que se conserva sin
cambios junto a su sello de tiempo. Único cambio: la implementación de
referencia del servidor MCP incluye también Python (§5).

> Este documento se publica como **divulgación defensiva**: su fin es que el
> método y sus variantes formen parte del estado de la técnica con fecha
> cierta, de modo que nadie pueda obtener después una patente sobre ellos. No
> concede licencia alguna: el texto y el código siguen sujetos a
> [`COPYRIGHT.md`](../COPYRIGHT.md).

## Abstract (English)

A method and system in which a proxy placed between client applications and a
large language model (LLM) observes the requests it forwards, groups them into
*tasks* (fixed instructions applied to a varying input), records each
input/output pair produced by the model, measures whether the model answers
the same input consistently by occasionally issuing the same request twice,
and, once a task has enough consistent samples, asks the LLM — instead of for
another answer — for a deterministic *program* that computes the task (the
*method*, not the *result*), together with tests and an explicit list of
inputs it must reject. After human or automated review, the program (a
*crystal*) is registered with the proxy, which from then on answers that task
by executing the program, without calling the model, and routes only the
inputs the program declares it cannot handle (*defects*) back to the model,
recording them as seeds for the next version of the program. The proxy is
transparent to clients (it speaks the same API as the model provider), it
supports both free-text tasks and structured-output tasks expressed as a
single forced tool call, and it exposes its state (tasks, maturity, seeds,
nucleation prompts, crystals) to other agents through an introspection API and
a Model Context Protocol (MCP) server.

## 1. Campo

Sistemas que usan modelos de lenguaje (LLM) en tiempo de ejecución, y en
particular la sustitución progresiva y verificable del modelo por programas
deterministas generados por el propio modelo.

## 2. Problema

Un LLM en el camino de ejecución cuesta en cada llamada, no repite
exactamente, no se puede auditar y falla en silencio. Muchas de las tareas
que una aplicación le encarga tienen estructura estable (extraer, clasificar,
normalizar, enrutar, validar) y necesitaron inteligencia **una vez**, para
entender el problema, no en cada entrada. Guardar las respuestas del modelo
(una caché) solo acierta con entradas idénticas y congela también sus
errores.

## 3. Descripción del método

### 3.1 Componentes

- **Proxy.** Se interpone entre los clientes y el proveedor del modelo y habla
  la misma API que este (por ejemplo, la Messages API de Anthropic), de modo
  que un cliente se conecta cambiando solo la URL base. Las credenciales del
  cliente se reenvían sin guardarse.
- **Tarea.** Clase de peticiones con las mismas instrucciones fijas (la
  *plantilla*: el prompt de sistema y, si la hay, la definición de la
  herramienta forzada) aplicadas a una *entrada* variable (el texto del
  usuario). Se identifica por un nombre explícito que pone el cliente (una
  cabecera) o, en su defecto, por un resumen criptográfico de la plantilla.
- **Cantera.** Registro persistente de las muestras de cada tarea: plantilla,
  entrada, salida del modelo, una segunda salida cuando se contrastó y, si la
  muestra vino de un defecto de un cristal, su motivo.
- **Cristal.** Programa determinista y puro (sin red, reloj ni aleatoriedad;
  el contexto, como la fecha, entra como argumento) que para una entrada
  devuelve una salida o un **defecto** declarado con su motivo.
- **Vitrina.** Conjunto de cristales aceptados, cada uno asociado a una
  tarea y a una fase (*mixta* o *cristalina*), registrado como código
  revisado y no como estado mutable.
- **Horno.** Lugar donde el proxy deposita, para cada tarea madura, su
  *semilla* (plantilla y muestras) y el *prompt de nucleación* ya relleno.

### 3.2 Flujo de una petición

1. El proxy decide si la petición es una **tarea cristalizable**: un único
   turno de usuario con texto, instrucciones fijas, sin streaming, y sin
   herramientas o con exactamente una herramienta forzada. Lo demás
   (conversaciones, agentes con herramientas libres, streaming) se reenvía
   sin tocar.
2. Si la tarea tiene cristal en la vitrina, se ejecuta. Si da salida, el
   proxy construye una respuesta en el formato del proveedor (un bloque de
   texto, o un bloque de uso de herramienta con el JSON de la salida) sin
   llamar al modelo y con consumo de tokens nulo.
3. Si el cristal declara un defecto y la fase es *mixta*, la petición va al
   modelo y la muestra se registra con el motivo del defecto. Si la fase es
   *cristalina*, se devuelve un error explícito con el motivo y no se llama al
   modelo.
4. Si la tarea no tiene cristal (*líquida*), la petición va al modelo y la
   muestra se registra. Una de cada *n* llamadas líquidas de la tarea se envía
   **dos veces** al modelo (en paralelo) para medir si repite la respuesta
   (*contraste*). Las salidas estructuradas se comparan en forma canónica
   (claves ordenadas).

### 3.3 Madurez y nucleación

Una tarea **madura** cuando la cantera tiene al menos *m* muestras, al menos
*k* contrastes, y el modelo repitió la respuesta en una fracción de los
contrastes igual o mayor que *e*. La madurez materializa el criterio: *si al
pedirle el resultado al modelo dos veces se espera la misma respuesta, esa
tarea debería ser un programa*. Un modelo que no se repite no hace madurar la
tarea.

Al madurar, el proxy genera la semilla y el **prompt de nucleación**, que
pide al modelo **el programa que resuelve la tarea para cualquier entrada, no
la respuesta a estas entradas**: una función pura con una firma dada que
devuelve salida o defecto, pruebas que cubran los ejemplos y las invariantes,
la lista explícita de los casos que no cubre, y la declaración de que el
problema no admite un método general cuando sea así (en vez de un programa que
sea una tabla de los ejemplos).

El programa devuelto se acepta si pasa la *red* (los ejemplos de la semilla,
las invariantes sobre toda la cantera, el rechazo de lo que está fuera de
dominio y la coincidencia con las salidas del modelo en lo que acepta), y se
registra en la vitrina en fase *mixta*. La red solo crece: un cristal nuevo
debe pasar la red del anterior.

### 3.4 Ciclo de vida

*Líquida* → *madura* → *mixta* → *cristalina*. Los defectos de la fase mixta
son las semillas de la recristalización. Si la fracción de entradas que
resuelve el cristal (*grado de cristalización*) cae bruscamente, el dominio
ha cambiado y el cristal se **funde**: la tarea vuelve a mixta o líquida.

### 3.5 Introspección y MCP

El proxy expone una API de solo lectura con la vitrina, la ejecución directa
de cada cristal, la lista de tareas con su fase, muestras, contrastes,
coincidencias y madurez, el detalle con las últimas muestras, la semilla y el
prompt de nucleación. Un servidor del Model Context Protocol, implementado en
varios lenguajes contra un mismo contrato y verificado con una prueba de
conformidad común, la ofrece a agentes como herramientas: cuatro de
observación y una por cristal, cuyos defectos vuelven como resultados con
marca de error para que el agente decida.

## 4. Variantes y generalizaciones

Las siguientes variantes forman parte de lo divulgado:

- **Protocolo y transporte.** Cualquier API de modelos (Anthropic Messages,
  OpenAI Chat Completions o Responses, Gemini, servidores locales tipo
  llama.cpp, vLLM u Ollama), por HTTP, gRPC, colas de mensajes o llamadas en
  proceso; como proxy de red, *sidecar*, biblioteca cliente, *middleware* de
  un framework de agentes, plugin de un gateway o servidor MCP con
  *sampling*.
- **Identificación de tareas.** Por nombre explícito; por resumen de la
  plantilla; por la combinación de plantilla, herramienta, esquema de salida,
  modelo o parámetros; por similitud semántica (embeddings, *clustering*) de
  plantillas o de pares entrada/salida; por la ruta o el servicio que llama;
  por plantillas con variables (separando las partes fijas de las variables
  mediante alineamiento de varias peticiones).
- **Medida de estabilidad.** Repetición de la misma petición (en paralelo o
  diferida, con la misma o distinta temperatura o semilla); comparación entre
  varios modelos; acuerdo de *k* de *n* muestras; comparación exacta,
  canónica, por esquema, por campos o semántica; uso de la probabilidad de los
  tokens; estabilidad por subconjuntos de entradas.
- **Criterio de madurez.** Umbrales fijos o adaptativos de muestras,
  contrastes y estabilidad; coste acumulado o previsto; volumen de llamadas;
  cobertura de la distribución de entradas; decisión humana.
- **Forma del cristal.** Código en cualquier lenguaje, expresiones regulares,
  gramáticas, autómatas y transductores de estado finito, tablas de reglas,
  árboles de decisión, consultas SQL, esquemas de validación, plantillas,
  módulos WebAssembly, y modelos pequeños o clasificadores entrenados o
  destilados a partir de la cantera, siempre que devuelvan salida o defecto
  declarado.
- **Nucleación y verificación.** Manual, asistida o automática: el proxy u
  otro proceso pide el programa al modelo, lo compila y ejecuta en un entorno
  aislado contra la red, lo compara con la cantera, lo somete a revisión y lo
  despliega; despliegue en sombra (el cristal responde en paralelo sin
  servir, para medir coincidencia) o canario (una fracción del tráfico).
- **Salida estructurada.** Tareas con herramienta forzada, modo JSON o
  esquema de respuesta; el cristal devuelve el objeto y el proxy lo envuelve
  en el formato del proveedor; una salida del cristal que no cumple el
  esquema se trata como defecto.
- **Composición.** Pipelines de etapas líquidas, mixtas y cristalinas; un
  cristal que cubre solo una parte de la salida (la plantilla de un texto, la
  rúbrica de un juicio) dejando líquido el hueco que lo necesita.
- **Registro.** Cantera en cualquier almacén (bases de series temporales,
  relacionales, de documentos, ficheros), con o sin anonimización o
  minimización de las entradas.
- **Métrica.** Grado de cristalización por tarea y global, ahorro de tokens,
  coste y latencia, como señal de fusión ante cambios de dominio.

## 5. Implementación de referencia

Repositorio `https://github.com/AbstractBike/cristales`: núcleo en OCaml 5
(`lib/forja`), proxy HTTP con Eio (`lib/forja-http`), cantera en GreptimeDB,
cristal de ejemplo (`cristales/fecha-es`), prompt de nucleación
(`prompts/cristalizar.md`), servidores MCP en OCaml, TypeScript, Go, Rust,
Kotlin y Python (`mcp/`, contrato en `mcp/CONTRATO.md`), verificados todos
con la misma prueba de conformidad, y sus pruebas.

---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Ver
[`COPYRIGHT.md`](../COPYRIGHT.md).
