# Charge l'URL API (ngrok auto) dans $env:API_BASE_URL pour les scripts run_*.ps1.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "start-backend.ps1")
. (Join-Path $PSScriptRoot "resolve-ngrok-api-url.ps1")

$url = Resolve-MechassistApiUrl
$env:API_BASE_URL = $url.TrimEnd("/")

Write-Host ""
Write-Host "API MechAssist -> $env:API_BASE_URL" -ForegroundColor Cyan
Write-Host ""

return $env:API_BASE_URL
