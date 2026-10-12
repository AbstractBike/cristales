# Semilla: t-5675e2af041b

Tarea que atendía el LLM a través de la forja. Sus instrucciones (la plantilla) eran:

~~~~
Extrae en mayúsculas.

## Esquema

{"name":"mayus","schema":{"type":"object"},"strict":true}
~~~~

- Entrada: texto (lo que variaba en cada llamada).
- Salida: un objeto JSON (ver Campos).

Cantera: 3 muestras; el LLM repitió la respuesta en 1 de 1 contrastes.

## Campos

La salida es un objeto JSON. Veces que el LLM repitió cada campo al preguntarle dos veces:

- `mayus`: 1 de 1

El cristal no tiene que darlos todos: puede devolver un objeto con solo los campos que sabe sacar, y la forja le pide al LLM el resto (x-forja-fuente: parcial). Empieza por los que el LLM repite: esos tienen un método que dar. Los que no repite, déjaselos.

## Ejemplos

### 1

Entrada:

~~~~
uno
~~~~

Salida:

~~~~
{"mayus":"UNO"}
~~~~

### 2

Entrada:

~~~~
dos
~~~~

Salida:

~~~~
{"mayus":"DOS"}
~~~~

### 3

Entrada:

~~~~
tres
~~~~

Salida:

~~~~
{"mayus":"TRES"}
~~~~

## Invariantes

Por declarar en la nucleación.

## Fuera de dominio (defecto)

Por declarar en la nucleación.
