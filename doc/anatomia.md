# Anatomía de un cristal

Cada cristal es un directorio bajo `cristales/<nombre>/`:

```
cristales/<nombre>/
├── SEMILLA.md        problema, tipos, ejemplos, invariantes, fuera de dominio
├── procedencia.sexp  modelo, prompt, fecha y versión de la nucleación
├── dune
├── <nombre>.ml       el cristal: función pura, devuelve resultado o defecto
├── <nombre>.mli
└── test/
    ├── dune
    └── red.ml        la red cristalina: ejemplos de la semilla + invariantes
```

## Reglas

- **El cristal es puro.** Sin red, sin reloj, sin aleatoriedad, sin LLM. Si
  necesita contexto (la fecha de hoy, una tabla), lo recibe como argumento.
- **El defecto es parte del tipo.** `aplicar : entrada -> (salida, defecto) result`.
  Nada de excepciones para "no sé".
- **La semilla y la procedencia se commitean.** Sin ellas el cristal no se
  puede recristalizar; sería código huérfano.
- **La red solo crece.** Un caso que entró en la red no se borra; si el
  dominio lo contradice, eso es una fusión y se documenta en la semilla.
- **El código generado se lee.** Que lo haya escrito un LLM no lo exime de
  revisión. El cristal es tuyo desde que se commitea.

## procedencia.sexp

```lisp
((cristal fecha-es)
 (version 1)
 (modelo claude-opus-5-5)
 (prompt prompts/cristalizar.md)
 (semilla cristales/fecha-es/SEMILLA.md)
 (fecha 2026-10-11))
```


---

© 2026 Silvio Macías Sánchez. Todos los derechos reservados. Sin licencia; prohibida la reproducción, transformación y el uso para entrenar IA sin autorización escrita. Ver [COPYRIGHT.md](../COPYRIGHT.md).
