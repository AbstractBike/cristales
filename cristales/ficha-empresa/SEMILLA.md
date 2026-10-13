# Semilla: ficha-empresa

La ficha de empresa para un headhunter: de un bloque `<evidence>` con el
nombre de una empresa, las ubicaciones vistas, los títulos de sus ofertas y
un extracto de una de ellas, el LLM rellena la herramienta forzada
`company_profile` (13 campos). En la forja es la tarea `t-3df20b85d1d5` (el
digest de su prompt y su esquema).

- Entrada: el mensaje con la evidencia entre `<evidence>` y `</evidence>`,
  en líneas `Empresa:`, `Ubicaciones vistas:` (separadas por `·` o `;`),
  `Ofertas suyas vistas:` (una por línea, `- …`) y `Extracto de una de sus
  ofertas:` (hasta el final).
- Salida: un objeto JSON con **solo los campos que la evidencia sostiene**
  (un cristal parcial, doc/forja.md «Campo a campo»); la forja le pide al LLM
  el resto.

## Por qué tan parcial

Campo a campo, el LLM repitió en 15 contrastes:

| Campo | Repetido | |
|---|---|---|
| website | 15 | maduro |
| hqCountry, hqCountryEn, remotePolicy, sizeBucket | 14 | maduros |
| hqCity, redFlags | 12 | |
| sectorEn, techStack | 8 | |
| confidence | 7 | |
| sector | 6 | |
| summary, summaryEn | 0 | |

Que el LLM se repita no quiere decir que lo saque del texto. La plantilla le
deja usar «conocimiento sólido y concreto de esa empresa», y lo usa: de las
81 webs que da en la semilla, 73 no aparecen en la evidencia (flosum.com,
getyourguide.com con solo getyourguide.careers en el texto); la sede de
Flosum, JetBrains o Typeform sale de lo que sabe de ellas, no del anuncio
(JetBrains: «Headquarters: Berlin, Germany…» en el texto y República Checa
en la ficha); el tamaño, igual (1000+ de GetYourGuide sin una cifra en la
evidencia). Un cristal puro no sabe nada del mundo: de cada campo maduro da
solo el caso en que la evidencia lo dice, y en el resto calla y lo pide la
forja. Callar no es `""`: `""` diría «no se sabe», y el LLM sí lo sabe.

## Reglas

| Campo | Regla | Da | Coincide con el LLM |
|---|---|---|---|
| remotePolicy | `remote` si todas las ubicaciones vistas (y las de una cabecera `Headquarters:`/`Location:` del extracto) dicen remote, remoto, worldwide o anywhere, y ni los títulos ni el extracto hablan de hybrid, office, oficina, presencial, onsite, Büro o bureau. `onsite` si todas dicen «(Presencial)» y nada habla de remoto ni híbrido. Lo demás (ciudades a secas, mezclas), el LLM | 98 de 165 (59 %): 88 remote, 10 onsite | 96 (98,0 %) |
| website | Un dominio que aparece en la evidencia, fuera de un correo, que no es de empleo (`.careers`, `.jobs`) y que es el nombre de la empresa sin su forma jurídica (`intellectsoft.net` de Intellectsoft, `sanctuary.computer` de Sanctuary Computer) o está en él (`Smartly.io Solutions GmbH`). Etiqueta de al menos tres letras. Uno solo; con dos, nada | 8 (5 %) | 8 (100 %) |
| hqCountry, hqCountryEn | La sede dicha en primera persona («our Berlin HQ», «our headquarters on Zürich’s…», «headquartered in Amsterdam, we…», «nuestra sede en…»), con el lugar en una tabla pequeña de ciudades y países (dentro del cristal) que da el país en español y en inglés. Un solo país; con dos, nada | 3 (2 %) | 3 (100 %) |
| sizeBucket | Una plantilla dicha: un número seguido de employees, colleagues, professionals, empleados, Mitarbeiter, staff, team members…; o de people/personas tras «we're», «we are», «somos». Un rango («3-5 engineers») no; una sola franja | 5 (3 %) | 5 (100 %) |

Medido contra las 165 fichas de la semilla con `test/medir.exe` (las
muestras no se commitean). En 104 fichas da algún campo; en 61, ninguno, y
es un defecto («la evidencia no sostiene ningún campo»): la forja se la pide
entera al LLM.

Las dos discrepancias de `remotePolicy`:

- MICHAEL PAGE, «Remoto - España» y «100% remoto» en el título: el LLM dice
  `unknown`, quizá porque es una consultora de selección y el remoto es del
  cliente. El cristal dice lo que dice la oferta.
- Diabolocom, «Remote - Paris, France» y «flexible work arrangements»: el LLM
  lo lee como `hybrid`. Bloquear «flexible» quitaba 8 remotos buenos por uno.

## Campos maduros que no da (o casi nunca)

- **hqCountry/hqCountryEn** fuera de una sede en primera persona: el LLM la
  saca de lo que sabe de la empresa, y el texto la contradice a menudo. Un
  `Headquarters:` de portal es la lista de ubicaciones de la oferta (JetBrains
  → República Checa, Typeform → España en la ficha); una sede en tercera
  persona puede ser de una filial («Headquartered in Nashville…, BMG» en una
  ficha de Bertelsmann, Alemania). Las ubicaciones vistas tampoco: una oferta
  en Berlín no hace alemana a la empresa.
- **website** que no aparece en la evidencia: 73 de las 81 webs del LLM.
- **sizeBucket** sin cifra: 47 «1000+» del LLM, casi todos de memoria.
- **remotePolicy** con ciudades a secas: el LLM dice `unknown`, `hybrid`,
  `onsite` o `remote` según lo que lea en el extracto, sin una regla que se
  vea (los 24 `unknown` son casi todos de este grupo).

## Invariantes

- Solo campos de la ficha; nunca confidence, hqCity, redFlags, sector,
  sectorEn, summary, summaryEn ni techStack.
- `remotePolicy` en {remote, onsite} (de su enumeración); `sizeBucket` en
  sus franjas.
- `hqCountry` y `hqCountryEn` van juntos, de la misma entrada de la tabla.
- `website` sin protocolo, sin `www.`, sin ruta.
- Una duda (dos países, dos franjas, dos dominios, una oficina en un
  remoto) quita el campo: el cristal calla antes que equivocarse.

## Fuera de dominio (defecto)

- Un mensaje sin `<evidence>` o sin `Empresa:`.
- Una evidencia que no sostiene ningún campo.

## Lo que no cubre

- Las sedes en ciudades fuera de la tabla (Nashville, Gütersloh): se
  amplía la tabla, no se adivina.
- Las ubicaciones en otros idiomas que «remoto»/«remote» («Télétravail»,
  «Fernarbeit»): no salen en la semilla.
- Una plantilla dicha en palabras («a few hundred people») o en otra forma
  («headcount of 300»).
- Los textos de las ofertas son de terceros: si traen órdenes para una IA,
  el cristal no las lee como órdenes; solo busca sus patrones.

## Recristalizar

Las muestras parciales quedan en la cantera con `parcial: faltan …`, y las
que no sostienen nada con su defecto. Con un prompt nuevo la tarea cambia de
digest y vuelve a ser líquida: o se registra el cristal con la nueva, o el
cliente manda `x-forja-tarea`.
