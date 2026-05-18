# Libere les ports Flutter Web (relance sans erreur "port deja utilise").
param(
    [int[]]$Ports = @(53100, 8000)
)

$ErrorActionPreference = "SilentlyContinue"
$flutterNames = '^(dart|flutter|dartaotruntime)$'
$killed = 0

function Stop-FlutterListenersOnPort {
    param([int]$Port)

    foreach ($conn in @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)) {
        $procId = $conn.OwningProcess
        if (-not $procId) { continue }
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if (-not $proc) { continue }
        if ($proc.ProcessName -match $flutterNames) {
            Stop-Process -Id $procId -Force
            $script:killed++
        }
    }
}

foreach ($p in $Ports) {
    Stop-FlutterListenersOnPort -Port $p
}

# Processus Flutter orphelins (parfois le port est deja libere).
Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -match $flutterNames } |
    ForEach-Object {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($cmd -match 'web-server|web-port|devtools|frontend_server') {
                Stop-Process -Id $_.Id -Force
                $script:killed++
            }
        } catch { }
    }

if ($killed -gt 0) {
    Write-Host "Flutter Web arrete ($killed processus, ports: $($Ports -join ', '))." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 600
}
