# Prompt de nucleación

Plantilla para pedirle a un LLM **el método, no el resultado**. Se rellenan los
huecos `{{…}}` con la semilla.

---

No quiero que resuelvas estos casos. Quiero el **programa** que los resuelve
todos, para no tener que volver a preguntarte.

## Problema

{{descripción en una frase}}

- Entrada: {{tipo de entrada}}
- Salida: {{tipo de salida}}

## Ejemplos

{{pares entrada → salida, incluidos los raros}}

## Invariantes

Toda salida debe cumplir:

{{lista de invariantes}}

## Fuera de dominio

Estas entradas deben **rechazarse**, no adivinarse:

{{lista o descripción}}

## Lo que tienes que entregar

1. Una función pura en OCaml 5, sin dependencias de red, reloj ni
   aleatoriedad, con firma
   `val aplicar : {{entrada}} -> ({{salida}}, defecto) result`.
   Todo lo que necesite del entorno lo recibe como argumento.
2. Para cada entrada que no sepas tratar con seguridad, devuelve `Error`
   con un motivo. Prefiero un defecto a una respuesta inventada.
3. Pruebas que cubran todos los ejemplos de arriba y comprueben las
   invariantes.
4. Una lista explícita de los casos que tu método **no** cubre y por qué.
5. Si este problema no admite un método general, dilo y explica qué ejemplos
   faltarían para que lo admitiera. No me des un programa que en el fondo
   sea una tabla de los ejemplos.


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Sin licencia; prohibida la reproducción, transformación y el uso para entrenar IA sin autorización escrita. Ver [COPYRIGHT.md](../COPYRIGHT.md).
