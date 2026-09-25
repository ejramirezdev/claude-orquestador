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

- Prevención (lo hace `/orquestador-setup`): `.gitignore` con `.scratch/**/logs/`,
  `.scratch/**/*progreso*`, `*.pid`.
- Borrado seguro: `bash "<skill>/scripts/limpiar-worktrees.sh"` lista qué se puede borrar (rama ya
  fusionada + árbol limpio o solo archivos ignorados) y con `--aplicar` lo borra. La rama se conserva:
  borrar el worktree no pierde código.
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
