# Libere UNIQUEMENT le(s) port(s) Flutter demande(s). Ne touche pas a l'autre instance (client/mecanicien).
param(
    [int[]]$Ports = @()
)

$ErrorActionPreference = "SilentlyContinue"
$flutterNames = '^(dart|flutter|dartaotruntime)$'
$killed = 0

if ($Ports.Count -eq 0) {
    . (Join-Path $PSScriptRoot "resolve-flutter-web-port.ps1")
    $Ports = @($script:MechassistClientWebPort, $script:MechassistMechanicWebPort)
}

function Stop-FlutterOnPort {
    param([int]$Port)

    foreach ($conn in @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)) {
        $procId = $conn.OwningProcess
        if (-not $procId) { continue }
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if (-not $proc) { continue }
        if ($proc.ProcessName -match $flutterNames) {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            $script:killed++
        }
    }

    $portPattern = [regex]::Escape("--web-port=$Port")
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match $flutterNames } |
        ForEach-Object {
            try {
                $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
                if ($cmd -and $cmd -match $portPattern) {
                    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
                    $script:killed++
                }
            } catch { }
        }
}

foreach ($p in $Ports) {
    Stop-FlutterOnPort -Port $p
}

# Reliquats Flutter sur 8000 seulement (jamais PHP/Laravel).
Stop-FlutterOnPort -Port 8000

if ($killed -gt 0) {
    Write-Host "Flutter arrete sur port(s) $($Ports -join ', ') ($killed processus)." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 600
}
