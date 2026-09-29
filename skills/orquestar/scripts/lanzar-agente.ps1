<#
.SYNOPSIS
  Lanza un agente de Cursor CLI en un worktree (nuevo o existente) y deja un log con inicio/fin.

.DESCRIPTION
  Corre en primer plano hasta que el agente termina: invócalo con run_in_background.
  -Modelo acepta un nivel (complejo | sencillo | auto) o un id exacto de `cursor-agent models`.
  Escribe en el log:  "inicio ..."  al empezar,  "reintento-auto ..." si el modelo se quedó sin cupo y se reintentó solo con auto (mismo worktree),
  "cupo-agotado ..." si tampoco auto tuvo cupo (el líder pasa a Sonnet/Haiku),
  "fin ... exit=N"  o  "error ..."  al terminar,
  y deja el PID de este proceso en "<log>.pid" mientras vive (lo usa vigilar-agente.sh).

.EXAMPLE
  # Worktree nuevo a partir de la rama principal
  & .\lanzar-agente.ps1 -Nombre dp-05-motor -Modelo complejo -PromptFile .scratch\feat\logs\05-lanzar.md

.EXAMPLE
  # Retomar un worktree existente (conserva lo que quedó sin commit)
  & .\lanzar-agente.ps1 -Worktree "C:\Users\me\.cursor\worktrees\repo\dp-05-motor" -Modelo auto -PromptFile .scratch\feat\logs\05-retomar.md
#>
param(
  [string]$Nombre,
  [Parameter(Mandatory = $true)][string]$Modelo,
  [Parameter(Mandatory = $true)][string]$PromptFile,
  [string]$Worktree,
  [string]$Base = "",
  [string]$Log
)

$ErrorActionPreference = "Stop"
if (-not $Nombre -and -not $Worktree) { throw "Indica -Nombre (worktree nuevo) o -Worktree (retomar uno existente)." }
if (-not (Test-Path $PromptFile)) { throw "No existe el archivo de prompt: $PromptFile" }
if (-not (Get-Command cursor-agent -ErrorAction SilentlyContinue)) {
  throw "cursor-agent no está en el PATH. Instala Cursor CLI y ejecuta 'cursor-agent login'."
}
if ($Worktree -and -not (Test-Path $Worktree)) { throw "No existe el worktree: $Worktree" }

if (-not $Log) {
  $dir = Split-Path -Parent $PromptFile
  $stem = [System.IO.Path]::GetFileNameWithoutExtension($PromptFile)
  $Log = Join-Path $dir "$stem-cursor.out"
}

# -Modelo acepta un nivel (complejo | sencillo | auto) o un id exacto; en ambos casos se valida
# contra la lista real de la cuenta antes de gastar un agente. Ver resolver-modelo.ps1.
$Modelo = (& "$PSScriptRoot\resolver-modelo.ps1" $Modelo | Select-Object -Last 1)
if ($LASTEXITCODE -ne 0 -or -not $Modelo) { throw "No se pudo resolver el modelo (ver mensaje anterior)." }

$prompt = Get-Content -Raw -Encoding utf8 $PromptFile
$destino = if ($Worktree) { "worktree=$Worktree" } else { "nuevo=$Nombre" }
"inicio $(Get-Date -Format s) modelo=$Modelo $destino" | Out-File -Encoding utf8 $Log
"$PID" | Out-File -Encoding ascii "$Log.pid"

$patronCupo = 'out of usage|usage limit|Switch to Auto'

function Invoke-Agente([string]$modelo, [string]$destinoWorktree, [string]$texto) {
  $a = @("-p", "--model", $modelo, "--force", "--trust")
  if ($destinoWorktree) {
    $a += @("--workspace", $destinoWorktree)
  } else {
    $a += @("-w", $Nombre)
    if ($Base) { $a += @("--worktree-base", $Base) }
  }
  $a += $texto
  cursor-agent @a *>> $Log
  return $LASTEXITCODE
}

try {
  $codigo = Invoke-Agente $Modelo $Worktree $prompt
  $sinCupo = $codigo -ne 0 -and (Select-String -Path $Log -Pattern $patronCupo -Quiet)

  # Sin cupo con un modelo que no es auto: reintento automático con auto, en el mismo worktree
  # (el usuario no tiene que intervenir). Cascada completa en lanzar.md.
  if ($sinCupo -and $Modelo -ne "auto") {
    $repo = Split-Path -Leaf (git rev-parse --show-toplevel 2>$null)
    $wt = if ($Worktree) { $Worktree } elseif ($Nombre) { Join-Path $env:USERPROFILE ".cursor\worktrees\$repo\$Nombre" } else { "" }
    if ($wt -and -not (Test-Path $wt)) { $wt = "" }
    "reintento-auto $(Get-Date -Format s) sin-cupo=$Modelo" | Out-File -Append -Encoding utf8 $Log
    $desde = @(Get-Content $Log).Count   # solo mira lo que escriba el reintento
    $nota = "`n`n---`nNota: esta tarea ya se intentó con otro modelo. Antes de seguir, revisa `git status` y `git log` en este worktree y continúa desde donde quedó, sin rehacer lo que ya está."
    $codigo = Invoke-Agente "auto" $wt ($prompt + $nota)
    $Modelo = "auto"
    $sinCupo = $codigo -ne 0 -and [bool](@(Get-Content $Log | Select-Object -Skip $desde) -match $patronCupo)
  }

  # Cupo agotado incluso con auto: el vigía lo avisa como CUPO y el líder pasa a Sonnet/Haiku (lanzar.md).
  if ($sinCupo) {
    "cupo-agotado $(Get-Date -Format s) modelo=$Modelo" | Out-File -Append -Encoding utf8 $Log
  }
  "fin $(Get-Date -Format s) exit=$codigo" | Out-File -Append -Encoding utf8 $Log
} catch {
  "error $(Get-Date -Format s): $_" | Out-File -Append -Encoding utf8 $Log
  throw
} finally {
  Remove-Item -ErrorAction SilentlyContinue "$Log.pid"
}
