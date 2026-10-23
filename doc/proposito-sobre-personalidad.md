# Propósito sobre personalidad

> *Purpose over personality*: que el entorno del agente no diga quién es su
> dueño, sino a qué ha venido.

Un agente de IA trabaja dentro de un entorno, y el entorno se cuela en todo
lo que lee y produce. Cada `pwd`, cada prompt de shell, cada `whoami`, cada
ruta de un error y cada `ls` entran en su contexto, y desde ahí empujan:
el modelo continúa lo que ve. Un `/home/<nombre-de-pila>/Descargas/` le
habla de una persona; un `/home/winner/strategies/` le habla de una tarea.

El patrón tiene dos mitades:

- **Fuera la personalidad.** Nada del entorno dice quién es el dueño, para
  quién trabaja ni cómo vive. Eso no ayuda al agente y sale en cada
  transcripción.
- **Dentro el propósito.** El usuario, la máquina y las carpetas se nombran
  según lo que el agente tiene que hacer ahí, de manera que cada vistazo al
  entorno le recuerde el objetivo.

Y una regla para lo que sobra: **lo que no sirve al propósito va en un
`.folder`**. Existe, pero no aparece.

```
  entorno con personalidad                  entorno con propósito
  ────────────────────────                  ─────────────────────
  silvia@portatil-casa                      winner@arena-1
  /home/silvia/                             /home/winner/
  ├── Proyectos-2026/                       ├── strategies/   lo que compite
  │   ├── cliente-acme/  ← para quién       ├── results/      lo que ha ganado o perdido
  │   └── tesis-final-v3/                   ├── work/         experimentos (purgable)
  ├── Fotos/  Descargas/  Banco/  ← vida    ├── docs/         reglas del juego
  └── ...                                   └── .media/ .archive/ .backups/ …
                                                        (ocultas)
  el contexto dice:                         el contexto dice:
  quién, para quién, cómo vive              a qué se ha venido
```

## Por qué

- **El nombre trabaja.** El modelo no distingue «instrucciones» de «lo que
  hay alrededor»: todo es contexto y todo condiciona lo que sigue. Un
  entorno nombrado según el propósito lo repite en cada ruta sin gastar una
  línea del prompt en ello.
- **Lo que se filtra dice menos.** Las [llaves de miel](llaves-de-miel.md)
  avisan de que una transcripción ha salido; quitar la personalidad hace
  que, cuando sale, cuente lo mínimo. Son las dos caras de lo mismo: saber
  *que* se ha filtrado y que *lo* filtrado valga poco.
- **Las muestras se pueden compartir.** La cantera y las semillas de los
  cristales guardan entradas y salidas reales. Sin rutas personales, una
  semilla se publica sin limpiarla a mano, y un cristal no aprende por
  accidente que `/home/silvia` forma parte del dominio.
- **Menos ruido, menos distracción.** Un `ls` con veinte carpetas personales
  es contexto que el agente lee, pondera y a veces toca. Lo que no aparece
  no le roba atención.
- **Igual en todas las máquinas.** El mismo usuario y las mismas rutas en
  cada nodo con el mismo propósito: las transcripciones se parecen, el
  prefijo de la caché de prompts se reutiliza y una sesión cambia de
  máquina sin cambiar nada.

## El usuario: su nombre es su propósito

El usuario del agente se llama como **lo que tiene que ser**, no como quien
lo usa:

| Usuario | Propósito | Qué le recuerda al modelo |
|---|---|---|
| `logical` | Razonar, construir, operar: el trabajo general | Que ahí se razona con lógica |
| `winner` | Competir y ganar: estrategias, torneos, *trading* en papel | Que el objetivo es ganar, y que se mide |

- Un nombre por propósito, no por persona ni por herramienta. Si nace un
  propósito nuevo, nace un usuario nuevo con su nombre: corto, en inglés
  corriente, que se lea como una cualidad o un rol.
- Su casa es `/home/<propósito>` y su grupo, el suyo. Ni el nombre del
  dueño, ni un apodo, ni un nombre que solo entienda él.
- La **máquina** también se nombra por función (`arena-1`, `build-2`), y el
  árbol compartido de la flota, con el mismo criterio que el usuario
  (`/logical-node`).
- La **identidad de git** del agente es la del propósito o la del proyecto,
  configurada en el repo; la del dueño no está en el entorno del agente.
- El usuario **no tiene privilegios** sobre lo personal: no lee
  `/home/<dueño>` ni lo necesita. Lo que le haga falta se le monta o se le
  clona en su casa.

