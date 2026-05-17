# MechAssist — Web (navigateur). API locale http://127.0.0.1:8000 + PostgreSQL sur le PC.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$env:MECHASSIST_API_TARGET = "web"
$repoRoot = Split-Path $PSScriptRoot
. (Join-Path $repoRoot "scripts\mechassist-api-url.ps1") | Out-Null
$apiUrl = $env:API_BASE_URL

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
try {
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
} finally {
    $listener.Stop()
}

Write-Host "MechAssist Web -> http://localhost:$port" -ForegroundColor Cyan

$device = if ($env:MECHASSIST_WEB_DEVICE) { $env:MECHASSIST_WEB_DEVICE } else { "web-server" }

flutter run -d $device `
    --web-port=$port `
    --web-hostname=localhost `
    --dart-define=API_BASE_URL=$apiUrl
