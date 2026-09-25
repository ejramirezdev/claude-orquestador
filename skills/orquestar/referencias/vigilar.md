# Vigilar agentes

`cursor-agent -p` no muestra nada hasta el final, y a veces **nunca termina**: se queda colgado después de
hacer su commit (tests que esperan una conexión a Redis o a una base de datos, reintentos de red de la
propia CLI). Si solo esperas la notificación de salida, el trabajo terminado queda parado sin que nadie
lo sepa. Por eso cada agente lanzado lleva su vigía.

## El vigía

`scripts/vigilar-agente.sh` es un script de shell: revisa cada 30 s el último commit del worktree, el
tamaño del log de progreso y si el proceso del agente sigue vivo. **No consume tokens mientras corre**;
solo cuesta cuando emite un evento.

Arráncalo con la herramienta Monitor (timeout máximo; re-ármalo si expira y el agente sigue vivo):

```
bash "<skill>/scripts/vigilar-agente.sh" --worktree "<ruta del worktree>" \
  --log ".scratch/<feature>/logs/NN-lanzar-cursor.out" \
  --progreso "<ruta del worktree>/.scratch/<feature>/logs/NN-progreso.md" [--verbose]
```

Emite solo:
- `COMMIT: <sha> <mensaje>` — revisa ya, aunque el proceso siga vivo.
- `ALERTA: N min sin avance ni commit` — mira el log, los procesos y la memoria.
- `FIN: el agente terminó` — revisa el resultado y la línea `fin exit=N` del log.
- Con `--verbose`, además cada línea nueva del log de progreso (más eventos, más tokens).

## Qué hacer con cada evento

| Evento | Acción |
|---|---|
| `COMMIT` con árbol limpio | Revisar el diff (`revisar.md`). Si el proceso sigue vivo y ya hay commit final, está colgado: termínalo (ver abajo). |
| `COMMIT` pero quedan cambios sin commit | Espera el `FIN` o el siguiente commit; el agente sigue trabajando. |
| `ALERTA` | Lee las últimas líneas del log de progreso y del log del lanzador (`…-cursor.out`); lista sus procesos hijos. Tests colgados → termínalos; memoria → `revisar-recursos`. |
| `FIN` sin commit | El agente murió o no commiteó. Si hay cambios en el worktree, relánzalo en modo "retomar". |
| La tarea en segundo plano aparece como detenida "por falta de memoria" | No la relances sola: informa al usuario y reduce el paralelismo (`problemas-conocidos.md`, "memoria"). |

## Terminar un agente colgado

Encuentra su árbol de procesos (Windows: `Get-CimInstance Win32_Process` filtrando por la ruta del
worktree o por `ParentProcessId`; macOS/Linux: `pgrep -f <ruta del worktree>`). Termina el proceso
principal y sus hijos (tests, compiladores) **solo después** de confirmar que su commit final está en el
worktree. Nunca mates procesos de otro agente vivo.
