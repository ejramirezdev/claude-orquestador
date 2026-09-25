#!/usr/bin/env bash
# Lista (y con --aplicar, borra) los worktrees que ya no hacen falta.
# Criterio seguro: la rama del worktree está fusionada en la rama principal Y el worktree no tiene
# cambios, salvo archivos ignorados por .gitignore. Las ramas se conservan: no se pierde código.
#
#   bash limpiar-worktrees.sh [--rama-principal master] [--aplicar]
#
# Correr desde la raíz del repositorio principal, en primer plano.
set -uo pipefail

principal="" aplicar=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rama-principal) principal="$2"; shift 2 ;;
    --aplicar) aplicar=1; shift ;;
    *) echo "argumento desconocido: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$principal" ]; then
  principal=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
  [ -n "$principal" ] || principal=$(git rev-parse --abbrev-ref HEAD)
fi
raiz=$(git rev-parse --show-toplevel)

borrables=() conservar=()
while IFS= read -r linea; do
  case "$linea" in
    "worktree "*) ruta="${linea#worktree }" ;;
    "branch "*)
      rama="${linea#branch refs/heads/}"
      [ "$(cd "$ruta" 2>/dev/null && pwd -P)" = "$(cd "$raiz" && pwd -P)" ] && continue
      if ! git merge-base --is-ancestor "$rama" "$principal" 2>/dev/null; then
        conservar+=("$ruta  [rama $rama sin fusionar en $principal]"); continue
      fi
      sucio=$(git -C "$ruta" status --porcelain 2>/dev/null | head -5)
      if [ -n "$sucio" ]; then
        conservar+=("$ruta  [cambios sin commit: $(echo "$sucio" | tr '\n' ' ')]"); continue
      fi
      borrables+=("$ruta|$rama") ;;
  esac
done < <(git worktree list --porcelain)

echo "Rama principal: $principal"
echo "Se conservan (${#conservar[@]}):"; for c in "${conservar[@]}"; do echo "  - $c"; done
echo "Se pueden borrar (${#borrables[@]}):"; for b in "${borrables[@]}"; do echo "  - ${b%%|*} (${b##*|})"; done

[ $aplicar -eq 1 ] || { echo; echo "Nada borrado. Repite con --aplicar para borrar los de la segunda lista."; exit 0; }

lote=0
for b in "${borrables[@]}"; do
  ruta="${b%%|*}"
  git worktree remove --force "$ruta" 2>/dev/null
  # En Windows, remove suele dejar el directorio por rutas largas: se borra aparte.
  [ -d "$ruta" ] && rm -rf "$ruta"
  echo "borrado: $ruta"
  lote=$(( lote + 1 ))
  if [ $(( lote % 8 )) -eq 0 ]; then sleep 2; fi
done
git worktree prune
echo "Listo. Ramas conservadas; 'git branch --merged $principal' las lista si quieres borrarlas también."
