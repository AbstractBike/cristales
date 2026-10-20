# El nucleador

> El agente que hace crecer la vitrina: una tarea madura por pasada.

Una vez al día, el servicio `nucleador` de nixos-config
(`modules/services/nucleador.nix`, en a1) pone el workbench
`/logical-node/workbench/cristales--nucleador` sobre `origin/main`, baja de la
forja a `/var/lib/nucleador/horno/` la ficha de cada tarea madura con sus 500
últimas muestras, y las muestras en el `.jsonl` de `medir` (por MCP no caben:
forja-mcp corta a los 5 s, y la semilla entera de memoria-escenas son 237 MB) y lanza `claude -p` con
[`prompts/nucleador.md`](../prompts/nucleador.md). El agente elige la tarea
madura que más tráfico ahorra, juzga si tiene un método, la nuclea (o sube de
versión su cristal con los campos maduros que aún no da), la mide contra la
cantera, la registra en la vitrina y commitea.

El servicio no se fía del agente: compila el paquete entero (`nix build`, con
la red de todos los cristales) y solo si compila sube la rama a `main` en
fast-forward. Si no, la deja en `nucleador/<fecha>` para que se mire.

Si lo subido toca la vitrina (un cristal nuevo o una versión), el servicio
lo lleva también a la forja: pone el input `cristales` de nixos-config en
`main`, sube el lock a master y despliega a2 en ventana (:20-:50 UTC, nunca
de 21:00 a 00:15 ni del miércoles 21Z al jueves 01Z). Solo si master no
lleva más cambios para a2 que nadie haya desplegado: si los lleva, el lock
queda subido y el aviso pide un despliegue a mano. Al acabar comprueba que la
forja sirve cada tarea registrada en la vitrina.

Cada pasada deja una fila aquí, también las que no nuclean nada: así la
siguiente no vuelve sobre una tarea rechazada mientras no haya más muestras.

## Pasadas

| Fecha | Tarea | Resultado | Campos (coincidencia) | Motivo |
|---|---|---|---|---|
| 2026-10-17 | t-a9fd1c2e9324 (oferta-trabajo, 5.566 muestras) | rechazada | — | Recristalización con los dos campos maduros que v2 no da, `companySize` y `languages`: ninguno tiene método. `companySize` gemma lo saca de lo que sabe de la empresa (Vattenfall, Zalando: «large» sin que la oferta lo diga); `languages` lo deduce del idioma de la oferta y lo nombra a su manera («Deutsch»/«German»), también en 146 ofertas sin ninguna palabra de idioma (medida de la semilla v2, 1.865 muestras). Sin muestras nuevas: `forja_tarea`, `forja_semilla` y `forja_nucleacion` dieron timeout, y el SQL directo a la cantera necesita una aprobación que en una pasada desatendida nadie da. Las demás: t-3df20b85d1d5 y t-cab6e50313a9 ya dan todos sus campos maduros; t-9cc62663051b (`tier`) es un juicio de encaje candidato-oferta, y el `score` de la entrada no lo decide (0,55 → TIER3, 0,53 → TIER2); memoria-escenas (`persona`) es casi siempre `""`, y la señal juzga si unos átomos cambian cómo se trabaja con el usuario: una constante que la entrada no sostiene. |
| 2026-10-17 | — | nada | — | Nada que nuclear. Maduras las mismas cinco que en la pasada anterior y con las mismas muestras: t-a9fd1c2e9324 (5.566), t-9cc62663051b (652) y memoria-escenas (4.163) se descartaron hoy y no han crecido un 50 %; t-3df20b85d1d5 y t-cab6e50313a9 ya dan con su cristal (ficha-empresa, oferta-trabajo) todos sus campos maduros. |
| 2026-10-18 | — | nada | — | Nada que nuclear. Maduras las mismas cinco: t-a9fd1c2e9324 (5.604, +0,7 %), t-9cc62663051b (652, +0 %) y memoria-escenas (4.165, +0,05 %) se rechazaron el 2026-10-17 y no han crecido un 50 %; t-3df20b85d1d5 y t-cab6e50313a9 piden los mismos campos maduros, que ya dan ficha-empresa y oferta-trabajo. |
| 2026-10-19 | — | nada | — | Nada que nuclear. Maduras tres: t-a9fd1c2e9324 (6.386, +14,7 % desde el rechazo del 2026-10-17 con 5.566) pide los mismos campos maduros, y los dos que oferta-trabajo no da (`companySize`, `languages`) siguen descartados; t-3df20b85d1d5 (241) y t-cab6e50313a9 (58) piden campos maduros que ya dan ficha-empresa y oferta-trabajo. t-9cc62663051b y memoria-escenas ya no salen en `forja_tareas`. |
| 2026-10-20 | — | nada | — | Nada que nuclear. Maduras las cinco: t-a9fd1c2e9324 (7.410, +33,1 % desde el rechazo del 2026-10-17 con 5.566) pide los mismos campos maduros; oferta-trabajo da todos menos `companySize` y `languages`, que siguen descartados. t-9cc62663051b (789, +21,0 % sobre 652) y memoria-escenas (4.185, +0,5 % sobre 4.163) vuelven a salir maduras, pero se rechazaron el 2026-10-17 y no han crecido un 50 %. t-3df20b85d1d5 (327) y t-cab6e50313a9 (58) piden campos maduros que ya dan ficha-empresa y oferta-trabajo. |
