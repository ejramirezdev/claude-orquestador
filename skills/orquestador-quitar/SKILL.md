---
name: orquestador-quitar
description: Deshace /orquestador-setup en el proyecto actual (quita el bloque del CLAUDE.md y las líneas del .gitignore) y explica cómo pausar o desinstalar el plugin. No borra código.
disable-model-invocation: true
---

# Quitar el modo orquestador de este proyecto

Deja el proyecto como estaba antes de `/orquestador-setup`, sin tocar código ni ramas. Informa cada
paso en una línea.

1. **Agentes vivos.** Revisa si hay agentes de Cursor lanzados desde este proyecto que sigan corriendo
   (`git worktree list` + los logs `…-cursor.out` sin línea `fin`). Si los hay, dile al usuario cuáles y
   pregúntale si esperar a que terminen o detenerlos. No sigas hasta que responda.
2. **`CLAUDE.md`.** Borra todo lo que hay entre `<!-- orquestador:inicio -->` y
   `<!-- orquestador:fin -->`, marcadores incluidos, y nada más. Si el archivo queda vacío y no existía
   antes del setup (`git log --diff-filter=A -- CLAUDE.md` muestra el commit del setup), bórralo.
   Si no encuentras los marcadores, muestra al usuario la sección `## Orquestador` que encuentres y
   pregunta antes de tocarla.
3. **`.gitignore`.** Borra las líneas entre `# orquestador:inicio` y `# orquestador:fin`, marcadores
   incluidos.
4. **Worktrees.** Corre `../orquestar/scripts/limpiar-worktrees.sh` (relativo a la carpeta de esta skill) sin `--aplicar` y muestra
   la lista. Borra solo si el usuario lo confirma. Las ramas y el código fusionado quedan intactos.
5. **`.scratch/`.** Las specs, issues y `ESTADO.md` son documentación del proyecto: no las borres salvo
   que el usuario lo pida.
6. **Commit** de `CLAUDE.md` y `.gitignore` con el mensaje "Quita el modo orquestador".

Al final, dile al usuario cómo seguir según lo que quiera:

- **Pausar en todos los proyectos** (se puede reactivar): `/plugin disable orquestador@orquestador`
  y luego `/plugin enable orquestador@orquestador`. Con el plugin desactivado, los proyectos que aún
  tengan el bloque en su `CLAUDE.md` trabajan de forma normal, porque el bloque lo indica.
- **Desinstalar del todo:** `/plugin uninstall orquestador@orquestador` y, si no quiere recibir
  actualizaciones, `/plugin marketplace remove orquestador`. El plugin no instala hooks, no cambia la
  configuración de Claude Code ni deja procesos: lo único que queda en cada proyecto es lo que acabas de
  quitar.
