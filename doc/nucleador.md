# El nucleador

> El agente que hace crecer la vitrina: una tarea madura por pasada.

Una vez al día, el servicio `nucleador` de nixos-config
(`modules/services/nucleador.nix`, en a1) pone el workbench
`/logical-node/workbench/cristales--nucleador` sobre `origin/main` y lanza
`claude -p` con [`prompts/nucleador.md`](../prompts/nucleador.md): elige la
tarea madura de la forja que más tráfico ahorra, juzga si tiene un método,
la nuclea (o sube de versión su cristal con los campos maduros que aún no da),
la mide contra la cantera, la registra en la vitrina y commitea.

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
