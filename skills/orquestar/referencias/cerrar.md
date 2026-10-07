# Fusionar, limpiar y desplegar

## Fusionar

1. El agente dejó **todo commiteado** en su worktree (`git -C <worktree> status --short` vacío). Si
   dejó cambios sin commit y ya aprobaste el diff, commitéalos tú (es mecánico).
2. En el checkout principal no puede haber una copia sin trackear de un archivo que la rama trae
   (p. ej. un issue que escribiste y no commiteaste): el merge aborta con "would be overwritten".
3. `git merge --no-ff <rama>` con un mensaje que diga qué pieza entra.
4. Conflictos: resuélvelos tú si son pequeños (suele ser `index.ts` de exportaciones, tests al final
   del archivo, lockfile). Si el conflicto es de lógica entre dos piezas, decide cuál manda según la
   spec y deja ambos comportamientos que la spec pide.
5. **Verifica en la rama principal**, no en el worktree: instala dependencias si cambió el lockfile,
   regenera código generado (ORM, tipos de rutas) y corre tipos, lint, tests. Dos piezas que pasaban
   por separado pueden romperse juntas.
6. Marca el issue `Status: resolved (fusionado)` y actualiza `ESTADO.md`.

## Limpiar el worktree (siempre, justo después de fusionar)

Cada worktree lleva su propio `node_modules`: decenas se comen el disco y confunden cualquier limpieza.
La causa de la basura acumulada es casi siempre la misma: el agente escribe su log de progreso sin
trackear, el worktree queda "sucio" para siempre y ninguna limpieza se atreve a borrarlo.

Caso real: 95 worktrees acumulados en dos semanas (subagentes de Claude en `.claude/worktrees` y
agentes de Cursor en `~/.cursor/worktrees`) llenaron un disco de 475 GB; el aviso llegó cuando Claude
ya no podía guardar la conversación. La limpieza no es opcional ni "para después".

- Prevención (lo hace `/orquestador-setup`): `.gitignore` con `.scratch/**/logs/`,
  `.scratch/**/*progreso*`, `*.pid`.
- Guarda automática: `lanzar-agente` se niega a crear un worktree nuevo con menos de 10 GB libres
  (`ORQ_DISCO_MIN_GB` lo ajusta) y avisa a partir de 8 worktrees acumulados. `revisar-recursos` muestra
  disco libre y cantidad de worktrees. Los subagentes de Claude (`isolation: "worktree"`) no pasan por
  el lanzador: corre `revisar-recursos` antes de lanzarlos.
- Borrado seguro: `bash "<skill>/scripts/limpiar-worktrees.sh"` lista qué se puede borrar (rama ya
  fusionada + sin cambios en archivos trackeados) y con `--aplicar` lo borra. La rama se conserva salvo
  `--borrar-ramas`: borrar el worktree no pierde código. Cubre los worktrees de Cursor y los de Claude.
- Un worktree fusionado que solo tiene archivos sin trackear se conserva y se lista; tras revisarlos,
  `--incluir-sin-trackear` lo borra.
- Worktrees que aún no se pueden borrar (rama sin fusionar, trabajo a medias): `--aplicar --artefactos`
  vacía sus carpetas de compilación (`.next`, `dist`, `.turbo`…), que se regeneran solas y suelen ser
  lo que más pesa; `--con-dependencias` quita también `node_modules`.
- Carpetas huérfanas (git ya no las registra) se listan y no se borran solas: no hay rama que respalde
  su contenido.
- Windows: `git worktree remove` a veces quita el registro pero no el directorio (rutas largas). El
  script borra el resto con `rm -rf` en lotes de 8 y en primer plano; `robocopy /MIR` gasta demasiada
  memoria.

## Desplegar

- Solo lo que pasó la revisión y está fusionado. Primero **staging**, verificar salud, después
  producción. Nunca dos despliegues a la vez.
- Un despliegue determinístico (script con git/ssh/docker/curl) lo corres tú directo: no hay decisión que
  delegar y un agente en otra shell (p. ej. WSL) puede ver cambios fantasma de fin de línea.
- Antes de tocar variables de entorno en un servidor: respaldo con fecha del archivo; secretos generados
  en el propio servidor (`openssl rand -base64 32`) y nunca impresos (`sed 's/=.*/=<oculto>/'`).
- Migraciones: confirma que quedaron aplicadas consultando la tabla de migraciones, no solo el log.
- Verifica cada servicio nuevo por separado (el script de despliegue puede no conocerlo).
- Lo que requiere otra máquina o panel (DNS, proxy, tienda de apps, Meta…): lista numerada para el
  usuario, o pídeselo a otra sesión de Claude que tenga acceso, con respaldo, validación antes de
  aplicar, recarga en vez de reinicio y verificación de que lo existente sigue sano.
