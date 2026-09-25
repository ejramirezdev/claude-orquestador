# Orquestador — Claude como líder técnico, Cursor como equipo

Plugin para Claude Code. Claude deja de escribir el código él mismo y pasa a trabajar como líder
técnico:

1. **Entiende** la tarea (te hace preguntas por rondas si es grande o ambigua).
2. **Planifica**: escribe una spec y la parte en piezas pequeñas (issues), cada una en su archivo.
3. **Delega** cada pieza a un agente de **Cursor CLI** (`cursor-agent`) en su propio worktree de git,
   eligiendo el modelo según la dificultad (uno fuerte para lo complejo, uno rápido para lo sencillo,
   `auto` cuando se acaba el cupo de Cursor).
4. **Vigila** a cada agente con un script liviano (sin gastar tokens) que avisa cuando hay commit,
   cuando se estanca o cuando termina.
5. **Revisa** cada diff contra la spec y una lista de problemas reales (seguridad, privacidad,
   duplicados, versiones inventadas…) y lo devuelve al mismo agente hasta que esté bien.
6. **Fusiona**, verifica en la rama principal y **limpia** el worktree.
7. **Despliega** (si tu proyecto lo tiene): staging, verificación, producción.

Incluye las lecciones de muchas horas de uso real: agentes que se cuelgan después de terminar, agentes
que mueren por falta de memoria, cupo de Cursor agotado, worktrees basura que se acumulan, errores de
lanzamiento en Windows, y más (`skills/orquestar/referencias/problemas-conocidos.md`).

## Requisitos

- [Claude Code](https://claude.com/claude-code).
- **Cursor CLI** instalado y con sesión iniciada (`cursor-agent login`). Comprueba con
  `cursor-agent models`.
- Git. El proyecto debe ser un repositorio con al menos un commit.
- Windows: PowerShell (viene con el sistema). macOS/Linux: bash.

## Instalar

Desde Claude Code:

```
/plugin marketplace add ejramirezdev/claude-orquestador
/plugin install orquestador@orquestador
```

(O, para probarlo desde una carpeta local: `/plugin marketplace add C:\ruta\a\claude-orquestador`.)

## Usar

1. Abre Claude Code en tu proyecto y ejecuta **`/orquestador-setup`** una vez. Revisa Cursor, te pregunta
   qué modelos usar, escribe las reglas en el `CLAUDE.md` del proyecto y ajusta el `.gitignore`.
2. Pide cualquier tarea como siempre ("agrega pagos con tarjeta", "arregla el bug del carrito"). Claude
   planifica, delega y te va informando. También puedes invocarlo con **`/orquestar`**.

Consejos:
- En laptops de 16 GB o menos, inicia Claude Code con `CLAUDE_CODE_DISABLE_BG_SHELL_PRESSURE_REAP=1`
  (Windows PowerShell: `$env:CLAUDE_CODE_DISABLE_BG_SHELL_PRESSURE_REAP = "1"; claude`).
- Si tienes que reiniciar, `claude --resume` recupera la conversación; además cada funcionalidad deja un
  `.scratch/<feature>/ESTADO.md` para retomar desde cero.

## Pausar o quitar

- **Quitarlo de un proyecto:** `/orquestador-quitar`. Borra el bloque que el setup agregó al `CLAUDE.md`
  y sus líneas del `.gitignore` (van entre marcadores `orquestador:inicio`/`orquestador:fin`), te ofrece
  limpiar los worktrees ya fusionados y hace commit. No toca tu código, tus ramas ni tus specs.
- **Pausarlo en todos los proyectos:** `/plugin disable orquestador@orquestador` (y `/plugin enable …`
  para volver). Con el plugin desactivado, Claude trabaja de forma normal aunque el bloque siga en un
  `CLAUDE.md`: el propio bloque lo indica.
- **Desinstalarlo:** `/plugin uninstall orquestador@orquestador` y, opcionalmente,
  `/plugin marketplace remove orquestador`.

El plugin no instala hooks, no cambia la configuración de Claude Code y no deja procesos corriendo. Lo
único que escribe en un proyecto es lo que hace `/orquestador-setup`, y `/orquestador-quitar` lo deshace.

## Contenido

```
.claude-plugin/          manifiesto del plugin y del marketplace
skills/orquestar/        la metodología (SKILL.md) + referencias + scripts
  referencias/           lanzar, vigilar, revisar, cerrar, plantillas, problemas conocidos
  scripts/               lanzar-agente (.ps1/.sh), vigilar-agente.sh, revisar-recursos (.ps1/.sh),
                         limpiar-worktrees.sh
skills/orquestador-setup/  preparación del proyecto (se invoca a mano)
skills/orquestador-quitar/ deshace la preparación en un proyecto (se invoca a mano)
```
