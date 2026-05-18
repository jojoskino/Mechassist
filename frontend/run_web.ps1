# MechAssist Web : UN seul serveur (port fixe), UN onglet navigateur, API locale.
# Relance safe : arrete l'ancien Flutter Web avant de demarrer.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$apiPort = if ($env:MECHASSIST_API_PORT) { [int]$env:MECHASSIST_API_PORT } else { 8000 }
$webPort = if ($env:MECHASSIST_WEB_PORT) { [int]$env:MECHASSIST_WEB_PORT } else { 53100 }
if ($webPort -eq $apiPort) {
    Write-Host "Port web $webPort = port API Laravel : conflit evite, utilisation de 53100." -ForegroundColor Yellow
    $webPort = 53100
}
$repoRoot = Split-Path $PSScriptRoot

# Ancienne instance Flutter (53100) + reliquats sur 8000 quand $port etait ecrase par l'API.
& (Join-Path $repoRoot "scripts\stop-flutter-web.ps1") -Ports @($webPort, 8000)

if (-not (& (Join-Path $repoRoot "scripts\wait-tcp-port-free.ps1") -Port $webPort)) {
    Write-Host "ERREUR: le port $webPort reste occupe. Fermez l'autre terminal Flutter ou executez:" -ForegroundColor Red
    Write-Host "  powershell -File scripts\stop-flutter-web.ps1" -ForegroundColor Yellow
    exit 1
}

$env:MECHASSIST_API_TARGET = "web"
. (Join-Path $repoRoot "scripts\mechassist-api-url.ps1") | Out-Null
$apiUrl = $env:API_BASE_URL

$url = "http://localhost:$webPort"
Write-Host ""
Write-Host "MechAssist Web -> $url" -ForegroundColor Cyan
Write-Host "API Laravel  -> $apiUrl" -ForegroundColor DarkGray
Write-Host "Relance : Ctrl+C puis .\flutter_run.ps1 (l'ancien serveur sera arrete automatiquement)." -ForegroundColor DarkGray
Write-Host ""

$openBrowserJob = Start-Job -ScriptBlock {
    param($listenPort)
    for ($i = 0; $i -lt 180; $i++) {
        try {
            $client = [System.Net.Sockets.TcpClient]::new()
            $client.Connect("127.0.0.1", $listenPort)
            $client.Close()
            Start-Process "http://localhost:$listenPort"
            return
        } catch {
            Start-Sleep -Seconds 1
        }
    }
} -ArgumentList $webPort

try {
    flutter run -d web-server `
        --web-port=$webPort `
        --web-hostname=localhost `
        --dart-define=API_BASE_URL=$apiUrl
    exit $LASTEXITCODE
}
finally {
    Stop-Job $openBrowserJob -ErrorAction SilentlyContinue
    Remove-Job $openBrowserJob -Force -ErrorAction SilentlyContinue
}
