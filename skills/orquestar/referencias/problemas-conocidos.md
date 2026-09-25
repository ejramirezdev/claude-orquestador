# Problemas conocidos

Cada entrada: síntoma → causa → arreglo. Todas ocurrieron de verdad.

## Agentes

**El agente terminó (hay commit) pero la tarea nunca avisa.**
Causa: el proceso quedó colgado después del trabajo — tests que esperan Redis/BD, o la CLI reintentando
la conexión con Cursor. Arreglo: el vigía avisa el `COMMIT`; revisa y termina el árbol de procesos
(`vigilar.md`). Prevención en el issue: tests que cierran sus conexiones y scripts de una sola corrida
que terminan con `process.exit`.

**`You're out of usage. Switch to Auto…`**
Causa: se agotó el cupo del plan de Cursor para ese modelo. Arreglo: relanza con `--model auto` en el
mismo worktree (`-Worktree`), y usa `auto` para todo hasta que el usuario diga otra cosa. Anótalo en el
bloque `## Orquestador` del `CLAUDE.md`.

**El agente no deja commit.**
Causa: lo olvidó o murió antes. Arreglo: si el diff está aprobado, commitea tú en su worktree; si está a
medias, relánzalo en modo "retomar".

**El agente no arranca** (sin worktree ni log, o `Cannot find module …index.js`).
- Windows, `Start-Process cursor-agent …` falla siempre: `cursor-agent` es un `.ps1`, no un `.exe`. Usa
  `scripts/lanzar-agente.ps1` o la invocación directa en la herramienta PowerShell con `run_in_background`.
- Bash de Git en Windows no encuentra `cursor-agent`: lánzalo desde PowerShell.
- Instalación corrupta (falta `index.js` en `%LOCALAPPDATA%\cursor-agent\versions\<versión>`): baja el
  paquete de esa misma versión
  (`https://downloads.cursor.com/lab/<versión>/windows/x64/agent-cli-package.zip`; prueba `windows` y
  `win32` con una petición HEAD), mueve a un lado la carpeta rota y copia `dist-package/*` en su lugar.
- Antivirus que intercepta TLS (p. ej. Kaspersky): exporta `NODE_EXTRA_CA_CERTS` con el certificado raíz
  del antivirus antes de lanzar.

**El agente hace `git push` y el servidor lo banea (fail2ban).**
Causa: el host del remoto no casa con ningún bloque de `~/.ssh/config`, así que SSH prueba llaves por
defecto y contraseña. Arreglo: agrega la IP/host exacto del remoto al bloque `Host` con su `IdentityFile`.

**Cientos de archivos "modificados" que no cambiaron.**
Causa: el agente usa una shell WSL y el repo está con `core.autocrlf=true` en Windows. Son finales de
línea. Arreglo: tareas de git/despliegue desde la shell nativa; a largo plazo, `.gitattributes`.

## Memoria

**Tareas en segundo plano "detenidas porque el sistema tiene poca memoria".**
Causa: Claude Code mata shells en segundo plano cuando la RAM se agota. Arreglo, en orden:
1. Menos agentes a la vez; que verifiquen UNO A LA VEZ y sin compilación completa hasta el final.
2. `scripts/revisar-recursos`: procesos `node` huérfanos de agentes muertos (tests, `tsx`, compiladores),
   copias duplicadas de herramientas (p. ej. la barra de estado), apps pesadas. Cierra lo que sobra.
3. **Memoria del kernel alta** (Windows: pool paginado + no paginado > ~2 GB) = un controlador que retiene
   memoria (antivirus, utilidades del fabricante, VPN). Solo se libera **reiniciando**. Antes de
   reiniciar, actualiza `ESTADO.md` y dale al usuario el prompt para retomar (`claude --resume` recupera
   la conversación).
4. Si aun así pasa: iniciar Claude Code con `CLAUDE_CODE_DISABLE_BG_SHELL_PRESSURE_REAP=1` evita que
   mate las tareas (a costa de que la máquina se ponga lenta).

**Compilar todas las apps a la vez agota la RAM** (p. ej. `turbo run build`). Compila una app a la vez;
para revisar el grafo de dependencias sin compilar: `turbo run build --dry=json`.

## Worktrees y repositorio

**Decenas de worktrees viejos** (gigas en `node_modules`). Ver `cerrar.md`, "Limpiar el worktree".

**`git merge` aborta: "untracked working tree files would be overwritten".** Un archivo sin trackear en
el checkout principal que la rama sí trae. Muévelo o bórralo (compara antes) y reintenta.

**Herramienta global rota tras reiniciar** (p. ej. `pnpm: …pnpm.exe: No such file`). A veces el
antivirus o una actualización quita el ejecutable. Revisa la carpeta global del paquete antes de
reinstalar: en pnpm había `pnpm-native.exe` y bastó copiarlo como `pnpm.exe`.

## Verificación

**Tipos rotos que "no son del diff"** (Next.js: `PageProps`, `AppRoutes`). Corre `next typegen` antes
de `tsc`; tras cambiar el esquema del ORM, regenera el cliente antes de verificar.

**Todo verde en local y falla el build de Docker.** Dependencia fuera del lockfile (`--frozen-lockfile`),
ciclo de dependencias entre paquetes, o assets inválidos. Antes de desplegar: `next build` de la app
afectada y `turbo run build --dry=json` buscando `cyclic`.

**Un build "pasó" pero había fallado.** Se leyó el código de salida de un `| tail`. Captura el código
de salida del comando real.

## Despliegue

**`sudo` pide contraseña en el servidor.** No asumas sudo sin contraseña: usa directorios del usuario
(`$HOME/...`) y variables de entorno para rutas de datos.

**Una imagen o versión "que existe" no existe.** El agente puede inventar etiquetas. Verifica con
`docker manifest inspect <imagen:tag>` antes de desplegar.

**Health check falla justo después de `up -d --build`.** El contenedor recién arranca; reintenta con
espera (hasta ~60 s) antes de declarar la falla.

## Coordinación

**Dos agentes crean la misma función con firmas distintas / choca un archivo compartido.** El issue debe
fijar de antemano nombres y dueños de lo compartido; al fusionar, unifica en una sola función.

**El usuario tuvo que preguntar "¿cómo va?".** Faltó el vigía o no se informó un evento. Todo agente
lanzado lleva vigía, y cada evento se informa en una o dos líneas.
