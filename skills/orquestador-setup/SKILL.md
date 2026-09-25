---
name: orquestador-setup
description: Prepara un proyecto (y la máquina) para trabajar en modo orquestador con agentes de Cursor. Correr una vez por proyecto, o de nuevo para cambiar modelos.
disable-model-invocation: true
---

# Preparar el modo orquestador

Deja el proyecto listo para la skill `orquestar`. Cada paso termina con su comprobación; informa al
usuario el resultado de cada uno en una línea y pide solo lo que no puedas hacer tú.

1. **Cursor CLI.** `cursor-agent --version` (en Windows, desde la herramienta PowerShell) y
   `cursor-agent models`. Si no está instalado o no hay sesión, dale al usuario los pasos (instalar
   Cursor CLI desde la documentación de Cursor y `cursor-agent login`) y espera.
   Hecho cuando: `cursor-agent models` lista modelos.
2. **Modelos.** Muestra los modelos disponibles y pregunta cuál usar para piezas **complejas** y cuál
   para **sencillas** (recomendación: el más fuerte de razonamiento para complejas, uno rápido para
   sencillas; `auto` como respaldo cuando se acabe el cupo).
   Hecho cuando: el usuario eligió los dos.
3. **Bloque en `CLAUDE.md`** del proyecto, entre los marcadores exactos de abajo (créalo si no existe; si
   los marcadores ya están, reemplaza lo que hay entre ellos y no toques nada fuera):

   ```markdown
   <!-- orquestador:inicio -->
   ## Orquestador

   En este proyecto Claude es líder técnico (skill `orquestar`): planifica, delega cada pieza a un agente
   de Cursor CLI en su propio worktree, lo vigila, revisa el diff y fusiona solo lo aprobado. No implementa
   código salvo cambios triviales (typo, constante, texto de una línea, conflicto de merge).
   Si la skill `orquestar` no está disponible (plugin desactivado o desinstalado), ignora este bloque y
   trabaja de forma normal.

   | Pieza | Modelo |
   |---|---|
   | Compleja (lógica nueva, varias partes del código, diseño, seguridad) | `<modelo complejo>` |
   | Sencilla (cambio mecánico, correr un script, commit) | `<modelo sencillo>` |
   | Sin cupo en Cursor | `auto` para todo hasta nuevo aviso |

   - Agentes en paralelo: máximo <N> (según la RAM de esta máquina); verificar UNO A LA VEZ.
   - Rama principal: `<rama>`. Verificaciones del proyecto: `<comandos exactos, en orden>`.
   - Despliegue: `<cómo, o "no aplica">`. Siempre staging antes que producción, uno a la vez.
   - Specs e issues en `.scratch/<feature>/`; estado para retomar en `.scratch/<feature>/ESTADO.md`.
   <!-- orquestador:fin -->
   ```

   Rellena los `<…>` mirando el repositorio (`package.json`, scripts, CI, README) y la RAM
   (`../orquestar/scripts/revisar-recursos`, relativo a la carpeta de esta skill); pregunta solo lo que no se pueda deducir.
   Hecho cuando: el bloque no tiene ningún `<…>` sin rellenar.
4. **`.gitignore`**: agrega (si faltan) estas líneas, para que los logs de los agentes no dejen los
   worktrees "sucios" y la limpieza pueda borrarlos:

   ```
   # orquestador:inicio
   .scratch/**/logs/
   .scratch/**/*progreso*
   *.pid
   # orquestador:fin
   ```
   Hecho cuando: `git check-ignore .scratch/x/logs/01-progreso.md` imprime la ruta.
5. **Git.** El proyecto es un repositorio con al menos un commit en la rama principal y `git worktree
   list` funciona. Si hay worktrees viejos, corre `../orquestar/scripts/limpiar-worktrees.sh` (sin `--aplicar`) y
   muéstrale al usuario la lista.
6. **Máquina** (informa, no cambies nada sin permiso):
   - RAM y memoria del kernel con `../orquestar/scripts/revisar-recursos.ps1` (Windows) o `.sh`.
   - Recomienda iniciar Claude Code con `CLAUDE_CODE_DISABLE_BG_SHELL_PRESSURE_REAP=1` si la máquina tiene
     16 GB o menos: evita que Claude Code mate a los agentes cuando la memoria aprieta.
   - Windows con antivirus que intercepta TLS: si `cursor-agent` falla con errores de certificado,
     `NODE_EXTRA_CA_CERTS` debe apuntar al certificado raíz del antivirus.
7. **Commit** del `CLAUDE.md` y el `.gitignore` en la rama principal (los worktrees nacen de ahí).

Al final, resume en 3-4 líneas cómo quedó y cómo empezar: "Pídeme una tarea; la planifico y la delego."
Menciona que `/orquestador-quitar` deshace esta preparación en el proyecto.
