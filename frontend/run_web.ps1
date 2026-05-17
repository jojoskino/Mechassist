# MechAssist — Web (navigateur) avec API Render par défaut.
# Choisit un port libre (évite l'erreur 10048 si 8120 est déjà pris).
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$apiUrl = "https://mechassist-api.onrender.com"
if ($env:API_BASE_URL) {
    $apiUrl = $env:API_BASE_URL.TrimEnd('/')
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
try {
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
} finally {
    $listener.Stop()
}

Write-Host ""
Write-Host "MechAssist Web -> http://localhost:$port" -ForegroundColor Cyan
Write-Host "API -> $apiUrl" -ForegroundColor DarkGray
Write-Host ""

flutter run -d web-server `
    --web-port=$port `
    --web-hostname=localhost `
    --dart-define=API_BASE_URL=$apiUrl
