# Cristalizar una pipeline de IA

Protocolo, etapa a etapa. Se aplica una y otra vez hasta que el grado de
cristalización deja de subir.

## 0. Partir de líquido

Toda etapa empieza líquida, y está bien: es la forma más rápida de saber si el
problema se puede resolver. Pero desde el primer día se **registra** cada
llamada: entrada, salida, modelo. Ese registro es la cantera de semillas.

## 1. Elegir la etapa

Se cristaliza primero la etapa que:

- más se ejecuta (más ahorro por cristal),
- tiene salida más cerrada (enumeración, esquema, formato),
- y cuyos errores son más fáciles de detectar.

## 2. Preparar la semilla

`SEMILLA.md` del cristal (ver [`anatomia.md`](anatomia.md)):

- qué hace la etapa, en una frase;
- el tipo de entrada y el de salida;
- 20–100 ejemplos reales sacados del registro, incluidos los raros;
- invariantes de la salida ("el importe es positivo", "la fecha existe en el
  calendario", "la etiqueta está en este conjunto");
- lo que debe quedar **fuera de dominio** (el cristal debe rechazarlo, no
  adivinarlo).

## 3. Nuclear

Se le pide al LLM el método con el prompt de
[`prompts/cristalizar.md`](../prompts/cristalizar.md). Lo que vuelve es código
más pruebas, y una lista explícita de los casos que el método no cubre.

Si el LLM no puede dar un método general, la etapa no está madura: se queda
líquida y se recogen más ejemplos.

## 4. Verificar la red

El cristal se acepta solo si:

- pasa todos los ejemplos de la semilla;
- cumple las invariantes sobre el registro completo (no solo los ejemplos);
- rechaza como defecto lo que está fuera de dominio;
- y, en lo que acepta, coincide con lo que respondía el líquido. Las
  discrepancias se revisan a mano: o el cristal tiene una impureza, o el
  líquido se equivocaba (pasa más de lo que parece).

## 5. Desplegar en mixto

La etapa pasa a `Mixta (cristal, liquido)`. El cristal atiende; los defectos
caen al LLM y se registran. Se mide el grado de cristalización.

## 6. Crecer

Periódicamente los defectos registrados se añaden a la semilla y se vuelve al
paso 3. El cristal nuevo tiene que pasar la red del anterior entera: la red
solo crece.

## 7. Solidificar

Cuando el grado de cristalización es ~1 y los defectos que quedan son
entradas que *deben* rechazarse, la etapa pasa a `Cristalina`. El LLM sale del
camino de ejecución. Un defecto en una etapa cristalina es un error visible,
no una llamada silenciosa al modelo.

## 8. Fundir cuando toque

Si el grado de cristalización cae de golpe, el dominio ha cambiado. Se vuelve
a mixto (o a líquido) sin dramas: la procedencia y la semilla antiguas siguen
en git para la siguiente nucleación.

## La pipeline entera

Una pipeline se describe como composición de etapas, y su estado es el de cada
una:

```
correo ──► [idioma: cristal] ──► [tipo: mixta 0.97] ──► [extraer: mixta 0.88] ──► [responder: líquida]
```

La pipeline está cristalizada cuando solo quedan líquidas las etapas que son
abiertas por naturaleza, y estas tienen el hueco líquido lo más pequeño
posible. En OCaml, con [`lib/cristal.mli`](../lib/cristal.mli):

```ocaml
let pipeline =
  Cristal.(idioma >>> tipo >>> extraer >>> responder)
```


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Libre para investigación y docencia sin ánimo de lucro, citando al autor; para uso comercial, escríbeme a silvio.macias.sanchez@abstract.bike o info@abstractarchitectures.ltd. Ver [COPYRIGHT.md](../COPYRIGHT.md).
