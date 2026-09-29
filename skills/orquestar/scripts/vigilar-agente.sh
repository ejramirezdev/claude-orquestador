#!/usr/bin/env bash
# Vigía de un agente: pensado para la herramienta Monitor de Claude Code (cada línea de salida = un evento).
# No consume tokens mientras corre; solo emite cuando algo cambia.
#
#   bash vigilar-agente.sh --worktree <ruta> --log <ruta del -cursor.out> \
#        [--progreso <ruta del log de progreso>] [--etiqueta NN] [--intervalo 20] [--alerta-min 15] [--silencioso]
#
# Eventos (con --etiqueta NN, cada uno va precedido de "[NN] "):
#   PROGRESO: <línea>                cada línea nueva del log de progreso (recortada a 200 caracteres);
#                                    así el líder narra el avance paso a paso. --silencioso la apaga.
#   COMMIT: <sha> <mensaje>          nuevo commit en el worktree
#   ALERTA: N min sin avance         ni commit ni cambios en el log de progreso
#   AUTO: <detalle>                  sin cupo con el modelo del nivel; el lanzador reintentó solo con auto
#   CUPO: <detalle>                  tampoco auto tuvo cupo: pasar a Sonnet/Haiku (AUTO y CUPO salen antes del FIN)
#   FIN: <línea fin/error del log>   el lanzador terminó (o su proceso desapareció)
set -uo pipefail

worktree="" log="" progreso="" etiqueta="" intervalo=20 alerta_min=15 narrar=1
while [ $# -gt 0 ]; do
  case "$1" in
    --worktree) worktree="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    --progreso) progreso="$2"; shift 2 ;;
    --etiqueta) etiqueta="$2"; shift 2 ;;
    --intervalo) intervalo="$2"; shift 2 ;;
    --alerta-min) alerta_min="$2"; shift 2 ;;
    --silencioso) narrar=0; shift ;;
    --verbose) narrar=1; shift ;;  # compatibilidad: narrar ya es el comportamiento por defecto
    *) echo "argumento desconocido: $1" >&2; exit 2 ;;
  esac
done
[ -n "$log" ] || { echo "falta --log" >&2; exit 2; }
pre=""; [ -z "$etiqueta" ] || pre="[$etiqueta] "

emitir() { echo "${pre}$*"; }

# El log puede traer bytes NUL (salida de PowerShell 5.1 en UTF-16 de lanzadores viejos o hechos a mano):
# sin quitarlos, "^fin" no coincide con "\0fin". Toda lectura del log pasa por aquí.
log_limpio() { tr -d '\000' < "$log" 2>/dev/null | tr -d '\r'; }

fin() { # $1 = motivo
  local extra=""
  if [ -n "$worktree" ] && [ -d "$worktree" ]; then
    extra=" | último commit: $(git -C "$worktree" log --oneline -1 2>/dev/null) | sin commit: $(git -C "$worktree" status --porcelain 2>/dev/null | wc -l | tr -d ' ') archivo(s)"
  fi
  narrar_nuevas
  local cupo auto
  auto=$(log_limpio | grep -E "^ *reintento-auto " | tail -1)
  [ -z "$auto" ] || emitir "AUTO: el modelo se quedó sin cupo y el lanzador reintentó con auto (${auto#*reintento-auto })"
  cupo=$(log_limpio | grep -E "^ *cupo-agotado " | tail -1)
  [ -z "$cupo" ] || emitir "CUPO: Cursor sin cupo incluso con auto (${cupo#*cupo-agotado }) — pasa a Sonnet/Haiku (lanzar.md)"
  emitir "FIN: $1$extra"
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

# Emite las líneas del log de progreso que no se hayan emitido todavía (incluido el resumen final
# que el agente escribe al terminar: así llega antes de abrir el diff).
narrar_nuevas() {
  [ $narrar -eq 1 ] || return 0
  local n; n=$(lineas)
  if [ "$n" -gt "$ultimas_lineas" ]; then
    tail -n $(( n - ultimas_lineas )) "$progreso" | tr -d '\000\r' | cut -c1-200 | sed "s/^/${pre}PROGRESO: /"
  fi
  ultimas_lineas=$n
}

# Espera a que el worktree nuevo exista (cursor-agent -w lo crea al arrancar).
for _ in $(seq 1 20); do
  { [ -z "$worktree" ] || [ -d "$worktree" ]; } && break
  sleep 3
done
[ -z "$worktree" ] || [ -d "$worktree" ] || emitir "ALERTA: el worktree $worktree no apareció; revisa el log $log"

# Al relanzar sobre un worktree existente, no repetir lo que el log de progreso ya tenía.
ultima_cabeza=$(cabeza); ultimas_lineas=$(lineas); ultimo_tamano=$(tamano)
quieto=0; alertado=0; vio_pid=0
umbral=$(( alerta_min * 60 / intervalo ))

while true; do
  sleep "$intervalo"

  t=$(tamano)
  if [ "$t" != "$ultimo_tamano" ]; then
    narrar_nuevas
    ultimo_tamano=$t; quieto=0; alertado=0
  else
    quieto=$(( quieto + 1 ))
  fi

  c=$(cabeza)
  if [ "$c" != "$ultima_cabeza" ] && [ "$c" != "-" ]; then
    emitir "COMMIT: $(git -C "$worktree" log --oneline -1)"
    ultima_cabeza=$c; quieto=0; alertado=0
  fi

  if [ $quieto -ge "$umbral" ] && [ $alertado -eq 0 ]; then
    emitir "ALERTA: $alerta_min min sin avance ni commit"
    alertado=1
  fi

  final=$(log_limpio | grep -E "^ *(fin|error) " | tail -1)
  [ -n "$final" ] && fin "${final#"${final%%[![:space:]]*}"}"
  if [ -f "$log.pid" ]; then
    vio_pid=1
    pid=$(tr -d '[:space:]' < "$log.pid")
    if [ -n "$pid" ] && ! vivo "$pid"; then fin "el proceso del lanzador ($pid) ya no existe y el log no tiene línea de fin"; fi
  elif [ $vio_pid -eq 1 ]; then
    fin "el lanzador terminó sin escribir su línea de fin"
  fi
done
