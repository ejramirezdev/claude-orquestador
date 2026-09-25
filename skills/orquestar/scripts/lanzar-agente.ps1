<#
.SYNOPSIS
  Lanza un agente de Cursor CLI en un worktree (nuevo o existente) y deja un log con inicio/fin.

.DESCRIPTION
  Corre en primer plano hasta que el agente termina: invócalo con run_in_background.
  Escribe en el log:  "inicio ..."  al empezar,  "fin ... exit=N"  o  "error ..."  al terminar,
  y deja el PID de este proceso en "<log>.pid" mientras vive (lo usa vigilar-agente.sh).

.EXAMPLE
  # Worktree nuevo a partir de la rama principal
  & .\lanzar-agente.ps1 -Nombre dp-05-motor -Modelo grok-4.7-high -PromptFile .scratch\feat\logs\05-lanzar.md

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

$prompt = Get-Content -Raw -Encoding utf8 $PromptFile
$destino = if ($Worktree) { "worktree=$Worktree" } else { "nuevo=$Nombre" }
"inicio $(Get-Date -Format s) modelo=$Modelo $destino" | Out-File -Encoding utf8 $Log
"$PID" | Out-File -Encoding ascii "$Log.pid"

$cliArgs = @("-p", "--model", $Modelo, "--force", "--trust")
if ($Worktree) {
  $cliArgs += @("--workspace", $Worktree)
} else {
  $cliArgs += @("-w", $Nombre)
  if ($Base) { $cliArgs += @("--worktree-base", $Base) }
}
$cliArgs += $prompt

try {
  cursor-agent @cliArgs *>> $Log
  "fin $(Get-Date -Format s) exit=$LASTEXITCODE" | Out-File -Append -Encoding utf8 $Log
} catch {
  "error $(Get-Date -Format s): $_" | Out-File -Append -Encoding utf8 $Log
  throw
} finally {
  Remove-Item -ErrorAction SilentlyContinue "$Log.pid"
}
