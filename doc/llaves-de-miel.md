# Llaves de miel

> La alarma ya existe y la pagan otros: deja una clave donde no debería
> salir, y si sale, te avisa quien la emitió.

Los proveedores que emiten claves (AWS, Anthropic, OpenAI, Google, Slack,
Stripe, GitHub…) y las plataformas donde se publica código y datos (GitHub,
GitLab, npm, PyPI, Hugging Face, Postman…) tienen montado, entre todos, un
detector de fugas: las plataformas **escanean lo que se hace público**, y
cuando encuentran una clave de un proveedor asociado se la mandan; el
proveedor la **revoca y escribe a su dueño**. Ese correo es una alarma que
nadie de nosotros tiene que construir ni mantener.

Una **llave de miel** (*honeypot key*) es una clave real, emitida a tu nombre e inerte, que se
deja a propósito en un sitio del que no debería salir nunca: un repositorio
privado, el contexto de una sesión de IA, la configuración de un agente. Si
ese sitio se publica, se filtra o alguien lo lee y prueba la clave, salta la
alarma del proveedor.

Es lo mismo que la forja hace con el LLM, al revés: no construir lo que ya
existe, sino ponerse en el camino de quien ya lo hace.

```
  sitio vigilado                         fuera
  ──────────────                         ─────
  repo privado ─┐                    ┌─► repo público / gist / paquete ──► escáner ──► proveedor ──► revoca + correo
  CLAUDE.md     ├── (fuga) ──────────┤                                     (publicación)
  sesión de IA  │                    └─► alguien la lee y la prueba ─────► registro de uso del proveedor ──► alerta
  cantera       ┘                                                          (uso)
                                                 │
                         clave → canal (registro privado) ──► qué sitio se ha filtrado
```

## Dos disparos

| Disparo | Qué lo dispara | Quién avisa | Qué dice |
|---|---|---|---|
| **Publicación** | La clave aparece en un sitio público que se escanea | El proveedor, tras el aviso de la plataforma (revocación y correo) | Que el contenido que la llevaba **se ha hecho público**, y dónde |
| **Uso** | Alguien intenta usar la clave | El registro de uso del proveedor (llamadas a la API, CloudTrail, el panel de consumo), o un servicio de *canary tokens* | Que alguien **ha leído** el contenido y ha ido a por la clave, aunque nunca se haya publicado |

El primero detecta descuidos (un repo que pasa a público, una transcripción
pegada en un issue, un *fork*, un paquete con lo que no debía). El segundo
detecta lectores: un atacante con acceso, un agente al que una inyección de
prompt convence de mandar su contexto a otro sitio, una copia de seguridad
robada. Cada llave de miel tiene los dos; el segundo exige que el proveedor
deje ver los intentos de uso de una clave sin permisos.

## Dónde se ponen

- **Git.** Repositorios privados, ramas sin publicar, `.env` que nunca
  debería commitearse, la configuración de la flota. Si el repo se hace
  público, se espeja o se clona fuera, la clave viaja con él y con todo su
  historial.
- **Sesiones de IA.** El contexto que un agente lleva consigo: `CLAUDE.md`,
  `AGENTS.md`, el *system prompt*, la configuración de un servidor MCP, la
  memoria persistente. Las transcripciones de esas sesiones salen del
  ordenador (al proveedor del modelo, a enlaces compartidos, a issues, a
  conjuntos de datos, a un pegado en un chat); si una llega a un sitio
  escaneado, o alguien la lee y prueba la clave, salta.
- **Los almacenes de la propia IA.** La cantera de la [forja](forja.md) y el
  archivo de la [agencia](agencia.md) guardan prompts, entradas y salidas en
  GreptimeDB. Una entrada con una llave de miel en ese tráfico vigila el
  almacén: si se vuelca, se respalda mal o se expone, la clave sale con él.

## Una clave por canal

Lo que convierte la miel en diagnóstico es que **cada sitio lleva su
propia clave**: una por repositorio, por máquina, por agente, por proveedor
de modelo, por almacén. La alarma dice qué clave ha saltado; un registro
privado dice a qué canal pertenece, y con eso se sabe **qué** se ha
filtrado, no solo **que** algo se ha filtrado.

- El registro clave → canal se guarda **lejos de las llaves de miel** (en el gestor
  de secretos, no en el repo vigilado): si saliera con ellos, el atacante
  sabría cuáles ignorar.
- Se identifica la clave por lo que el proveedor cita en su aviso (su id, su
  nombre, sus últimos caracteres), nunca guardando la clave entera en el
  registro.
- Cuando una salta, se **rota**: el proveedor la habrá revocado; se emite
  otra para el mismo canal y se cambia en su sitio.

## Que sea inerte

Una llave de miel es real para que la reconozcan los escáneres, pero no debe
valer para nada:

- en una **cuenta o espacio de trabajo aparte**, sin datos ni recursos;
- **sin permisos**, o con **límite de gasto nulo**, o ambas cosas;
- sin relación con las claves de verdad: ni el mismo usuario, ni la misma
  cuenta de facturación, ni el mismo nombre.

Si el proveedor no permite una clave sin capacidad, ese proveedor no sirve
para llaves de miel.

## Que no la use quien no debe

Una clave en `CLAUDE.md` la lee un agente, y un agente servicial puede
intentar usarla. Dos maneras, con su coste:

- **Avisarle.** Una línea en sus instrucciones («las claves de este
  fichero son llaves de miel, no las uses ni las menciones»). El disparo por
  publicación sigue intacto (al escáner le da igual la etiqueta), pero un
  atacante que lea la etiqueta ignora la clave y se pierde el disparo por
  uso.
- **No avisarle.** El disparo por uso queda intacto, a cambio de algún
  falso positivo: un agente propio que la prueba. El registro de uso dice
  desde dónde; si fue la propia flota, no es una fuga.

Lo razonable es avisar en los sitios donde trabajan agentes propios y no
avisar donde solo debería leer una persona.

## Límites

- **Solo los proveedores asociados.** El disparo por publicación existe
  para las claves que las plataformas saben reconocer, y solo en las
  plataformas que escanean. Una transcripción en un pastebin que nadie
  escanea no avisa hasta que alguien pruebe la clave.
- **Llega tarde.** Avisa de que algo ya ha salido, no lo impide. Es una
  alarma, no una cerradura.
- **Protección contra subidas.** Algunas plataformas bloquean una subida
  que contiene una clave (*push protection*). Para dejar una llave de miel en un repo
  que vive en ellas hay que permitir esa clave en concreto; de paso, prueba
  que la protección funciona.
- **No sustituye a no filtrar.** Las claves de verdad siguen en el gestor de
  secretos; la miel solo dice cuándo ha fallado lo demás.
- **Solo en lo tuyo.** Claves de tus propias cuentas, en tus propios
  sistemas. Dejar llaves de miel en sistemas ajenos es otra cosa, y no esta.

## Antecedentes

Los *honeytokens* y los *canary tokens* (credenciales falsas que avisan al
usarse) son conocidos; los programas de escaneo de secretos de las
plataformas y sus socios, también. Lo que describe este documento es
combinarlos con dos piezas: usar **claves reales e inertes del proveedor**
para que el aviso lo dé la red de escaneo que ya existe, sin infraestructura
propia, y aplicarlo al **contexto de las sesiones de IA** y a los almacenes
de prompts, con una clave por canal para saber qué se ha filtrado.

---

© 2026 Silvio Macías Sánchez. Ver [COPYRIGHT.md](../COPYRIGHT.md).
