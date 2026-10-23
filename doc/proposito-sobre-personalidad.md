# Propósito sobre personalidad

*Purpose over personality*: el entorno de ejecución como contexto implícito
de un agente de IA.

## Resumen

Un agente basado en un modelo de lenguaje (LLM) no solo recibe un *prompt*:
recibe también, de manera implícita, el entorno en el que trabaja. Nombres de
usuario, nombres de máquina, rutas, árboles de directorios y prompts de
shell entran en su ventana de contexto con cada orden que ejecuta, y salen
de ella en cada transcripción. Este documento propone un patrón de diseño
del entorno, **propósito sobre personalidad**, con dos componentes: (i)
eliminar del entorno toda información sobre la persona que lo posee, y (ii)
nombrar usuario, máquina y directorios según el propósito del agente, de
forma que el contexto implícito refuerce el objetivo de la tarea. Una
tercera regla relega a directorios ocultos (`.folder`) todo lo que no sirve
a ese propósito. Se formulan las hipótesis que el patrón presupone, se
revisa la evidencia disponible, que es parcial y en un caso contraria, y se
describe un diseño experimental para contrastarlas.

## 1. Introducción

Un agente de programación o de operación ejecuta órdenes en un sistema real
y lee su salida. Esa salida contiene, sin que nadie lo haya decidido, una
descripción del entorno: `whoami` devuelve un nombre, `pwd` una ruta, `ls`
un inventario, y cualquier traza de error repite las rutas absolutas. Para
el modelo, todo ello es texto en su contexto, indistinguible en naturaleza
de las instrucciones explícitas.

De ahí se siguen dos consecuencias. La primera es de **confidencialidad**:
las transcripciones salen de la máquina (al proveedor del modelo, a
registros, a la cantera de la [forja](forja.md), al archivo de la
[agencia](agencia.md), a semillas de cristales publicadas), y llevan consigo
lo que el entorno revela de su dueño. La segunda es de **comportamiento**:
si el contexto condiciona la continuación del modelo, el entorno es una
parte del *prompt* que se diseña por omisión, casi siempre sin intención.

El patrón trata el entorno como un artefacto de diseño más: algo que se
declara, se nombra con un objetivo y se mide.

## 2. Trabajo relacionado

**Sensibilidad al contexto irrelevante.** Shi et al. (2023) muestran que
añadir información irrelevante a problemas aritméticos degrada de forma
apreciable la precisión de los LLM. Liu et al. (2024) documentan que el uso
de la información depende de su posición en contextos largos. Sclar et al.
(2024) encuentran variaciones grandes de rendimiento ante cambios de formato
del *prompt* sin contenido semántico. Estos resultados apoyan que el ruido
del entorno no es inocuo y motivan la regla de los directorios ocultos.

**Roles y personas en el *prompt*.** Kong et al. (2024) informan de mejoras
en razonamiento *zero-shot* al asignar un rol al modelo. En sentido
contrario, Zheng et al. (2024), con un estudio sistemático sobre miles de
preguntas y numerosos roles, concluyen que añadir una persona al *prompt*
de sistema no mejora el rendimiento de manera consistente y que su efecto es
difícil de predecir. Esta evidencia mixta obliga a tratar el componente (ii)
como hipótesis y no como hecho. El patrón difiere de esos trabajos en que
el rol no se declara en una instrucción, sino que aparece de forma ambiental
y repetida (en cada ruta y cada prompt de shell). No conocemos estudios que
midan este caso.

**Primado en psicología.** El análogo humano, el primado conductual (Bargh,
Chen y Burrows, 1996), tiene una historia de replicaciones fallidas (Doyen
et al., 2012). Se cita como advertencia metodológica, no como apoyo: un
efecto plausible y llamativo no exime de medirlo.

**Fuga de información.** Carlini et al. (2021) demuestran que los modelos
pueden memorizar y reproducir datos de entrenamiento, entre ellos datos
personales. Greshake et al. (2023) muestran que un agente que lee contenido
del entorno puede ser manipulado para exfiltrar su contexto (inyección
indirecta de *prompts*). Ambos refuerzan el componente (i): lo que no está
en el contexto no se puede memorizar ni exfiltrar. El patrón complementa a
las [llaves de miel](llaves-de-miel.md): estas detectan que una transcripción
se ha filtrado, y este reduce lo que la filtración revela.

**Optimización de objetivos mal especificados.** Krakovna et al. (2020)
recopilan casos de *specification gaming*: sistemas que satisfacen la letra
de su objetivo y no su intención. Es relevante para el riesgo de un
propósito nombrado con demasiada fuerza (§6).

