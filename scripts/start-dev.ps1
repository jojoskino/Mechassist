# API Laravel 8000 seulement. Pour 2 frontends : run_client.ps1 + run_mechanic.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot | Split-Path

Write-Host ""
Write-Host "API Laravel -> http://127.0.0.1:8000" -ForegroundColor Cyan
Write-Host "Puis dans 2 terminaux (frontend/) :" -ForegroundColor White
Write-Host "  .\run_client.ps1    -> http://localhost:53100" -ForegroundColor DarkGray
Write-Host "  .\run_mechanic.ps1  -> http://localhost:53101" -ForegroundColor DarkGray
Write-Host ""

& (Join-Path $repoRoot "scripts\start-backend.ps1") -Port 8000
