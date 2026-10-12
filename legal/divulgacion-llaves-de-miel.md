# Divulgación técnica: llaves de miel, credenciales reales e inertes que detectan la fuga de repositorios y de contextos de IA a través del escaneo de secretos de terceros

**Autor:** Silvio Macías Sánchez
**Primera divulgación pública:** 12 de octubre de 2026, repositorio
`https://github.com/AbstractBike/cristales`, documento
[`doc/llaves-de-miel.md`](../doc/llaves-de-miel.md) (commit `d104783`,
2026-10-12T19:35Z).
**Documento:** versión 1, 12 de octubre de 2026.

> Este documento se publica como **divulgación defensiva**: su fin es que el
> método y sus variantes formen parte del estado de la técnica con fecha
> cierta, de modo que nadie pueda obtener después una patente sobre ellos. No
> concede licencia alguna: el texto sigue sujeto a
> [`COPYRIGHT.md`](../COPYRIGHT.md).

## Abstract (English)

A method for detecting the leakage of private content — source repositories,
and in particular the context of artificial-intelligence sessions (system
prompts, agent instruction files, tool and MCP server configurations,
persistent agent memory, conversation transcripts, prompt and completion
logs, retrieval corpora and training datasets) — by deliberately placing in
that content *honeypot keys*: genuine credentials issued by a third-party
provider to the owner, made inert (isolated account, no permissions, zero
spending limit), and distinct for every channel being watched. Detection is
delegated to infrastructure that already exists and is operated by others:
when the content becomes public, the secret-scanning programs of code and
data hosting platforms recognise the credential and report it to its issuer,
which revokes it and notifies the owner (*publication trigger*); when
someone reads the content and tries the credential, the issuer's usage logs
record the attempt (*use trigger*). A private registry, kept apart from the
baits, maps each credential to the channel where it was placed, so that an
alert identifies which repository, machine, agent, model provider, session
or store has leaked. The method covers how the baits are issued, made
inert, placed, labelled or left unlabelled for the owner's own AI agents,
attributed, rotated after an alert and managed declaratively across a fleet.

## 1. Campo

Seguridad de la información: detección de fugas de datos y de credenciales,
*honeytokens*, y en particular la vigilancia del contexto que los sistemas de
IA (agentes, asistentes de programación, servidores MCP, proxies de LLM)
llevan consigo y envían a terceros.

## 2. Problema

Un agente de IA lleva en su contexto lo que su dueño no publicaría nunca:
instrucciones, configuración, fragmentos de código privado, memoria. Ese
contexto sale del ordenador hacia el proveedor del modelo, hacia enlaces
compartidos, issues, conjuntos de datos, registros y copias de seguridad, y
puede extraerse por inyección de prompt. Lo mismo vale, desde siempre, para
los repositorios privados. El dueño no tiene manera de saber si algo de eso
se ha hecho público o lo ha leído alguien. Los *canary tokens* clásicos
exigen montar y mantener la infraestructura que recibe el aviso, y solo
detectan el uso, no la publicación.

## 3. Descripción del método

### 3.1 Componentes

- **Llave de miel.** Credencial real emitida por un proveedor (una clave de
  API, un token, unas credenciales de nube) a nombre del dueño, con un
  formato que los escáneres de secretos reconocen, y **inerte**: en una
  cuenta o espacio de trabajo aparte, sin datos ni recursos, sin permisos o
  con límite de gasto nulo, sin relación con las credenciales de verdad.
- **Canal.** El sitio vigilado: un repositorio, una rama, una máquina, un
  fichero de instrucciones de agente, un servidor MCP, un proveedor de
  modelo, una sesión, un almacén de prompts.
- **Registro clave → canal.** Privado y guardado lejos de los cebos (en el
  gestor de secretos), identifica cada llave por lo que el proveedor cita en
  su aviso (identificador, nombre, últimos caracteres), sin guardar la
  credencial entera.
- **Red de escaneo de terceros.** Los programas de escaneo de secretos de
  las plataformas de alojamiento (repositorios de código, registros de
  paquetes, plataformas de modelos y datos, herramientas de API) y los
  acuerdos con los proveedores emisores para revocar y notificar.
- **Registro de uso del proveedor.** Lo que el emisor anota de cada intento
  de usar la credencial: llamadas a su API, registros de auditoría, panel de
  consumo.

### 3.2 Funcionamiento

1. Para cada canal se emite una llave de miel distinta, se hace inerte y se
   anota en el registro clave → canal.
2. Se coloca en el canal, donde un lector la encontraría: en el contenido de
   un fichero commiteado, en las instrucciones o la memoria de un agente, en
   la configuración de un servidor, en una entrada del tráfico de un proxy de
   LLM que acaba en su almacén.
3. **Disparo por publicación.** Si el contenido del canal se hace público en
   un sitio que se escanea, la plataforma reconoce la credencial y avisa al
   emisor, que la revoca y notifica al dueño.
