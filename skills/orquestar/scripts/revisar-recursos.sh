#!/usr/bin/env bash
# Diagnóstico de memoria antes de lanzar agentes (macOS/Linux). Solo lee; no mata nada.
set -uo pipefail

if [ "$(uname)" = "Darwin" ]; then
  pag=$(sysctl -n hw.pagesize)
  libres=$(vm_stat | awk '/Pages free|Pages inactive|Pages speculative/ {gsub("\\.","",$NF); s+=$NF} END {print s}')
  libre_mb=$(( libres * pag / 1024 / 1024 ))
  total_mb=$(( $(sysctl -n hw.memsize) / 1024 / 1024 ))
else
  libre_mb=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  total_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
fi
echo "RAM disponible: $(( libre_mb / 1024 )) GB de $(( total_mb / 1024 )) GB"
echo
echo "Procesos node (tipo, pid, padre, MB, comando):"
ps -eo pid=,ppid=,rss=,command= | awk '/[n]ode/ {
  t="otro"
  if ($0 ~ /cursor-agent/) t="agente cursor"; else if ($0 ~ /statusline/) t="barra de estado";
  else if ($0 ~ /next/) t="next"; else if ($0 ~ /tsc/) t="tsc"; else if ($0 ~ /tsx|vitest|jest|test/) t="tests";
  printf "  %-15s %7s %7s %6d MB  %.80s\n", t, $1, $2, $3/1024, substr($0, index($0,$4)) }'
agentes=$(ps -eo command= | grep -c "[c]ursor-agent")
echo "Agentes de Cursor corriendo: $agentes"
echo
libre_gb=$(( libre_mb / 1024 ))
if [ "$libre_gb" -ge 8 ]; then echo "Recomendación: hasta 3 agentes en paralelo (restando los que ya corren), verificando UNO A LA VEZ."
elif [ "$libre_gb" -ge 4 ]; then echo "Recomendación: 1 agente a la vez, verificando UNO A LA VEZ."
else echo "Recomendación: NO lances más agentes; cierra procesos huérfanos o reinicia."; fi
