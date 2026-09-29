#!/usr/bin/env bash
# Resuelve un nivel de dificultad al id EXACTO de modelo que acepta `cursor-agent --model`,
# leyendo la lista real de la cuenta (`cursor-agent --list-models`). Imprime solo el id.
#
#   bash resolver-modelo.sh complejo   # Grok más reciente, esfuerzo high
#   bash resolver-modelo.sh sencillo   # Composer más reciente
#   bash resolver-modelo.sh auto       # el modo automático de Cursor
#   bash resolver-modelo.sh grok-4.7-high   # id explícito: solo se valida que exista
#
# Los ids no siguen un patrón único (`grok-4.7-high` vs `cursor-grok-4.6-high`), por eso nunca se
# arman a mano. Se prefiere la variante sin `-fast`. Si el esfuerzo pedido no existe para esa versión,
# se usa el más cercano hacia abajo (y, si no hay, hacia arriba). Códigos: 0 ok, 1 no hay modelo, 2 uso.
set -uo pipefail

nivel="${1:-}"
[ -n "$nivel" ] || { echo "uso: resolver-modelo.sh complejo|sencillo|auto|<id>" >&2; exit 2; }
command -v cursor-agent >/dev/null || { echo "cursor-agent no está en el PATH" >&2; exit 2; }

ids=$(cursor-agent --list-models 2>/dev/null | tr -d '\r' | sed -nE 's/^([A-Za-z0-9._-]+) - .*/\1/p')
[ -n "$ids" ] || { echo "cursor-agent --list-models no devolvió modelos (¿sesión iniciada?)" >&2; exit 1; }
existe() { printf '%s\n' "$ids" | grep -qx -- "$1"; }

# Grok: versión más alta (sort -V) y, dentro de ella, el esfuerzo pedido con su cadena de respaldo.
grok() { # $1 = esfuerzo
  local ver orden e id
  ver=$(printf '%s\n' "$ids" | sed -nE 's/^(cursor-)?grok-([0-9]+(\.[0-9]+)*)-(low|medium|high|xhigh)(-fast)?$/\2/p' | sort -Vu | tail -1)
  [ -n "$ver" ] || return 1
  case "$1" in
    high)   orden="high medium low xhigh" ;;
    medium) orden="medium low high xhigh" ;;
    *)      orden="low medium high xhigh" ;;
  esac
  for e in $orden; do
    for id in "grok-$ver-$e" "cursor-grok-$ver-$e" "grok-$ver-$e-fast" "cursor-grok-$ver-$e-fast"; do
      if existe "$id"; then
        [ "$e" = "$1" ] || echo "aviso: Grok $ver no tiene esfuerzo '$1'; se usa '$e'" >&2
        echo "$id"; return 0
      fi
    done
  done
  return 1
}

composer() {
  local ver id
  ver=$(printf '%s\n' "$ids" | sed -nE 's/^composer-([0-9]+(\.[0-9]+)*)(-fast)?$/\1/p' | sort -Vu | tail -1)
  [ -n "$ver" ] || return 1
  for id in "composer-$ver" "composer-$ver-fast"; do
    existe "$id" && { echo "$id"; return 0; }
  done
  return 1
}

case "$nivel" in
  complejo) grok high  || { echo "no hay ningún modelo Grok en la cuenta" >&2; exit 1; } ;;
  sencillo) composer   || { echo "no hay ningún modelo Composer en la cuenta" >&2; exit 1; } ;;
  auto)     echo auto ;;
  *)
    if existe "$nivel"; then echo "$nivel"; else
      echo "el modelo '$nivel' no existe en esta cuenta. Parecidos:" >&2
      printf '%s\n' "$ids" | grep -i -- "$(printf '%s' "$nivel" | sed -E 's/-(low|medium|high|xhigh|fast).*//')" | head -8 >&2
      exit 1
    fi ;;
esac