4. **Disparo por uso.** Si alguien lee el contenido y prueba la credencial,
   el emisor registra el intento (y lo rechaza, por ser inerte).
5. Con el aviso, el registro clave → canal dice qué canal se ha filtrado.
   Se investiga ese canal, se emite otra llave para él y se sustituye.

### 3.3 Agentes propios

Un agente de IA del dueño que lea la llave puede intentar usarla. El método
contempla dos políticas: **etiquetarla** en las instrucciones del agente
como cebo que no debe usar ni mencionar (conserva el disparo por publicación,
pierde el de uso frente a un lector que lea la etiqueta), o **no
etiquetarla** (conserva ambos y distingue los falsos positivos por el
origen de la llamada en el registro de uso). Se elige por canal.

## 4. Variantes y generalizaciones

Las siguientes variantes forman parte de lo divulgado:

- **Tipo de credencial.** Claves de API de proveedores de modelos de IA, de
  nube, de pago, de mensajería, de control de versiones o de cualquier
  servicio; tokens OAuth, de acceso personal o de bots; pares de claves de
  acceso; cadenas de conexión a bases de datos; URLs de *webhooks*; claves
  SSH o de firma; claves privadas de monederos de criptomonedas con un saldo
  mínimo (el barrido del saldo es el disparo por uso); credenciales de
  servicios propios o de servicios de *canary tokens*, en combinación con
  las de terceros.
- **Contenido vigilado.** Repositorios y su historial, ramas sin publicar,
  submódulos, espejos y *forks*; ficheros `.env` y de configuración;
  ficheros de instrucciones de agentes (`CLAUDE.md`, `AGENTS.md`,
  `.cursorrules` y equivalentes); *system prompts* de asistentes, GPTs o
  agentes desplegados (detecta la extracción y difusión del *system
  prompt*); configuraciones de servidores MCP y de herramientas; memoria
  persistente de agentes; transcripciones y conversaciones compartidas;
  registros de prompts y respuestas de proxies, gateways y plataformas de
  observabilidad; almacenes de muestras para cristalizar o destilar;
  corpus de RAG y bases vectoriales; conjuntos de datos de entrenamiento o
  ajuste fino (detecta su publicación y, si el modelo la memoriza y la
  reproduce, su regurgitación); wikis, tickets, chats, correo, documentos,
  imágenes de contenedor, copias de seguridad, volcados y registros.
- **Colocación.** En texto plano, en un comentario, en una variable con un
  nombre verosímil, en un historial de git ya reescrito o no, en una entrada
  sintética inyectada periódicamente en el tráfico de un proxy de LLM, en
  cada copia de un documento repartido a varios destinatarios.
- **Granularidad de la atribución.** Una llave por repositorio, rama,
  máquina, usuario, agente, proveedor de modelo, sesión, destinatario,
  versión de documento o ventana de tiempo, y sus combinaciones; el canal
  puede codificarse también en el nombre o la descripción que el proveedor
  devuelve en su aviso.
- **Fuentes del aviso.** Programas de escaneo de secretos de cualquier
  plataforma y sus socios; registros de uso, auditoría y facturación del
  emisor; alertas de gasto; servicios de *canary tokens*; búsqueda periódica
  propia de las llaves en buscadores, repositorios públicos o conjuntos de
  datos; combinación de varias fuentes.
- **Gestión.** Emisión, inerte y rotación automáticas mediante las APIs de
  los proveedores; declaración de los canales, las llaves y su registro en
  configuración declarativa (por ejemplo Nix) y en un gestor de secretos;
  recepción automática de los avisos (correo, *webhooks*) y su cruce con el
  registro para abrir la incidencia del canal; comprobación periódica de que
  cada canal sigue llevando su llave.
- **Prueba de controles.** El rechazo de una subida que contiene la llave
  (*push protection*) se usa también para comprobar que esa protección
  funciona, permitiendo la llave de miel de forma explícita donde se quiera
  dejar.

## 5. Antecedentes conocidos

Los *honeytokens* y *canary tokens* (credenciales falsas que avisan al ser
usadas, a través de una infraestructura de quien los coloca) y los programas
de escaneo de secretos con revocación por el emisor son conocidos. Lo que
este documento divulga es su combinación: credenciales **reales e inertes**
de un tercero cuyo aviso llega por la red de escaneo y por el registro de
uso del emisor, sin infraestructura propia; aplicadas al **contexto de las
sesiones y sistemas de IA** y a los almacenes de prompts; con una llave por
canal para saber qué se ha filtrado, y con la política para los agentes
propios del §3.3.

## 6. Implementación de referencia

Repositorio `https://github.com/AbstractBike/cristales`, documento
[`doc/llaves-de-miel.md`](../doc/llaves-de-miel.md), que la aplica a la
cantera de la forja y al archivo de la agencia del mismo repositorio.

---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Ver
[`COPYRIGHT.md`](../COPYRIGHT.md).
