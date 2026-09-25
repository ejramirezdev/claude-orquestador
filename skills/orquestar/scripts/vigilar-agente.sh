#!/usr/bin/env bash
# Vigía de un agente: pensado para la herramienta Monitor de Claude Code (cada línea de salida = un evento).
# No consume tokens mientras corre; solo emite cuando algo cambia.
#
#   bash vigilar-agente.sh --worktree <ruta> --log <ruta del -cursor.out> \
#        [--progreso <ruta del log de progreso>] [--intervalo 30] [--alerta-min 15] [--verbose]
#
# Eventos:
#   COMMIT: <sha> <mensaje>          nuevo commit en el worktree
#   ALERTA: N min sin avance         ni commit ni cambios en el log de progreso
#   FIN: <línea fin/error del log>   el lanzador terminó (o su proceso desapareció)
#   PROGRESO: <línea>                solo con --verbose
set -uo pipefail

worktree="" log="" progreso="" intervalo=30 alerta_min=15 verbose=0
while [ $# -gt 0 ]; do
  case "$1" in
    --worktree) worktree="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    --progreso) progreso="$2"; shift 2 ;;
    --intervalo) intervalo="$2"; shift 2 ;;
    --alerta-min) alerta_min="$2"; shift 2 ;;
    --verbose) verbose=1; shift ;;
    *) echo "argumento desconocido: $1" >&2; exit 2 ;;
  esac
done
[ -n "$log" ] || { echo "falta --log" >&2; exit 2; }

fin() { # $1 = motivo
  local extra=""
  if [ -n "$worktree" ] && [ -d "$worktree" ]; then
    extra=" | último commit: $(git -C "$worktree" log --oneline -1 2>/dev/null) | sin commit: $(git -C "$worktree" status --porcelain 2>/dev/null | wc -l | tr -d ' ') archivo(s)"
  fi
  echo "FIN: $1$extra"
  exit 0
}

vivo() { # $1 = pid
  if command -v tasklist.exe >/dev/null 2>&1; then
    tasklist.exe //FI "PID eq $1" //NH 2>/dev/null | grep -q "[[:space:]]$1[[:space:]]"
  else
    kill -0 "$1" 2>/dev/null
  fi
}

cabeza() { [ -n "$worktree" ] && git -C "$worktree" rev-parse HEAD 2>/dev/null || echo "-"; }
lineas() { [ -n "$progreso" ] && [ -f "$progreso" ] && wc -l < "$progreso" | tr -d ' ' || echo 0; }
tamano() { [ -n "$progreso" ] && [ -f "$progreso" ] && wc -c < "$progreso" | tr -d ' ' || echo 0; }

# Espera a que el worktree nuevo exista (cursor-agent -w lo crea al arrancar).
for _ in $(seq 1 20); do
  { [ -z "$worktree" ] || [ -d "$worktree" ]; } && break
  sleep 3
done
[ -z "$worktree" ] || [ -d "$worktree" ] || echo "ALERTA: el worktree $worktree no apareció; revisa el log $log"

ultima_cabeza=$(cabeza); ultimas_lineas=$(lineas); ultimo_tamano=$(tamano)
quieto=0; alertado=0; vio_pid=0
umbral=$(( alerta_min * 60 / intervalo ))

while true; do
  sleep "$intervalo"

  c=$(cabeza)
  if [ "$c" != "$ultima_cabeza" ] && [ "$c" != "-" ]; then
    echo "COMMIT: $(git -C "$worktree" log --oneline -1)"
    ultima_cabeza=$c; quieto=0; alertado=0
  fi

  t=$(tamano)
  if [ "$t" != "$ultimo_tamano" ]; then
    if [ $verbose -eq 1 ]; then
      n=$(lineas)
      [ "$n" -gt "$ultimas_lineas" ] && tail -n $(( n - ultimas_lineas )) "$progreso" | sed 's/^/PROGRESO: /'
      ultimas_lineas=$n
    fi
    ultimo_tamano=$t; quieto=0; alertado=0
  else
    quieto=$(( quieto + 1 ))
  fi

  if [ $quieto -ge "$umbral" ] && [ $alertado -eq 0 ]; then
    echo "ALERTA: $alerta_min min sin avance ni commit"
    alertado=1
  fi

  final=$(grep -E "^(fin|error) " "$log" 2>/dev/null | tail -1)
  [ -n "$final" ] && fin "$final"
  if [ -f "$log.pid" ]; then
    vio_pid=1
    pid=$(tr -d '[:space:]' < "$log.pid")
    if [ -n "$pid" ] && ! vivo "$pid"; then fin "el proceso del lanzador ($pid) ya no existe y el log no tiene línea de fin"; fi
  elif [ $vio_pid -eq 1 ]; then
    fin "el lanzador terminó sin escribir su línea de fin"
  fi
done
