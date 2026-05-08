# Prepare Gradle (verrous / cache) puis lance l'app sur Android (appareil par defaut si un seul).
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$repoRoot = Split-Path $PSScriptRoot
$fix = Join-Path $repoRoot "scripts\fix-flutter-android-build.ps1"
if (-not (Test-Path $fix)) {
    Write-Host "Script introuvable : $fix" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Preparation Gradle..." -ForegroundColor Cyan
powershell -NoProfile -ExecutionPolicy Bypass -File $fix
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Appareils Flutter :" -ForegroundColor Cyan
& flutter devices
Write-Host ""
Write-Host "Lancement (Ctrl+C pour arreter)..." -ForegroundColor Cyan
& flutter run
