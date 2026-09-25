# Lanzar agentes

## Elegir modelo

La tabla vigente vive en el bloque `## Orquestador` del `CLAUDE.md` del proyecto (la escribe
`/orquestador-setup`). Por defecto:

| Tipo de pieza | Ejemplos | Modelo |
|---|---|---|
| **Compleja** | lógica nueva, varias partes del código a la vez, diseño, seguridad, IA | el modelo fuerte (p. ej. `grok-4.7-high`) |
| **Sencilla** | cambio mecánico de una pieza, correr un script ya escrito, commit, renombrar | el modelo rápido (p. ej. `composer-2.5`) |
| **Sin cupo** | Cursor responde `You're out of usage` | `auto` para todo, hasta que el usuario diga otra cosa |

Ante la duda, _compleja_: rehacer un diff malo cuesta más que el modelo caro.
Lista real de modelos de la cuenta: `cursor-agent models`. Una corrección vuelve al **mismo** agente
con el **mismo** modelo.

## Cuántos a la vez

Cada agente corre instalaciones, verificaciones de tipos y compilaciones: en una laptop de 16 GB, dos
agentes que compilan a la vez ya pueden agotar la RAM. Antes de lanzar, corre `scripts/revisar-recursos`
y decide:

- **≥ 8 GB libres:** hasta 3 en paralelo si sus archivos son disjuntos.
- **4–8 GB:** 1 o 2, y pídeles verificar UNO A LA VEZ y sin compilación completa salvo al final.
- **< 4 GB:** 1, y resuelve primero la causa (ver `problemas-conocidos.md`, "memoria").

Despliegues y todo lo que toque un recurso compartido (servidor, base de datos): **siempre de a uno**.

## Cómo lanzar

1. Escribe el prompt en `.scratch/<feature>/logs/NN-lanzar.md` (plantilla en `plantillas.md`). Nunca un
   prompt largo inline: el shell corta o interpreta caracteres (`$`, comillas).
2. Comprueba que el issue y la spec están **commiteados** en la rama principal.
3. Lanza en segundo plano (`run_in_background`):
   - Windows (herramienta PowerShell):
     `& "<skill>/scripts/lanzar-agente.ps1" -Nombre dp-NN-slug -Modelo <modelo> -PromptFile .scratch/<feature>/logs/NN-lanzar.md`
     Para retomar un worktree existente: `-Worktree "<ruta>"` en vez de crear uno nuevo.
   - macOS/Linux: `bash "<skill>/scripts/lanzar-agente.sh" --nombre dp-NN-slug --modelo <modelo> --prompt-file <ruta> [--worktree <ruta>]`
   El script escribe `inicio` y `fin exit=N` en `<prompt>-cursor.out` (p. ej.
   `logs/NN-lanzar-cursor.out`; o el que pases con `-Log`/`--log`) y deja su PID en `<log>.pid`.
   El worktree nuevo lo crea Cursor; su ruta real sale en `git worktree list` (en Windows suele ser
   `%USERPROFILE%\.cursor\worktrees\<repo>\<nombre>`).
4. ~30 s después confirma que el worktree existe (`git worktree list`) y que el log tiene `inicio`.
   Si no, ver "no arranca" en `problemas-conocidos.md`.
5. Arranca el vigía (`vigilar.md`) antes de seguir con otra cosa.

## Retomar trabajo a medias

Un agente muerto (memoria, cupo, colgado) deja su trabajo sin commit en el worktree. No lo tires:
relánzalo con `-Worktree <ruta>` y el prompt de "retomar" de `plantillas.md` (commit WIP → merge de la
rama principal → terminar). Si otra pieza se fusionó mientras tanto, ese merge evita conflictos al final.

## Alternativas cuando Cursor no está disponible

Si el usuario lo autoriza: subagentes de Claude en worktree aislado (herramienta Agent con
`isolation: "worktree"` y un modelo más barato). Tienen su propio límite de uso por sesión: si también
se cortan, retoma en el mismo worktree con Cursor `auto`.
