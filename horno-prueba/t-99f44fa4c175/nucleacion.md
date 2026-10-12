No quiero que resuelvas estos casos. Quiero el **programa** que los resuelve
todos, para no tener que volver a preguntarte.

## Problema

Lo que hacía el LLM con estas instrucciones:

~~~~
Dos campos.

## Esquema

{"name":"dos","schema":{"additionalProperties":false,"properties":{"a":{"type":"string"},"b":{"type":"string"}},"required":["a","b"],"type":"object"},"strict":true}
~~~~

La salida es un objeto JSON. Veces que el LLM repitió cada campo al preguntarle dos veces:

- `a`: 1 de 1
- `b`: 1 de 1

El cristal no tiene que darlos todos: puede devolver un objeto con solo los campos que sabe sacar, y la forja le pide al LLM el resto (x-forja-fuente: parcial). Empieza por los que el LLM repite: esos tienen un método que dar. Los que no repite, déjaselos.

- Entrada: texto
- Salida: un objeto JSON, con todos sus campos o solo los que sepas

## Ejemplos

### 1

Entrada:

~~~~
uno
~~~~

Salida:

~~~~
{"a":"a:UNO","b":"b:UNO"}
~~~~

### 2

Entrada:

~~~~
dos
~~~~

Salida:

~~~~
{"a":"a:DOS","b":"b:DOS"}
~~~~

### 3

Entrada:

~~~~
tres
~~~~

Salida:

~~~~
{"a":"a:TRES","b":"b:TRES"}
~~~~

## Invariantes

Toda salida debe cumplir:

No las conozco: dedúcelas de la plantilla y los ejemplos y decláralas explícitamente en tu respuesta.

## Fuera de dominio

Estas entradas deben **rechazarse**, no adivinarse:

No las conozco: dedúcelas de la plantilla y los ejemplos y decláralas explícitamente en tu respuesta.

## Lo que tienes que entregar

1. Una función pura en OCaml 5, sin dependencias de red, reloj ni
   aleatoriedad, con firma
   `val aplicar : string -> (string, defecto) result`.
   Todo lo que necesite del entorno lo recibe como argumento.
2. Para cada entrada que no sepas tratar con seguridad, devuelve `Error`
   con un motivo. Prefiero un defecto a una respuesta inventada.
3. Pruebas que cubran todos los ejemplos de arriba y comprueben las
   invariantes.
4. Una lista explícita de los casos que tu método **no** cubre y por qué.
5. Si este problema no admite un método general, dilo y explica qué ejemplos
   faltarían para que lo admitiera. No me des un programa que en el fondo
   sea una tabla de los ejemplos.