## Las carpetas: nombres que empujan

Pocas carpetas y poco profundas. Los nombres son **convencionales donde la
convención ya dice el propósito** (el modelo los conoce de su entrenamiento
y no hay que explicárselos) y **del dominio donde el propósito es
concreto**:

```
/home/logical/                        /home/winner/
├── src/      un checkout por repo    ├── strategies/   una por directorio
├── work/     efímero (purgable)      ├── results/      cada partida, su resultado
├── docs/     lo que se entrega       ├── work/         efímero (purgable)
├── .config/ .cache/ .local/  (XDG)   ├── docs/         reglas y criterio de victoria
└── .bare/ .archive/ .backups/ .media/└── .config/ .cache/ .archive/ …
```

Reglas:

- **El nombre dice para qué sirve lo que hay dentro.** `results/` empuja a
  medir; `strategies/`, a proponer; `src/`, a construir. Si una carpeta no
  se puede nombrar por lo que se hace con ella, probablemente sobra o va
  oculta.
- **Nada de nombres propios, años, versiones** (`-v3`, `-final`), clientes,
  idiomas mezclados ni metáforas privadas. Un nombre que hay que explicar no
  empuja: confunde, y la explicación se paga en tokens en cada sesión.
- **La organización va en los metadatos, no en la ruta.** La licencia de un
  repo está en su `LICENSE`, su cliente en su README, su fecha en git. Si un
  dato se lee del contenido, no se codifica en el árbol: en la ruta, sale en
  cada transcripción y además se desincroniza.
- **Plano mejor que hondo.** `src/<repo>`, no
  `src/<cliente>/<año>/<licencia>/<repo>`. Cada nivel es un dato más en
  cada ruta y un paso más que el agente tiene que adivinar.
- **Una ruta por cosa.** Lo canónico en un sitio, lo efímero en `work/`. Un
  agente no tiene que adivinar cuál de tres copias es la buena.

## Lo que no sirve al propósito, en `.folder`

La regla es una: **si el agente no lo necesita para su propósito, va en una
carpeta oculta.** Medios, archivo, copias, descargas, repos bare, estado de
programas. Sigue ahí y se llega por su ruta, pero:

- `ls`, los *globs* (`*`) y el autocompletado no la enseñan;
- las herramientas de búsqueda de los agentes (y `rg`, `fd`) la saltan por
  defecto;
- lo primero que ve el agente al llegar es solo su propósito.

Lo que es importante lo decide el propósito, no el valor: las fotos de
familia valen más que cualquier repo y van en `.media/`, precisamente porque
el agente no tiene nada que hacer con ellas.

## Que sea declarativo

Los usuarios, sus grupos y sus árboles se declaran en el sistema (en NixOS,
`users.users.<propósito>` y reglas de `systemd.tmpfiles`), igual en todos
los nodos; no se crean a mano en una sesión. Mover lo que ya existe al árbol
nuevo es una migración con su plan, no un `mv` desde el agente.

## Medirlo

Que los nombres empujen es una hipótesis razonable, pero no un dato. Se
mide como todo lo demás: la misma tarea, con el mismo modelo, en un entorno
neutro (`user`, `src/`) y en uno con propósito (`winner`, `strategies/`), con
suficientes casos para que la diferencia no sea ruido, y con el criterio de
éxito fijado antes de mirar. Si no hay diferencia, la mitad «fuera la
personalidad» sigue valiendo por sí sola.

## Límites

- **No es anonimato.** El contenido sigue identificando: el código, los
  commits, los correos dentro de los ficheros, el propio `CLAUDE.md`. El
  patrón quita lo que el entorno añade sin necesidad; lo que el trabajo
  lleva dentro, lo lleva.
- **Oculto no es protegido.** Un punto delante del nombre es una cuestión de
  atención, no de permisos: `ls -a` lo enseña. Lo que el agente no debe
  leer se protege con permisos o no se monta, no con un punto.
- **Un propósito mal nombrado empuja mal.** `winner` empuja a ganar, y un
  agente empujado a ganar puede querer ganar como sea. El criterio de
  victoria (en `docs/`) y los límites (en sus instrucciones) tienen que
  estar a la altura del nombre.
- **Romper lo que ya funciona cuesta.** Cambiar de usuario y de árbol en una
  flota viva toca servicios, permisos, rutas absolutas en configuraciones y
  hábitos. Se hace por pasos, nodo a nodo, empezando por el menos crítico.

---

© 2026 Silvio Macías Sánchez. Ver [COPYRIGHT.md](../COPYRIGHT.md).
