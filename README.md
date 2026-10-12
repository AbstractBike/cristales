# cristales

> Dale a un LLM una pregunta y te dará una respuesta.
> Pídele cómo se responde y no tendrás que volver a preguntarle.

**Cristalizar** es pedirle a un LLM *la forma de hacerlo*, no *el resultado*.
En vez de pescado, la caña: un programa, una gramática, una regla, una consulta,
algo determinista que queda en el repositorio y responde solo, sin volver a
llamar al modelo.

Un LLM en tiempo de ejecución es **líquido**: toma la forma de cada entrada,
cuesta en cada llamada, no repite exactamente y no se puede auditar. Lo que
genera cuando le pides el método es **cristal**: una estructura fija, barata,
reproducible, versionada en git, con sus pruebas.

```
           líquido                                 cristal
  entrada ──► LLM ──► salida            entrada ──► f ──► salida
           (cada vez)                             (código, una vez generado)

  coste:   por llamada                    coste:   una vez (la nucleación)
  salida:  estocástica                    salida:  determinista
  auditar: imposible                      auditar: git diff
  falla:   en silencio                    falla:   con un defecto explícito
```

## Las pipelines de IA se cristalizan

Una pipeline de IA es una cadena de etapas que hoy llaman a un modelo:
clasificar, extraer, normalizar, enrutar, resumir. Casi ninguna necesita
inteligencia en cada ejecución; la necesitó **una vez**, para entender el
problema. Cristalizar la pipeline es ir sacando al LLM del camino caliente,
etapa a etapa:

1. **Líquida** — la etapa llama al LLM en cada entrada. Así nace todo.
2. **Mixta** — un cristal atiende lo que sabe; lo que no, cae al LLM y se
   registra como *defecto*.
3. **Cristalina** — el cristal lo cubre todo. El LLM ya no se ejecuta; solo se
   le convoca para *recristalizar* cuando el dominio cambia.

Los defectos de la fase mixta son las semillas de la siguiente versión del
cristal. La pipeline aprende, pero lo aprendido queda escrito como código, no
como pesos ni como contexto.

El LLM deja de ser un intérprete y pasa a ser un **compilador**: no ejecuta tu
problema, te escribe el programa que lo ejecuta.

Y si no sabes cuáles son las etapas, la [forja](doc/forja.md) las descubre:
un proxy delante del LLM que ve pasar las tareas, avisa cuando una está madura
para cristalizar y, una vez cristalizada, la atiende sin llamar al modelo. Y
al revés, como servidor MCP: un agente usa los cristales como herramientas y
observa la forja hasta nuclear él mismo los que ella le señala.

Y mientras una tarea siga siendo líquida, la [agencia](doc/agencia.md)
elige a qué modelo pedírsela: el más barato que, según su histórico, la hace
bien.

## Por qué

- **Pureza.** Un cristal es una función pura del input. Igual que un flake sin
  `--impure`: lo que se evaluó hoy se evalúa idéntico mañana.
- **Coste.** Se paga la nucleación, no cada pez.
- **Auditoría.** Cada decisión de la pipeline está en un fichero que se puede
  leer, revisar y revertir.
- **Fallo explícito.** Un cristal sabe cuándo no sabe; un LLM contesta igual.
- **Soberanía.** Una pipeline cristalina corre sin red, sin proveedor y sin GPU.

## Contenido

| Ruta | Qué es |
|---|---|
| [`doc/concepto.md`](doc/concepto.md) | Vocabulario: semilla, nucleación, cristal, defecto, fusión… |
| [`doc/pipelines.md`](doc/pipelines.md) | Protocolo para cristalizar una pipeline de IA, etapa a etapa |
| [`doc/anatomia.md`](doc/anatomia.md) | Cómo se guarda un cristal en un repositorio |
| [`doc/forja.md`](doc/forja.md) | La forja: proxy de LLM que cristaliza las tareas que atiende, y su variante MCP |
| [`doc/agencia.md`](doc/agencia.md) | La agencia: agentes que saben a qué modelo pedir cada cosa, con el histórico de cada encargo (MCP) |
| [`prompts/cristalizar.md`](prompts/cristalizar.md) | El prompt de nucleación: pedir el método, no el resultado |
| [`lib/`](lib/) | `cristal`, librería OCaml 5: etapas líquida/mixta/cristalina y su composición |
| [`lib/forja/`](lib/forja/), [`lib/forja-http/`](lib/forja-http/) | Núcleo de la forja y su proxy HTTP (Messages API, GreptimeDB) |
| [`bin/forja/`](bin/forja/) | El binario `forja` y su vitrina de cristales |
| [`mcp/`](mcp/) | `forja-mcp` en OCaml, TypeScript, Go, Rust, Kotlin y Python: contrato y prueba de conformidad |
| [`lib/agencia/`](lib/agencia/), [`bin/agencia-mcp/`](bin/agencia-mcp/) | La agencia y su servidor MCP |
| [`legal/`](legal/) | Divulgación técnica defensiva, sellos de tiempo y expediente |
| [`cristales/fecha-es/`](cristales/fecha-es/) | Cristal de ejemplo: fechas en español a ISO 8601 |
| [`cristales/grafica-modelo/`](cristales/grafica-modelo/) | Las gráficas de sobremesa que nombra un texto, con su catálogo (GTX 750 Ti a RTX 5090, RX 9070 XT, Arc) |
| [`cristales/grafica-anuncio/`](cristales/grafica-anuncio/) | Qué se vende en un anuncio de segunda mano de informática y en qué estado |
| [`cristales/grafica-noticia/`](cristales/grafica-noticia/) | De qué va una noticia de hardware para quien sigue las gráficas |

## Construir

```sh
nix develop -c dune build @runtest
```


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](COPYRIGHT.md).
