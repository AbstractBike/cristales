# Despersonaliza

> Lo que ve el agente lo ve todo el que lea su transcripción: que vea una
> máquina cualquiera.

Un agente de IA trabaja dentro de un entorno, y el entorno se cuela en todo
lo que produce. Cada `pwd`, cada ruta de un error, cada `ls` y cada `git
status` acaban en la transcripción, y la transcripción sale del ordenador:
al proveedor del modelo, a la cantera de la [forja](forja.md), al archivo de
la [agencia](agencia.md), a una semilla de cristal, a un enlace compartido,
a un issue. Un `/home/<nombre-de-pila>/clientes/<empresa>/…` dice quién
eres, para quién trabajas y cómo organizas tu vida antes de que el agente
haya hecho nada.

**Despersonalizar** es darle al agente un entorno que no diga nada de nadie:

1. **Un usuario genérico.** El agente trabaja como `logical`, en
   `/home/logical`, en una máquina que se llama como su función, no como su
   dueño.
2. **Una arquitectura de carpetas lógica, simple y nada exótica.** La que
   cualquiera esperaría, y la que el modelo ya conoce de su entrenamiento.
3. **Lo no importante, en carpetas ocultas.** Todo lo que el agente no
   necesita ver va en un `.folder`: existe, pero no aparece.

```
  entorno personal                          entorno despersonalizado
  ────────────────                          ────────────────────────
  /home/silvia/                             /home/logical/
  ├── Proyectos-2026/                       ├── src/
  │   ├── cliente-acme/  ← para quién       │   ├── web/
  │   └── tesis-final-v3/                   │   └── api/
  ├── Fotos/  Descargas/  Banco/  ← vida    ├── work/
  ├── nodo-zeta/repos-por-licencia/ ← raro  ├── docs/
  └── ...                                   └── .media/ .archive/ .backups/ …
                                                        (ocultas)
  la transcripción dice:                    la transcripción dice:
  quién, para quién, cómo vive              nada que no sea el trabajo
```

## Por qué

- **Lo que se filtra dice menos.** Las [llaves de miel](llaves-de-miel.md)
  avisan de que una transcripción ha salido; despersonalizar hace que, cuando
  sale, cuente lo mínimo. Son las dos caras de lo mismo: saber *que* se ha
  filtrado y que *lo* filtrado valga poco.
- **Las muestras se pueden compartir.** La cantera y las semillas de los
  cristales guardan entradas y salidas reales. Con rutas genéricas, una
  semilla se publica sin limpiarla a mano, y un cristal no aprende por
  accidente que `/home/silvia` forma parte del dominio.
- **El modelo ya sabe dónde está todo.** `~/src/<repo>` no hace falta
  explicarlo; un árbol propio con nombres inventados sí, y esa explicación
  se paga en tokens en cada sesión (en `CLAUDE.md`, en `AGENTS.md`, en las
  preguntas del agente) y aun así se equivoca. Lo convencional es lo que el
  modelo predice bien.
- **Menos ruido, menos distracción.** Un `ls` con veinte carpetas personales
  es contexto que el agente lee, pondera y a veces toca. Lo que no aparece
  no le roba atención.
- **Igual en todas las máquinas.** El mismo usuario y las mismas rutas en
  cada nodo: las transcripciones se parecen entre sí, el prefijo de la caché
  de prompts se reutiliza y una sesión se mueve de máquina sin cambiar nada.

## El usuario genérico

- Se llama **`logical`**, su casa es **`/home/logical`** y su grupo, el
  suyo. Ni el nombre del dueño, ni un apodo, ni un nombre que solo use él.
- **El nombre trabaja.** `logical` no dice nada de nadie, pero sí le dice
  algo al modelo: cada ruta, cada prompt de shell y cada `whoami` le
  recuerdan, de pasada, que ahí se razona con lógica. Es mejor que `user`,
  que es igual de genérico y no aporta nada. El mismo nombre sirve para el
  árbol compartido de la flota (`/logical-node`).
- El **nombre de la máquina** dice lo que hace o dónde está en la flota
  (`build-1`, `web-2`), no de quién es.
