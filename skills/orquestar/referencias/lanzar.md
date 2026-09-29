# Lanzar agentes

## Elegir modelo

La tabla vigente vive en el bloque `## Orquestador` del `CLAUDE.md` del proyecto (la escribe
`/orquestador-setup`). Por defecto:

| Nivel | Ejemplos | Modelo que resuelve `-Modelo <nivel>` |
|---|---|---|
| `complejo` | seguridad, arquitectura, lógica nueva, varias partes del código a la vez, diseño, IA | **Grok más reciente**, esfuerzo `high` |
| `sencillo` | cambio mecánico de una pieza, correr un script ya escrito, commit, renombrar | **Composer más reciente** |
| `auto` | Cursor recomienda pasar a Auto (cupo del modelo agotado) | modo `auto` de Cursor, para todo |

Ante la duda, _complejo_: rehacer un diff malo cuesta más que el modelo caro.

**Nunca escribas a mano el id de un modelo Grok o Composer.** Los ids no siguen un patrón único
(`grok-4.7-high`, pero `cursor-grok-4.6-high`) y cambian con cada versión. Pasa el **nivel** a
`-Modelo`/`--modelo`: `scripts/resolver-modelo` lee `cursor-agent --list-models`, toma la versión más
alta de Grok (o de Composer), aplica el esfuerzo del nivel y valida que el id exista. Si esa versión no
trae el esfuerzo pedido, baja al más cercano y avisa por stderr. Así, cuando salga Grok 4.8 o 5, el plugin
lo usa solo.

**Si el usuario fija un modelo** (en la tabla del `CLAUDE.md` pone un id exacto en lugar de un nivel), se
respeta ese id tal cual: el script solo comprueba que exista. Una corrección vuelve al **mismo** agente
con el **mismo** modelo (usa el id ya resuelto, que queda en la línea `inicio` del log).

## Cascada cuando se acaba el cupo

Se degrada de a un escalón, y solo cuando el anterior falla por cupo. Cursor `auto` va **antes** que
Claude: nunca saltes directo a Sonnet.

1. **Grok / Composer** (según el nivel). Se intenta **siempre primero**: no hay forma de consultar el
   cupo restante sin gastarlo (la CLI no lo expone), y un intento sin cupo falla al instante y sin coste
   apreciable, así que el propio lanzamiento hace de sonda. Cuando Cursor renueva el cupo, la siguiente
   pieza vuelve sola a Grok/Composer.
2. **Cursor `auto`, reintento automático.** Si el agente muere con `You're out of usage. Switch to Auto…`,
   el lanzador **reintenta solo con `auto`** en el mismo worktree (con una nota para que continúe desde
   lo ya hecho), escribe `reintento-auto` en el log y el vigía emite `AUTO:`. No hay que intervenir:
   solo informa al usuario en una línea. `auto` también se usa con las piezas complejas.
3. **Claude**, solo si `auto` también responde sin cupo (`CUPO:` del vigía) **y el usuario confirma**
   (gasta el cupo de Claude: pregúntale en una línea antes de lanzar, y mientras esperas no dejes nada
   corriendo): subagente con la herramienta
   Agent e `isolation: "worktree"`, eligiendo el modelo por dificultad —`model: "sonnet"` para piezas
   complejas, `model: "haiku"` para las sencillas—. Para retomar un worktree que ya existe,
   indícale su ruta en el prompt. Informa al usuario. Los subagentes de Claude tienen su propio límite;
   si también se cortan, avisa al usuario y espera.

## Cuántos a la vez

Cada agente corre instalaciones, verificaciones de tipos y compilaciones: en una laptop de 16 GB, dos
agentes que compilan a la vez ya pueden agotar la RAM. Antes de lanzar, corre `scripts/revisar-recursos`
y decide:

- **≥ 8 GB libres:** hasta 3 en paralelo si sus archivos son disjuntos.
- **4–8 GB:** 1 o 2, y pídeles verificar UNO A LA VEZ y sin compilación completa salvo al final.
- **< 4 GB:** 1, y resuelve primero la causa (ver `problemas-conocidos.md`, "memoria").

Despliegues y todo lo que toque un recurso compartido (servidor, base de datos): **siempre de a uno**.

## Cómo lanzar

1. Escribe el prompt en `.scratch/<feature>/logs/NN-lanzar.md` (plantilla en `plantillas.md`). Nunca un
   prompt largo inline: el shell corta o interpreta caracteres (`$`, comillas).
2. Comprueba que el issue y la spec están **commiteados** en la rama principal.
3. Lanza en segundo plano (`run_in_background`):
   - Windows (herramienta PowerShell):
     `& "<skill>/scripts/lanzar-agente.ps1" -Nombre dp-NN-slug -Modelo <nivel|id> -PromptFile .scratch/<feature>/logs/NN-lanzar.md`
     Para retomar un worktree existente: `-Worktree "<ruta>"` en vez de crear uno nuevo.
   - macOS/Linux: `bash "<skill>/scripts/lanzar-agente.sh" --nombre dp-NN-slug --modelo <nivel|id> --prompt-file <ruta> [--worktree <ruta>]`
   El script escribe `inicio` y `fin exit=N` en `<prompt>-cursor.out` (p. ej.
   `logs/NN-lanzar-cursor.out`; o el que pases con `-Log`/`--log`) y deja su PID en `<log>.pid`.
   El worktree nuevo lo crea Cursor; su ruta real sale en `git worktree list` (en Windows suele ser
   `%USERPROFILE%\.cursor\worktrees\<repo>\<nombre>`).
4. ~30 s después confirma que el worktree existe (`git worktree list`) y que el log tiene `inicio`.
   Si no, ver "no arranca" en `problemas-conocidos.md`.
5. Arranca el vigía (`vigilar.md`) antes de seguir con otra cosa.

## Retomar trabajo a medias

Un agente muerto (memoria, cupo, colgado) deja su trabajo sin commit en el worktree. No lo tires:
relánzalo con `-Worktree <ruta>` y el prompt de "retomar" de `plantillas.md` (commit WIP → merge de la
rama principal → terminar). Si otra pieza se fusionó mientras tanto, ese merge evita conflictos al final.

## Cursor no disponible por otra causa

Sin cupo se aplica la cascada de arriba. Si Cursor falla por otra razón (no instalado, sin sesión, red
caída), no es un caso de cupo: arréglalo (`problemas-conocidos.md`, "El agente no arranca") o pregunta al
usuario antes de pasar a subagentes de Claude.
