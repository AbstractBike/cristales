No quiero que resuelvas estos casos. Quiero el **programa** que los resuelve
todos, para no tener que volver a preguntarte.

## Problema

Lo que hacía el LLM con estas instrucciones:

~~~~
Pon en mayúsculas.
~~~~

- Entrada: texto
- Salida: texto

## Ejemplos

### 1

Entrada:

~~~~
uno
~~~~

Salida:

~~~~
UNO
~~~~

### 2

Entrada:

~~~~
dos
~~~~

Salida:

~~~~
DOS
~~~~

### 3

Entrada:

~~~~
tres
~~~~

Salida:

~~~~
TRES
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
