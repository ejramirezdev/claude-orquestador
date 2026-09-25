#!/usr/bin/env bash
# Lanza un agente de Cursor CLI en un worktree (nuevo o existente) y deja un log con inicio/fin.
# Corre en primer plano hasta que el agente termina: invócalo con run_in_background.
#
#   bash lanzar-agente.sh --nombre dp-05-motor --modelo grok-4.7-high --prompt-file .scratch/feat/logs/05-lanzar.md
#   bash lanzar-agente.sh --worktree ~/.cursor/worktrees/repo/dp-05-motor --modelo auto --prompt-file .scratch/feat/logs/05-retomar.md
#
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

args=(-p --model "$modelo" --force --trust)
if [ -n "$worktree" ]; then
  args+=(--workspace "$worktree"); destino="worktree=$worktree"
else
  args+=(-w "$nombre"); destino="nuevo=$nombre"
  [ -z "$base" ] || args+=(--worktree-base "$base")
fi

echo "inicio $(date -Iseconds) modelo=$modelo $destino" > "$log"
echo $$ > "$log.pid"
trap 'rm -f "$log.pid"' EXIT

cursor-agent "${args[@]}" "$(cat "$prompt_file")" >> "$log" 2>&1
code=$?
echo "fin $(date -Iseconds) exit=$code" >> "$log"
exit $code
