#!/usr/bin/env bash
# Lanza un agente de Cursor CLI en un worktree (nuevo o existente) y deja un log con inicio/fin.
# Corre en primer plano hasta que el agente termina: invócalo con run_in_background.
#
#   bash lanzar-agente.sh --nombre dp-05-motor --modelo complejo --prompt-file .scratch/feat/logs/05-lanzar.md
#   bash lanzar-agente.sh --worktree ~/.cursor/worktrees/repo/dp-05-motor --modelo auto --prompt-file .scratch/feat/logs/05-retomar.md
#
# --modelo: complejo | sencillo | auto, o un id exacto de `cursor-agent models`.
# Opcionales: --base <rama> (base del worktree nuevo), --log <ruta> (por defecto <prompt>-cursor.out).
# Escribe "inicio ..." y "fin ... exit=N" en el log y deja el PID en "<log>.pid" mientras vive.
set -uo pipefail

nombre="" modelo="" prompt_file="" worktree="" base="" log=""
while [ $# -gt 0 ]; do
  case "$1" in
    --nombre) nombre="$2"; shift 2 ;;
    --modelo) modelo="$2"; shift 2 ;;
    --prompt-file) prompt_file="$2"; shift 2 ;;
    --worktree) worktree="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    *) echo "argumento desconocido: $1" >&2; exit 2 ;;
  esac
done

[ -n "$modelo" ] && [ -n "$prompt_file" ] || { echo "faltan --modelo y --prompt-file" >&2; exit 2; }
[ -n "$nombre" ] || [ -n "$worktree" ] || { echo "indica --nombre (nuevo) o --worktree (retomar)" >&2; exit 2; }
[ -f "$prompt_file" ] || { echo "no existe el prompt: $prompt_file" >&2; exit 2; }
command -v cursor-agent >/dev/null || { echo "cursor-agent no está en el PATH (instala Cursor CLI y 'cursor-agent login')" >&2; exit 2; }
[ -z "$worktree" ] || [ -d "$worktree" ] || { echo "no existe el worktree: $worktree" >&2; exit 2; }

[ -n "$log" ] || log="${prompt_file%.*}-cursor.out"

# --modelo acepta un nivel (complejo | sencillo | auto) o un id exacto; se valida contra la lista
# real de la cuenta antes de gastar un agente. Ver resolver-modelo.sh.
modelo=$(bash "$(dirname "${BASH_SOURCE[0]}")/resolver-modelo.sh" "$modelo" | tail -1) && [ -n "$modelo" ] \
  || { echo "no se pudo resolver el modelo (ver mensaje anterior)" >&2; exit 2; }

patron_cupo='out of usage|usage limit|Switch to Auto'
[ -z "$worktree" ] && destino="nuevo=$nombre" || destino="worktree=$worktree"

echo "inicio $(date -Iseconds) modelo=$modelo $destino" > "$log"
echo $$ > "$log.pid"
trap 'rm -f "$log.pid"' EXIT

correr() { # $1 = modelo, $2 = worktree existente (vacío = crear con -w), $3 = texto del prompt
  local a=(-p --model "$1" --force --trust)
  if [ -n "$2" ]; then a+=(--workspace "$2"); else
    a+=(-w "$nombre"); [ -z "$base" ] || a+=(--worktree-base "$base")
  fi
  cursor-agent "${a[@]}" "$3" >> "$log" 2>&1
}

desde=1
correr "$modelo" "$worktree" "$(cat "$prompt_file")"; code=$?
sin_cupo=0; [ $code -ne 0 ] && tail -n +$desde "$log" | grep -qE "$patron_cupo" && sin_cupo=1

# Sin cupo con un modelo que no es auto: reintento automático con auto, en el mismo worktree
# (el usuario no tiene que intervenir). Cascada completa en lanzar.md.
if [ $sin_cupo -eq 1 ] && [ "$modelo" != "auto" ]; then
  wt="$worktree"
  if [ -z "$wt" ] && [ -n "$nombre" ]; then
    repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
    [ -d "$HOME/.cursor/worktrees/$repo/$nombre" ] && wt="$HOME/.cursor/worktrees/$repo/$nombre"
  fi
  echo "reintento-auto $(date -Iseconds) sin-cupo=$modelo" >> "$log"
  desde=$(( $(wc -l < "$log") + 1 ))   # solo mira lo que escriba el reintento
  nota=$'\n\n---\nNota: esta tarea ya se intentó con otro modelo. Antes de seguir, revisa `git status` y `git log` en este worktree y continúa desde donde quedó, sin rehacer lo que ya está.'
  correr auto "$wt" "$(cat "$prompt_file")$nota"; code=$?
  modelo=auto
  sin_cupo=0; [ $code -ne 0 ] && tail -n +$desde "$log" | grep -qE "$patron_cupo" && sin_cupo=1
fi

# Cupo agotado incluso con auto: el vigía lo avisa como CUPO y el líder pasa a Sonnet/Haiku (lanzar.md).
[ $sin_cupo -eq 1 ] && echo "cupo-agotado $(date -Iseconds) modelo=$modelo" >> "$log"
echo "fin $(date -Iseconds) exit=$code" >> "$log"
exit $code
