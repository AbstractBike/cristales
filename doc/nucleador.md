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
fast-forward. Si no, la deja en `nucleador/<fecha>` para que se mire. Lo que
llega a `main` todavía no atiende tráfico: la forja de a2 lo recoge con
`nix flake update cristales` y su despliegue, que siguen siendo de una
persona.

Cada pasada deja una fila aquí, también las que no nuclean nada: así la
siguiente no vuelve sobre una tarea rechazada mientras no haya más muestras.

## Pasadas

| Fecha | Tarea | Resultado | Campos (coincidencia) | Motivo |
|---|---|---|---|---|
| 2026-10-17 | t-a9fd1c2e9324 (oferta-trabajo, 5.566 muestras) | rechazada | — | Recristalización con los dos campos maduros que v2 no da, `companySize` y `languages`: ninguno tiene método. `companySize` gemma lo saca de lo que sabe de la empresa (Vattenfall, Zalando: «large» sin que la oferta lo diga); `languages` lo deduce del idioma de la oferta y lo nombra a su manera («Deutsch»/«German»), también en 146 ofertas sin ninguna palabra de idioma (medida de la semilla v2, 1.865 muestras). Sin muestras nuevas: `forja_tarea`, `forja_semilla` y `forja_nucleacion` dieron timeout, y el SQL directo a la cantera necesita una aprobación que en una pasada desatendida nadie da. Las demás: t-3df20b85d1d5 y t-cab6e50313a9 ya dan todos sus campos maduros; t-9cc62663051b (`tier`) es un juicio de encaje candidato-oferta, y el `score` de la entrada no lo decide (0,55 → TIER3, 0,53 → TIER2); memoria-escenas (`persona`) es casi siempre `""`, y la señal juzga si unos átomos cambian cómo se trabaja con el usuario: una constante que la entrada no sostiene. |
| 2026-10-17 | — | nada | — | Nada que nuclear. Maduras las mismas cinco que en la pasada anterior y con las mismas muestras: t-a9fd1c2e9324 (5.566), t-9cc62663051b (652) y memoria-escenas (4.163) se descartaron hoy y no han crecido un 50 %; t-3df20b85d1d5 y t-cab6e50313a9 ya dan con su cristal (ficha-empresa, oferta-trabajo) todos sus campos maduros. |
