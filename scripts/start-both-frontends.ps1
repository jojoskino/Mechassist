# Ouvre 2 fenetres : client 53100 + mecanicien 53101
$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot | Split-Path
$frontend = Join-Path $repoRoot "frontend"

Write-Host "Demarrage API Laravel (8000)..." -ForegroundColor Cyan
& (Join-Path $repoRoot "scripts\start-backend.ps1") -Port 8000

Start-Process powershell -ArgumentList @(
    '-NoExit', '-ExecutionPolicy', 'Bypass',
    '-Command', "Set-Location '$frontend'; Write-Host 'CLIENT port 53100' -ForegroundColor Cyan; .\run_client.ps1"
)
Start-Sleep -Seconds 2
Start-Process powershell -ArgumentList @(
    '-NoExit', '-ExecutionPolicy', 'Bypass',
    '-Command', "Set-Location '$frontend'; Write-Host 'MECANICIEN port 53101' -ForegroundColor Cyan; .\run_mechanic.ps1"
)

Write-Host ""
Write-Host "Client     -> http://localhost:53100" -ForegroundColor Green
Write-Host "Mecanicien -> http://localhost:53101" -ForegroundColor Green
Write-Host "API        -> http://127.0.0.1:8000" -ForegroundColor DarkGray
