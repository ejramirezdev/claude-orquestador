# Vigilar agentes

`cursor-agent -p` no muestra nada hasta el final, y a veces **nunca termina**: se queda colgado después de
hacer su commit (tests que esperan una conexión a Redis o a una base de datos, reintentos de red de la
propia CLI). Si solo esperas la notificación de salida, el trabajo terminado queda parado sin que nadie
lo sepa. Por eso cada agente lanzado lleva su vigía.

## El vigía

`scripts/vigilar-agente.sh` es un script de shell. Cada 20 s revisa tres cosas: el último commit del worktree, el log de progreso y si el proceso del agente sigue vivo. **No consume tokens mientras corre**: solo cuesta cuando emite un evento.

Arráncalo con la herramienta Monitor, con el timeout máximo. **Un vigía por agente**, con `--etiqueta NN`:

```
bash "<skill>/scripts/vigilar-agente.sh" --etiqueta NN --worktree "<ruta del worktree>" \
  --log ".scratch/<feature>/logs/NN-lanzar-cursor.out" \
  --progreso "<ruta del worktree>/.scratch/<feature>/logs/NN-progreso.md"
```

Eventos, cada uno precedido de `[NN]`:
- `PROGRESO: <línea>`: cada paso que el agente anota, incluido su resumen final. Viene activado por defecto; `--silencioso` lo apaga cuando corren muchos agentes a la vez y el volumen de eventos importa más que la narración.
- `COMMIT: <sha> <mensaje>`: revisa ya, aunque el proceso siga vivo.
- `ALERTA: N min sin avance ni commit`: mira el log, los procesos y la memoria.
- `AUTO` / `CUPO`: la cascada de cupo (ver `lanzar.md`).
- `FIN: <línea fin/error>`: el agente terminó. Revisa el resultado.

**Por qué uno por agente y no uno para todos.** Cada agente tiene su propio ciclo: se relanza, se le devuelve una corrección o se cae por cupo, y el de al lado sigue igual. Con un vigía por agente, relanzar uno solo reinicia su vigía; los demás siguen sin perder su estado. Con uno compartido, cada relanzamiento obliga a matarlo y rearmarlo para todos, y se pierde qué líneas ya se habían narrado. El costo en tokens es el mismo, porque lo que cuesta es cada evento emitido, no cada proceso.

**Narra cada evento al usuario**, en una línea: qué hizo el agente y qué haces tú ahora. Ejemplos: "la pieza 02 escribió los tests en rojo, ahora implementa" o "la 03 terminó, reviso el diff". Es lo que hace que el usuario vea el trabajo avanzar sin preguntar "¿cómo va?". Los agentes terminan con un bloque `== RESUMEN ==` en su log de progreso (ver `plantillas.md`), que llega como `PROGRESO` antes del `FIN`: léelo antes de abrir el diff.

**Rearmar.** El Monitor expira a los 30 min como máximo. Si expira y el agente sigue vivo, vuelve a lanzar el mismo comando: el vigía arranca desde el tamaño actual del log de progreso y no repite líneas ya narradas. Si relanzas el agente (con una corrección o para retomarlo), detén su vigía y arma uno nuevo; los de los otros agentes no se tocan.

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
