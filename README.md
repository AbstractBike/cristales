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
| [`prompts/cristalizar.md`](prompts/cristalizar.md) | El prompt de nucleación: pedir el método, no el resultado |
| [`lib/`](lib/) | `cristal`, librería OCaml 5: etapas líquida/mixta/cristalina y su composición |
| [`cristales/fecha-es/`](cristales/fecha-es/) | Cristal de ejemplo: fechas en español a ISO 8601 |

## Construir

```sh
nix develop -c dune build @runtest
```
