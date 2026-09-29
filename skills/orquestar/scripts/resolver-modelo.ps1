<#
.SYNOPSIS
  Resuelve un nivel de dificultad al id EXACTO de modelo que acepta `cursor-agent --model`.

.DESCRIPTION
  Lee la lista real de la cuenta (`cursor-agent --list-models`) e imprime solo el id.
    complejo  -> Grok más reciente, esfuerzo high
    sencillo  -> Composer más reciente
    auto      -> el modo automático de Cursor
    <id>      -> id explícito: solo se valida que exista
  Los ids no siguen un patrón único (`grok-4.7-high` vs `cursor-grok-4.6-high`), por eso nunca se arman a
  mano. Se prefiere la variante sin `-fast`. Si el esfuerzo pedido no existe para esa versión, se usa el
  más cercano hacia abajo (y, si no hay, hacia arriba). Sale con código 1 si no hay modelo.

.EXAMPLE
  & .\resolver-modelo.ps1 complejo
#>
param([Parameter(Mandatory = $true, Position = 0)][string]$Nivel)

$ErrorActionPreference = "Stop"
if (-not (Get-Command cursor-agent -ErrorAction SilentlyContinue)) {
  [Console]::Error.WriteLine("cursor-agent no está en el PATH"); exit 2
}

$ids = @(cursor-agent --list-models 2>$null | ForEach-Object {
  if ($_ -match '^([A-Za-z0-9._-]+) - ') { $Matches[1] }
})
if ($ids.Count -eq 0) {
  [Console]::Error.WriteLine("cursor-agent --list-models no devolvió modelos (¿sesión iniciada?)"); exit 1
}

function Get-Grok([string]$esfuerzo) {
  $versiones = $ids | ForEach-Object {
    if ($_ -match '^(?:cursor-)?grok-(\d+(?:\.\d+)*)-(?:low|medium|high|xhigh)(?:-fast)?$') { [version]$Matches[1] }
  } | Sort-Object -Unique
  if (-not $versiones) { return $null }
  $ver = ($versiones | Select-Object -Last 1).ToString()
  $orden = switch ($esfuerzo) {
    "high"   { "high", "medium", "low", "xhigh" }
    default  { "medium", "low", "high", "xhigh" }
  }
  foreach ($e in $orden) {
    foreach ($id in "grok-$ver-$e", "cursor-grok-$ver-$e", "grok-$ver-$e-fast", "cursor-grok-$ver-$e-fast") {
      if ($ids -contains $id) {
        if ($e -ne $esfuerzo) { [Console]::Error.WriteLine("aviso: Grok $ver no tiene esfuerzo '$esfuerzo'; se usa '$e'") }
        return $id
      }
    }
  }
  return $null
}

function Get-Composer {
  $versiones = $ids | ForEach-Object {
    if ($_ -match '^composer-(\d+(?:\.\d+)*)(?:-fast)?$') { [version]$Matches[1] }
  } | Sort-Object -Unique
  if (-not $versiones) { return $null }
  $ver = ($versiones | Select-Object -Last 1).ToString()
  foreach ($id in "composer-$ver", "composer-$ver-fast") { if ($ids -contains $id) { return $id } }
  return $null
}

$id = switch ($Nivel) {
  "complejo" { Get-Grok "high" }
  "sencillo" { Get-Composer }
  "auto"     { "auto" }
  default    { if ($ids -contains $Nivel) { $Nivel } else { $null } }
}

if (-not $id) {
  if ($Nivel -eq "complejo") { [Console]::Error.WriteLine("no hay ningún modelo Grok en la cuenta") }
  elseif ($Nivel -eq "sencillo") { [Console]::Error.WriteLine("no hay ningún modelo Composer en la cuenta") }
  else {
    [Console]::Error.WriteLine("el modelo '$Nivel' no existe en esta cuenta. Parecidos:")
    $raiz = $Nivel -replace '-(low|medium|high|xhigh|fast).*', ''
    $ids | Where-Object { $_ -like "*$raiz*" } | Select-Object -First 8 | ForEach-Object { [Console]::Error.WriteLine($_) }
  }
  exit 1
}
$id