## 3. El patrón

### 3.1. Definiciones

- **Entorno visible**: todo texto que el agente obtiene del sistema sin
  pedirlo expresamente como dato de la tarea: identidad del usuario, nombre
  de la máquina, rutas, listados de directorios y prompts.
- **Personalidad**: información del entorno visible sobre la persona que lo
  posee (nombre, clientes, organización privada, vida personal) que no
  contribuye a la tarea.
- **Propósito**: el objetivo para el que existe el agente, enunciable con
  una palabra o un rol.

### 3.2. Componentes

**C1. Eliminar la personalidad.** El entorno visible no contiene
personalidad. Ni el usuario, ni la máquina, ni las rutas llevan nombres
propios, clientes, fechas, versiones ni metáforas privadas. La organización
que hoy se codifica en la ruta (licencia, cliente, año) se traslada a los
metadatos del contenido (`LICENSE`, README, historial de git), donde ya
está y de donde se puede leer.

**C2. Nombrar por el propósito.** Usuario, máquina y directorios se nombran
según el propósito. Un usuario por propósito:

| Usuario | Propósito | Refuerzo esperado |
|---|---|---|
| `logical` | Razonar, construir y operar (trabajo general) | Razonamiento lógico, rigor |
| `winner` | Competir y ganar (estrategias, torneos, *trading* en papel) | Orientación al resultado y a su medida |

La máquina se nombra por función (`arena-1`, `build-2`). El árbol compartido
de una flota sigue el mismo criterio (`/logical-node`). La identidad de git
del agente es la del propósito o la del proyecto, nunca la del dueño.

**C3. Ocultar lo que no sirve al propósito.** Todo lo que el agente no
necesita va en directorios ocultos (`.media/`, `.archive/`, `.backups/`,
`.bare/`), que siguen accesibles por su ruta, pero que `ls`, los *globs*, el
autocompletado y las herramientas de búsqueda habituales (`rg`, `fd`) omiten
por defecto. Lo que se oculta lo decide el propósito, no el valor de la
información: las fotografías personales valen más que cualquier repositorio
y se ocultan precisamente porque el agente no tiene nada que hacer con ellas.

### 3.3. Estructura de directorios

Pocos niveles y nombres convencionales donde la convención ya expresa el
propósito (el modelo los conoce de su entrenamiento), o del dominio donde el
propósito es concreto:

```
/home/logical/                         /home/winner/
├── src/      un checkout por repo     ├── strategies/   una por directorio
├── work/     efímero, purgable        ├── results/      cada partida y su resultado
├── docs/     lo que se entrega        ├── work/         efímero, purgable
├── .config/ .cache/ .local/  (XDG)    ├── docs/         reglas y criterio de victoria
└── .bare/ .archive/ .backups/ .media/ └── .config/ .cache/ .archive/ …
```

Criterios: (a) cada nombre describe lo que se hace con su contenido; (b)
estructura plana (`src/<repo>`, no `src/<cliente>/<año>/<licencia>/<repo>`),
porque cada nivel añade información a cada ruta y un paso más que inferir;
(c) una ubicación canónica por objeto, para que el agente no tenga que elegir
entre copias.

### 3.4. Declaración

Usuarios, grupos y árboles se declaran en la configuración del sistema (en
NixOS, `users.users.<propósito>` y reglas de `systemd.tmpfiles`), de forma
idéntica en todos los nodos con el mismo propósito. La reproducibilidad es
una condición del patrón: entornos idénticos producen transcripciones
comparables, prefijos de caché de *prompts* reutilizables y experimentos
repetibles.

## 4. Hipótesis

- **H1 (confidencialidad).** C1 y C3 reducen la información personal
  presente en las transcripciones. Se sigue de la construcción y solo
  requiere una auditoría: contar apariciones de identificadores personales
  antes y después.
- **H2 (distracción).** C3 reduce el consumo de contexto y los errores
  atribuibles a contenido irrelevante. La sostienen Shi et al. (2023), pero
  no se ha medido en entornos de agentes.
- **H3 (refuerzo).** C2 mejora la tasa de éxito de la tarea frente a un
  entorno neutro (`user`, `src/`). Es la hipótesis más débil: la evidencia
  sobre roles explícitos es mixta (Kong et al., 2024; Zheng et al., 2024) y
  no conocemos ninguna sobre roles ambientales.

C1 y C3 se justifican por H1 aunque H2 y H3 resultaran nulas.

## 5. Evaluación propuesta

