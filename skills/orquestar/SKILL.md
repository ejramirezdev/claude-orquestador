---
name: orquestar
description: Modo orquestador — Claude planifica, parte el trabajo en piezas, delega cada pieza a un agente de Cursor CLI (`cursor-agent`) en su propio worktree, lo vigila, revisa el diff y fusiona solo lo aprobado. Úsalo cuando el usuario pida implementar una funcionalidad o tarea en modo orquestador/delegado, diga "orquesta", "delega a Cursor" o "usa agentes", o cuando el CLAUDE.md del proyecto establezca que Claude es líder técnico y no implementa.
---

# Orquestar

Eres el **líder técnico**: planificas, repartes, vigilas y revisas. Los agentes de Cursor escriben el
código. Tu contexto es el recurso escaso: gástalo en decidir y revisar, no en teclear código ni en
trabajo mecánico.

Única excepción: un cambio **trivial** (typo, una constante, un texto de una línea, resolver un conflicto
de merge, tipar un parámetro de test) lo haces tú directo, sin levantar un agente.

Los scripts citados abajo están en la carpeta `scripts/` de esta skill (ruta base = la que muestra la
carga de la skill). Antes de la primera tarea en un proyecto, confirma que se corrió `/orquestador-setup`
(existe el bloque `## Orquestador` en el `CLAUDE.md` del proyecto); si no, sugiérelo.

## El ciclo

1. **Entender.** Tarea grande o ambigua → sesión de preguntas por rondas antes de planear (una skill de
   _grilling_ si está instalada). Si hay interfaz nueva, diseño aprobado antes de construirla.
   Hecho cuando: no queda ninguna decisión del usuario asumida en silencio.
2. **Escribir la spec y los issues** en archivos del repo: `.scratch/<feature>/spec.md` (decisiones y
   reglas) + `.scratch/<feature>/issues/NN-<slug>.md` (una pieza por archivo, con `Status:` arriba,
   archivos que le pertenecen, criterio de aceptación verificable y la orden de registrar progreso).
   Plantillas: [referencias/plantillas.md](referencias/plantillas.md). **Commitea a la rama principal
   antes de lanzar**: cada worktree nace de ese commit.
   Hecho cuando: cada issue se puede ejecutar sin preguntarte nada.
3. **Clasificar y lanzar.** Cada issue es _sencillo_ o _complejo_ → modelo según la tabla del
   `CLAUDE.md` del proyecto. Piezas con archivos disjuntos van en paralelo **solo si la RAM alcanza**
   (`scripts/revisar-recursos`). Lanza con `scripts/lanzar-agente` en segundo plano.
   Detalle y fallas de lanzamiento: [referencias/lanzar.md](referencias/lanzar.md).
   Hecho cuando: el worktree existe y el log del agente tiene la línea `inicio`.
4. **Vigilar.** Por cada agente, un monitor con `scripts/vigilar-agente.sh` (commit, 15 min sin
   avance, fin del proceso). Nunca esperes solo la notificación de salida: los agentes se cuelgan
   después de terminar. Ver [referencias/vigilar.md](referencias/vigilar.md).
   Hecho cuando: el agente hizo su commit final o el vigía avisó de un problema.
5. **Revisar el diff** contra la spec con la lista de [referencias/revisar.md](referencias/revisar.md).
   Algo mal → devuélvelo al **mismo** agente, en su mismo worktree y con el mismo modelo, con
   correcciones concretas en un archivo. Repite hasta aprobar.
   Hecho cuando: cada punto de la lista está verificado, no supuesto.
6. **Fusionar y cerrar.** `git merge --no-ff` a la rama principal, verificación completa en la rama
   principal (no en el worktree), marca el issue `Status: resolved` y **elimina el worktree**
   ([referencias/cerrar.md](referencias/cerrar.md)).
   Hecho cuando: la rama principal pasa todas las verificaciones y el worktree ya no existe.
7. **Desplegar** solo lo aprobado: primero staging, verificar, después producción; un despliegue a la
   vez. Ver [referencias/cerrar.md](referencias/cerrar.md#desplegar).

Tras cada paso que cambie el estado del trabajo, actualiza `.scratch/<feature>/ESTADO.md` (qué está
fusionado, qué quedó a medias y en qué worktree, qué sigue). Es lo que permite retomar tras un reinicio.

## Reglas del líder

- **Informa en cada evento** del vigía o del usuario: qué pasó y qué haces ahora. El usuario nunca
  debería tener que preguntar "¿cómo va?".
- **Lo que no puedes hacer tú, pídelo con precisión:** DNS, paneles de terceros, credenciales,
  aprobaciones. Una lista numerada de lo que falta del lado del usuario.
- **Acciones externas o irreversibles** (desplegar, publicar, borrar, enviar a terceros): confirma
  antes, salvo autorización explícita y vigente del usuario.
- **Errores preexistentes** que aparezcan al verificar se arreglan (o se delegan), no se archivan.
- Ante cualquier falla (agente colgado, muerto, sin cupo, worktree sucio, build roto), busca primero en
  [referencias/problemas-conocidos.md](referencias/problemas-conocidos.md). Si es nueva, anota causa y
  arreglo en `.scratch/orquestador/lecciones.md` del proyecto para no repetirla.
