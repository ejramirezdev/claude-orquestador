<#
.SYNOPSIS
  Diagnóstico de memoria antes de lanzar agentes (Windows). Solo lee; no mata nada.
  Imprime: RAM libre, memoria retenida por el kernel, procesos node por tipo y una recomendación
  de cuántos agentes lanzar a la vez.
#>
$os = Get-CimInstance Win32_OperatingSystem
$libreGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
"RAM libre: $libreGB GB de $totalGB GB"

try {
  $c = Get-Counter '\Memory\Pool Nonpaged Bytes', '\Memory\Pool Paged Bytes' -ErrorAction Stop
  $pool = ($c.CounterSamples | Measure-Object CookedValue -Sum).Sum / 1GB
  "Memoria del kernel (pool paginado + no paginado): {0:N1} GB" -f $pool
  if ($pool -gt 2.5) {
    "  ALTA: probablemente un controlador retiene memoria (antivirus, utilidades del fabricante, VPN)."
    "  Solo se libera reiniciando. Antes: actualiza ESTADO.md y deja el prompt para retomar."
  }
} catch { "Memoria del kernel: no disponible ($_)" }

""
"Procesos node (agentes, tests, compiladores, herramientas):"
$nodes = Get-CimInstance Win32_Process -Filter "Name='node.exe'"
$nodes | ForEach-Object {
  $cmd = [string]$_.CommandLine
  $tipo = switch -Regex ($cmd) {
    'cursor-agent.*index.*\s-p(\s|$)' { 'agente cursor (-p)'; break }
    'cursor-agent.*index' { 'cursor interactivo'; break }
    'ccstatusline|statusline' { 'barra de estado'; break }
    'next.*(build|dev)|next-server' { 'next'; break }
    'tsc|typescript' { 'tsc'; break }
    'tsx|vitest|jest|test' { 'tests'; break }
    default { 'otro' }
  }
  [pscustomobject]@{ Tipo = $tipo; PID = $_.ProcessId; PadrePID = $_.ParentProcessId; MB = [int]($_.WorkingSetSize / 1MB); Inicio = $_.CreationDate }
} | Sort-Object Tipo, Inicio | Format-Table -AutoSize

$agentes = @($nodes | Where-Object { [string]$_.CommandLine -match 'cursor-agent.*index.*\s-p(\s|$)' }).Count
"Agentes de Cursor corriendo: $agentes"
""
$recomendado = if ($libreGB -ge 8) { 3 } elseif ($libreGB -ge 4) { 1 } else { 0 }
if ($recomendado -eq 0) {
  "Recomendación: NO lances más agentes. Cierra procesos huérfanos (tests/tsx/next de agentes ya muertos, copias repetidas de herramientas) o reinicia."
} else {
  "Recomendación: hasta $recomendado agente(s) en paralelo (restando los que ya corren), verificando UNO A LA VEZ."
}
