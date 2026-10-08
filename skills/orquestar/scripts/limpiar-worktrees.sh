#!/usr/bin/env bash
# Lista (y con --aplicar, borra) los worktrees que ya no hacen falta, y libera el espacio de los que sí.
#
# Criterio seguro para borrar un worktree: su rama está fusionada en la rama principal Y no tiene
# cambios en archivos trackeados. Los archivos ignorados por .gitignore no bloquean. Los archivos sin
# trackear y no ignorados (pueden ser trabajo que el agente olvidó commitear) se respetan, salvo que
# pases --incluir-sin-trackear.
#
#   bash limpiar-worktrees.sh [--rama-principal master] [--aplicar]
#        [--incluir-sin-trackear]   borra también worktrees fusionados que solo tienen archivos sin trackear
#        [--borrar-ramas]           borra las ramas ya fusionadas de los worktrees eliminados (git branch -d)
#        [--artefactos]             borra carpetas de compilación (.next, .turbo, dist, build, out, coverage)
#                                   en TODOS los worktrees secundarios, también en los que se conservan:
#                                   se regeneran solas y suelen ser lo que más pesa
#        [--con-dependencias]       con --artefactos, borra además node_modules (se reinstala al retomar)
#
# Sin --aplicar no borra nada: solo informa. Correr desde la raíz del repositorio principal, en primer plano.
set -uo pipefail

principal="" aplicar=0 sin_trackear=0 ramas=0 artefactos=0 dependencias=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rama-principal) principal="$2"; shift 2 ;;
    --aplicar) aplicar=1; shift ;;
    --incluir-sin-trackear) sin_trackear=1; shift ;;
    --borrar-ramas) ramas=1; shift ;;
    --artefactos) artefactos=1; shift ;;
    --con-dependencias) dependencias=1; shift ;;
    *) echo "argumento desconocido: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$principal" ]; then
  principal=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
  [ -n "$principal" ] || principal=$(git rev-parse --abbrev-ref HEAD)
fi
raiz=$(git rev-parse --show-toplevel)

libre_gb() { df -Pk "$raiz" 2>/dev/null | awk 'NR==2 {printf "%.1f", $4/1024/1024}'; }
antes=$(libre_gb)

borrables=() conservar=() todos=() padres=("$raiz/.claude/worktrees")
while IFS= read -r linea; do
  case "$linea" in
    "worktree "*) ruta="${linea#worktree }" ;;
    "branch "*)
      rama="${linea#branch refs/heads/}"
      [ "$(cd "$ruta" 2>/dev/null && pwd -P)" = "$(cd "$raiz" && pwd -P)" ] && continue
      todos+=("$ruta"); padres+=("$(dirname "$ruta")")
      if ! git merge-base --is-ancestor "$rama" "$principal" 2>/dev/null; then
        conservar+=("$ruta  [rama $rama sin fusionar en $principal]"); continue
      fi
      modificados=$(git -C "$ruta" status --porcelain --untracked-files=no 2>/dev/null | head -5)
      if [ -n "$modificados" ]; then
        conservar+=("$ruta  [cambios sin commit: $(echo "$modificados" | tr '\n' ' ')]"); continue
      fi
      sueltos=$(git -C "$ruta" status --porcelain 2>/dev/null | grep -c '^??')
      if [ "${sueltos:-0}" -gt 0 ] && [ $sin_trackear -eq 0 ]; then
        conservar+=("$ruta  [$sueltos archivo(s) sin trackear; revisa o repite con --incluir-sin-trackear]"); continue
      fi
      borrables+=("$ruta|$rama") ;;
  esac
done < <(git worktree list --porcelain)

# Directorios huérfanos: carpetas hermanas de worktrees conocidos (o en .claude/worktrees) que git ya
# no registra. No se borran solas: no hay rama que respalde su contenido.
huerfanos=()
while IFS= read -r padre; do
  [ -d "$padre" ] || continue
  # Solo carpetas dedicadas a worktrees: un worktree creado en /tmp o en la carpeta de proyectos no
  # convierte en "huérfanos" a sus vecinos.
  case "$padre/" in */worktrees/*) ;; *) continue ;; esac
  for d in "$padre"/*/; do
    d="${d%/}"; [ -d "$d" ] || continue
    [ -e "$d/.git" ] || huerfanos+=("$d")
  done
done < <(printf '%s\n' "${padres[@]}" | sort -u)

