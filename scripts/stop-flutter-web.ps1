# Libere le port Flutter Web (evite plusieurs serveurs / onglets zombies).
param(
    [int]$Port = 53100
)

$ErrorActionPreference = "SilentlyContinue"
$killed = 0

foreach ($conn in @(Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue)) {
    $pid = $conn.OwningProcess
    if (-not $pid) { continue }
    $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
    if (-not $proc) { continue }
    if ($proc.ProcessName -match 'dart|flutter|dartaotruntime') {
        Stop-Process -Id $pid -Force
        $killed++
    }
}

if ($killed -gt 0) {
    Write-Host "Port $Port libere ($killed processus Flutter/Dart arretes)." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 400
}
