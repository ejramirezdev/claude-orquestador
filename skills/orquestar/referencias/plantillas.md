# Plantillas

## `spec.md` (una por funcionalidad)

```markdown
# <Funcionalidad> — spec

Estado: <fecha> · decisiones cerradas con el usuario.

## 1. Problema
<qué duele hoy y para quién>

## 2. Alcance por fase
| Fase | Contenido |
Fuera de alcance: <lista explícita>

## 3. Lo que ya existe (no reinventar)
<archivos, modelos, funciones reutilizables con ruta>

## 4. Arquitectura
<dónde vive cada pieza y por qué>

## 5. Reglas funcionales
<una subsección por regla, con números y umbrales concretos>

## 6. Modelo de datos
## 7. Verificación
## 8. Issues (orden y dependencias)
```

## `issues/NN-<slug>.md` (una pieza = un agente)

```markdown
Status: open
Ola: <n> (en paralelo con <NN>, tras <NN>)
Modelo: complejo | sencillo

# NN — <título>

Lee solo `.scratch/<feature>/spec.md` (§<secciones>) y los archivos listados abajo. No leas el
`CLAUDE.md` ni explores el resto del repo: lo que necesitas está aquí.

## Contexto que necesitas
<fragmentos, firmas y rutas ya decididos; las dos o tres reglas del proyecto que sí le aplican>

## Objetivo
<una o dos frases>

## Archivos tuyos
<lista cerrada; lo que no esté aquí no se toca. Si otra pieza corre en paralelo, di cuál y qué archivos son suyos>

## Qué hacer
<pasos numerados, con nombres de funciones/rutas cuando ya estén decididos>

## Criterio de aceptación
- Tests: <solo si la pieza los necesita: casos concretos; puedes correr ESE archivo de test, nada más>
- NO verifiques: sin instalar dependencias, generar código, tipos, lint, suite completa ni compilación.
  El líder verifica una vez, tras fusionar. Tampoco agregues tests, constantes ni abstracciones que este
  issue no pida.
- Sin bases de datos reales, sin desplegar, sin llamar APIs de pago.
- Registra cada paso terminado, una línea con hora, en `.scratch/<feature>/logs/NN-progreso.md`
  (el vigía narra cada línea al líder: una línea por paso real, no un párrafo al final).
- Al terminar, agrega al final de ese log un bloque `== RESUMEN ==` con tres partes: archivos tocados, las decisiones que tomaste y el issue no fijaba, y la lista de prueba manual.
- Commit final en tu worktree con un mensaje que incluya lista de verificación manual y desviaciones.
```

Reglas para escribir issues que los agentes ejecutan bien:
- **Nombres compartidos decididos de antemano.** Si dos piezas paralelas necesitan el mismo helper,
  el issue fija su nombre, firma y archivo, y dice quién lo crea.
- **Qué no hacer, dicho en positivo:** "deja un TODO `// <feature> Ola 2` y un comportamiento seguro"
  en vez de "no implementes X".
- **Todo lo que dependa de la máquina** va en el issue: el agente no sabe que otro agente corre al lado.
- **Autocontenido y con tope:** cada lectura y cada comando del agente gasta consumo de Cursor. Dale los
  fragmentos en vez de mandarlo a buscarlos, y una lista cerrada de archivos.

## Prompt de lanzamiento (archivo `logs/NN-lanzar.md`)

Corto; el detalle vive en el issue:

```
Implementa el issue .scratch/<feature>/issues/NN-<slug>.md en este worktree.
Lee el issue completo y solo lo que referencia. Otros agentes trabajan en paralelo en <áreas>: no las toques.
No instales dependencias ni corras verificaciones (tipos, lint, tests, compilación): las corre el líder.
Registra avance en .scratch/<feature>/logs/NN-progreso.md.
Commit final en español neutro.
```

## Prompt para retomar un worktree a medias

```
Estás retomando el issue <ruta> en este worktree; otro agente lo dejó a medias sin commitear.
Paso 0: commit WIP y `git merge <rama-principal>` para traer lo ya fusionado; resuelve conflictos.
Revisa git status, git diff y logs/NN-progreso.md para ver qué está hecho, lee el issue y termínalo.
```

## Prompt de corrección tras revisión (archivo `logs/NN-revision.md`)

```
Revisión del commit <sha> (issue <ruta>). Corrige solo esto:
1. <problema concreto> → <resultado esperado>. Por qué: <consecuencia real>.
2. ...
No corras verificaciones. Registra avance y haz commit en este worktree.
```

## `ESTADO.md` (retomar tras reinicio o sesión nueva)

```markdown
# <Funcionalidad> — estado y cómo continuar
Última actualización: <fecha>

## Rol de Claude
Orquestador y revisor (skill `orquestar`). Modelos y reglas: bloque `## Orquestador` del CLAUDE.md.

## Avance
| # | Issue | Estado (fusionado / a medias en <ruta del worktree> / pendiente) |

## Siguientes pasos, en orden
## Pendiente del usuario
## Hallazgos de revisión ya resueltos (no repetirlos)
```

Prompt para el usuario tras reiniciar (si `claude --resume` no está disponible):

```
Continúa <funcionalidad>. Lee primero .scratch/<feature>/ESTADO.md y luego la spec y los issues
pendientes. Trabaja en modo orquestador (skill orquestar): los agentes de Cursor escriben el código,
tú revisas y fusionas. Empieza por <siguiente paso>.
```