echo "Rama principal: $principal    Espacio libre: ${antes} GB    Worktrees secundarios: ${#todos[@]}"
echo "Se conservan (${#conservar[@]}):"; for c in ${conservar[@]+"${conservar[@]}"}; do echo "  - $c"; done
echo "Se pueden borrar (${#borrables[@]}):"; for b in ${borrables[@]+"${borrables[@]}"}; do echo "  - ${b%%|*} (${b##*|})"; done
if [ ${#huerfanos[@]} -gt 0 ]; then
  echo "Huérfanos, sin registro en git (${#huerfanos[@]}): revísalos y bórralos a mano si no hay nada que rescatar"
  for h in "${huerfanos[@]}"; do echo "  - $h"; done
fi

[ $aplicar -eq 1 ] || { echo; echo "Nada borrado. Repite con --aplicar (y --artefactos para vaciar compilaciones de los que se conservan)."; exit 0; }

# Antes de borrar cualquier carpeta: quitar los enlaces (symlinks o junctions de Windows) que apunten
# FUERA de ella, sin seguirlos. Un worktree puede tener su node_modules enlazado al del repositorio
# principal; borrar el worktree siguiendo ese enlace vacía las dependencias del principal (pasó de verdad).
quitar_enlaces() { # $1 = carpeta
  local enlace
  while IFS= read -r enlace; do
    [ -n "$enlace" ] || continue
    if command -v cygpath >/dev/null 2>&1; then
      cmd //c rmdir "$(cygpath -w "$enlace")" >/dev/null 2>&1 || cmd //c del "$(cygpath -w "$enlace")" >/dev/null 2>&1
    else
      unlink "$enlace" 2>/dev/null
    fi
    # Si el enlace sigue ahí no se arriesga el borrado recursivo de esa carpeta.
    [ -L "$enlace" ] && return 1
  done < <(find "$1" -maxdepth 6 -type l -not -path '*/node_modules/*' 2>/dev/null)
  return 0
}

# Borrado recursivo que NO sigue enlaces. En Windows, `rm -rf` de Git Bash y `git worktree remove --force`
# pueden entrar por una junction (p. ej. node_modules/.bin enlazado al repositorio principal, a cualquier
# profundidad) y vaciar el destino; `rmdir /s /q` de cmd quita la junction sin tocar a dónde apunta.
borrar_dir() { # $1 = carpeta
  if command -v cygpath >/dev/null 2>&1; then
    cmd //c rmdir //s //q "$(cygpath -w "$1")" >/dev/null 2>&1
  else
    rm -rf "$1"
  fi
  [ ! -e "$1" ]
}

lote=0
for b in ${borrables[@]+"${borrables[@]}"}; do
  ruta="${b%%|*}" rama="${b##*|}"
  quitar_enlaces "$ruta" || { echo "NO borrado (tiene enlaces que no se pudieron quitar): $ruta"; continue; }
  if command -v cygpath >/dev/null 2>&1; then
    # Windows: nunca `git worktree remove --force` ni `rm -rf` (siguen junctions). Se borra la carpeta y
    # `git worktree prune` (al final) quita el registro.
    borrar_dir "$ruta" || { echo "NO se pudo borrar del todo: $ruta"; continue; }
  else
    git worktree remove --force "$ruta" 2>/dev/null
    [ -d "$ruta" ] && rm -rf "$ruta"
  fi
  [ $ramas -eq 1 ] && git branch -d "$rama" >/dev/null 2>&1
  echo "borrado: $ruta"
  lote=$(( lote + 1 ))
  if [ $(( lote % 8 )) -eq 0 ]; then sleep 2; fi
done
git worktree prune

if [ $artefactos -eq 1 ]; then
  nombres=(.next .turbo dist build out coverage)
  [ $dependencias -eq 1 ] && nombres+=(node_modules)
  for t in ${todos[@]+"${todos[@]}"}; do
    [ -d "$t" ] || continue
    for n in "${nombres[@]}"; do
      # Solo carpetas ignoradas por git: una "build" o "dist" versionada no se toca.
      while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        git -C "$t" check-ignore -q "$dir" 2>/dev/null || continue
        # Un node_modules (u otra carpeta) que es un enlace hacia otro lugar se desenlaza, nunca se vacía.
        if [ -L "$dir" ]; then quitar_enlaces "$(dirname "$dir")"; continue; fi
        borrar_dir "$dir" && echo "artefacto borrado: $dir"
      done < <(find "$t" -maxdepth 4 \( -type d -o -type l \) -name "$n" -not -path '*/node_modules/*' -prune 2>/dev/null)
    done
  done
fi

echo "Listo. Espacio libre: ${antes} GB -> $(libre_gb) GB."
[ $ramas -eq 1 ] || echo "Ramas conservadas; repite con --borrar-ramas o usa 'git branch --merged $principal' para verlas."
