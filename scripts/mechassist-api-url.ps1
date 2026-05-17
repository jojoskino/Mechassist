# Charge l'URL API dans $env:API_BASE_URL (local par defaut, ngrok si MECHASSIST_TUNNEL=ngrok).
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "start-backend.ps1")

$target = if ($env:MECHASSIST_API_TARGET) { $env:MECHASSIST_API_TARGET } else { "web" }
$port = if ($env:MECHASSIST_API_PORT) { [int]$env:MECHASSIST_API_PORT } else { 8000 }

if ($env:MECHASSIST_TUNNEL -eq "ngrok") {
    . (Join-Path $PSScriptRoot "resolve-ngrok-api-url.ps1")
    $url = Resolve-MechassistApiUrl -TargetPort $port
} else {
    . (Join-Path $PSScriptRoot "resolve-local-api-url.ps1")
    $url = Resolve-LocalApiUrl -Mode $target -BackendPort $port
}

$env:API_BASE_URL = $url.TrimEnd("/")

Write-Host ""
Write-Host "API MechAssist (local PostgreSQL + Laravel) -> $env:API_BASE_URL" -ForegroundColor Cyan
Write-Host ""

return $env:API_BASE_URL
