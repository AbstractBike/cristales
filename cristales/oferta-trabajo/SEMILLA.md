# Semilla: oferta-trabajo

La extracción de trabajo.email (`ExtractionAgent` de trabajo-kt, por
buzon-kt): de una oferta rastreada, 14 campos en un objeto JSON. En la forja
es la tarea `t-a9fd1c2e9324` (el digest de su prompt y su esquema), por Chat
Completions con `json_schema` contra gemma-4-12b; antes de este cristal, el
grueso de lo que se repetía en la flota.

- Entrada: el mensaje de la extracción, con la oferta entre `<posting>` y
  `</posting>` en líneas `URL:`, `Title:`, `Company:`, `Location:` y
  `Description:` (hasta el final).
- Salida: un objeto JSON con **solo los campos que el cristal sabe** de esa
  oferta (un cristal parcial, doc/forja.md «Campo a campo»); la forja le
  pide a gemma el resto.

## Por qué parcial

El objeto entero no madura: gemma lo repetía en 54 de 80 contrastes (67 %).
Campo a campo, sí:

| Campo | Repetido por gemma | |
|---|---|---|
| salaryMin, salaryMax, salaryCurrency, salaryPeriod, workMode, seniority, yoeMin, yoeMax, isAgency, isEasyApply | 80 de 80 | |
| companySize | 79 | |
| languages | 77 | |
| contractType | 76 | |
| hardSkills | 61 | se queda en el LLM |

Que el LLM repita un campo dice que tiene un método; no que el método sea de
reglas. El cristal da los campos que una regla decide con precisión y deja
el resto, aunque sean estables (`isAgency`, `companySize`, `contractType`
piden criterio; `languages` gemma lo deduce del idioma de la oferta y lo
nombra a su manera: «Deutsch» o «German», «Dansk» o «Danish»).

## Reglas

| Campo | Regla | Da | Coincide con gemma |
|---|---|---|---|
| salaryMin/Max/Currency/Period | Sin ninguna señal de dinero (símbolos, monedas, «salary», «Gehalt», «løn», «60k»…), los cuatro `null` | 61 % | 99,8–100 % |
| yoeMin, yoeMax | Sin ninguna palabra de años («years», «Jahre», «años», «år»…), `null` | 60 % | 98,6–99,8 % |
| isEasyApply | `true` si el texto dice «easy apply»; si no, `false` | 100 % | 99,4 % |
| seniority | Por el título: principal (o senior staff), lead (lead, director, head), senior, junior, entry (prácticas, Werkstudent); con «mid» o sin ninguna, nada | 33 % | 98,2 % |
| workMode | Sin ninguna señal de remoto, híbrido, home office, flexible o móvil en la oferta, `onsite` (la regla del propio prompt) | 45 % | 98,9 % |

Medido contra las 804 salidas de gemma con `test/medir.exe`. Las
discrepancias que quedan son sobre todo de gemma: `isEasyApply` a `true` en
ofertas de smartrecruiters que no lo dicen, años o moneda que la oferta no
da.

## Invariantes

- Solo campos de la extracción; nunca hardSkills, languages, contractType,
  isAgency ni companySize.
- `seniority` y `workMode`, dentro de sus enumeraciones.
- Una señal de duda (dinero, años, remoto) quita el campo: el cristal calla
  antes que equivocarse.

## Fuera de dominio (defecto)

Un mensaje sin `<posting>`.

## Recristalizar

Las muestras parciales quedan en la cantera con `parcial: faltan …`. Con un
prompt nuevo en trabajo-kt la tarea cambia de digest y vuelve a ser líquida:
o se registra el cristal con la nueva, o trabajo-kt manda `x-forja-tarea`.