Diseño entre condiciones con tres entornos (personal, neutro y con
propósito) idénticos salvo en los nombres, con el mismo modelo, la misma
versión, la misma temperatura y las mismas tareas:

1. **Prerregistro.** Antes de ejecutar nada se fijan las tareas, la métrica
   de éxito de cada una (para `winner`, el criterio de victoria escrito en
   `docs/`), el tamaño de muestra y el análisis.
2. **Muestra.** Suficientes tareas y repeticiones por condición como para
   detectar el efecto mínimo que interesa. Un efecto que no compensa
   renombrar una flota no merece detectarse.
3. **Métricas.** Tasa de éxito (H3), tokens consumidos y errores por
   contenido irrelevante (H2), e identificadores personales por
   transcripción (H1).
4. **Análisis.** Comparación por pares sobre las mismas tareas, con
   intervalos de confianza. Si se prueban varios nombres de propósito, se
   corrige por comparaciones múltiples.

Amenazas a la validez: el efecto puede depender del modelo y de su versión
(los resultados no se generalizan sin replicar); el nombre del propósito
puede correlacionar con la tarea de formas que el diseño no separa; y las
tareas elegidas por quien propone el patrón tienden a favorecerlo, por lo
que conviene tomarlas de un conjunto previo.

## 6. Limitaciones y riesgos

- **No es anonimato.** El contenido del trabajo sigue identificando: el
  código, los commits, las direcciones dentro de los ficheros, las propias
  instrucciones del agente. El patrón elimina lo que el entorno añade sin
  necesidad, no lo que la tarea contiene.
- **Ocultar no es proteger.** Un directorio oculto es una medida de atención,
  no de control de acceso: `ls -a` lo muestra. Lo que el agente no debe leer
  se protege con permisos o no se le monta.
- **Un propósito puede reforzar en exceso.** Si H3 es cierta, también lo es
  su riesgo: un entorno que repite `winner` empuja a ganar, y un objetivo
  reforzado sin un criterio bien especificado invita al *specification
  gaming* (Krakovna et al., 2020). El criterio de victoria y los límites del
  agente tienen que estar especificados con el mismo cuidado que el nombre.
- **Coste de migración.** Cambiar usuarios y árboles en un sistema en
  producción afecta a servicios, permisos y rutas absolutas en las
  configuraciones. Se aplica de forma incremental, nodo a nodo y empezando
  por el menos crítico.

## 7. Conclusión

El entorno de un agente es parte de su contexto, se diseñe o no. El patrón
propone diseñarlo: sin rastro de su dueño, nombrado según su propósito y con
lo accesorio fuera de la vista. La primera parte se justifica por la
confidencialidad; la segunda es una hipótesis contrastable, con evidencia
previa mixta, que este documento deja planteada para medirla antes de darla
por buena.

## Referencias

- Bargh, J. A., Chen, M. y Burrows, L. (1996). Automaticity of social
  behavior: Direct effects of trait construct and stereotype activation on
  action. *Journal of Personality and Social Psychology*, 71(2), 230–244.
- Carlini, N. et al. (2021). Extracting training data from large language
  models. *30th USENIX Security Symposium*.
- Doyen, S., Klein, O., Pichon, C.-L. y Cleeremans, A. (2012). Behavioral
  priming: It's all in the mind, but whose mind? *PLoS ONE*, 7(1), e29081.
- Greshake, K. et al. (2023). Not what you've signed up for: Compromising
  real-world LLM-integrated applications with indirect prompt injection.
  *AISec '23*.
- Kong, A. et al. (2024). Better zero-shot reasoning with role-play
  prompting. *NAACL 2024*.
- Krakovna, V. et al. (2020). Specification gaming: the flip side of AI
  ingenuity. *DeepMind Blog*.
- Liu, N. F. et al. (2024). Lost in the middle: How language models use long
  contexts. *Transactions of the ACL*, 12.
- Sclar, M., Choi, Y., Tsvetkov, Y. y Suhr, A. (2024). Quantifying language
  models' sensitivity to spurious features in prompt design. *ICLR 2024*.
- Shi, F. et al. (2023). Large language models can be easily distracted by
  irrelevant context. *ICML 2023*.
- Zheng, M., Pei, J., Logeswaran, L., Lee, M. y Jurgens, D. (2024). When "A
  helpful assistant" is not really helpful: Personas in system prompts do
  not improve performances of large language models. *Findings of EMNLP
  2024*.

---

© 2026 Silvio Macías Sánchez. Ver [COPYRIGHT.md](../COPYRIGHT.md).