- La **identidad de git** del agente es la de la máquina o la del proyecto,
  configurada en el repo; la del dueño no está en el entorno del agente.
- Es un usuario **sin privilegios** sobre lo personal: no lee `/home/<dueño>`
  ni falta que le hace. Lo que necesite se le monta o se le clona en su casa.

## La arquitectura de carpetas

Pocas carpetas, nombres en inglés corriente, un nivel de profundidad para
lo que importa:

```
/home/logical/
├── src/            un checkout por repositorio: src/<repo>
├── work/           área efímera: copias, worktrees, experimentos (purgable)
├── docs/           lo que se lee o se entrega
├── .config/        configuración (XDG, lo de siempre)
├── .cache/         cachés (XDG)
├── .local/         datos y binarios locales (XDG)
├── .bare/          repositorios bare, si los hay
├── .archive/       lo viejo que no se borra
├── .backups/       copias de seguridad
└── .media/         fotos, vídeo, música: nada que el agente deba mirar
```

Reglas:

- **Nombres que existen en todas partes.** `src`, `work`, `docs`, `bin`,
  `tmp`. Nada de nombres propios, años, versiones (`-v3`, `-final`), clientes,
  idiomas mezclados ni metáforas de la casa.
- **La organización va en los metadatos, no en la ruta.** La licencia de un
  repo está en su `LICENSE`, su cliente en su README, su fecha en git. Si un
  dato se puede leer del contenido, no se codifica en el árbol: duplicarlo en
  la ruta lo filtra y además se desincroniza.
- **Plano mejor que hondo.** `src/<repo>`, no
  `src/<cliente>/<año>/<licencia>/<repo>`. Cada nivel es un dato más que
  sale en cada ruta.
- **Una ruta por cosa.** Lo canónico en `src/`, lo efímero en `work/`. Un
  agente no tiene que adivinar cuál de tres copias es la buena.

## Lo no importante, en `.folder`

La regla es una: **si el agente no lo necesita para trabajar, va en una
carpeta oculta.** Medios, archivo, copias, descargas, bare, estado de
programas. Sigue ahí y se llega a ella por su ruta, pero:

- `ls`, los *globs* (`*`) y el autocompletado no la enseñan;
- las herramientas de búsqueda de los agentes (y `rg`, `fd`) la saltan por
  defecto;
- el árbol que el agente ve al llegar cabe en una línea.

Qué es importante lo decide el trabajo, no el valor: las fotos de familia
valen más que cualquier repo y van en `.media/`, precisamente porque el
agente no tiene nada que hacer con ellas.

## Que sea declarativo

El usuario, sus grupos y su árbol se declaran en el sistema (en NixOS,
`users.users.logical` y reglas de `systemd.tmpfiles`), igual en todos los nodos;
no se crean a mano en una sesión. Mover lo que ya existe al árbol nuevo es
una migración con su plan, no un `mv` desde el agente.

## Límites

- **No es anonimato.** El contenido sigue identificando: el código, los
  commits, los correos dentro de los ficheros, el propio `CLAUDE.md`.
  Despersonalizar quita lo que el entorno añade sin necesidad; lo que el
  trabajo lleva dentro, lo lleva.
- **Oculto no es protegido.** Un punto delante del nombre es una cuestión de
  atención, no de permisos: `ls -a` lo enseña. Lo que el agente no debe
  leer se protege con permisos o no se monta, no con un punto.
- **Las rutas de la flota también son entorno.** Un árbol compartido con
  nombres que solo entiende uno es tan delator como un `/home/<nombre>`; el
  árbol de la flota se nombra con el mismo criterio que el usuario.
- **Romper lo que ya funciona cuesta.** Cambiar de usuario y de árbol en una
  flota viva toca servicios, permisos, rutas absolutas en configuraciones y
  hábitos. Se hace por pasos, nodo a nodo, empezando por el menos crítico.

---

© 2026 Silvio Macías Sánchez. Ver [COPYRIGHT.md](../COPYRIGHT.md).
