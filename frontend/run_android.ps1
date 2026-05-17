# Prepare Gradle puis lance Android avec URL API ngrok auto.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$repoRoot = Split-Path $PSScriptRoot
. (Join-Path $repoRoot "scripts\mechassist-api-url.ps1") | Out-Null
$apiUrl = $env:API_BASE_URL

$fix = Join-Path $repoRoot "scripts\fix-flutter-android-build.ps1"
if (-not (Test-Path $fix)) {
    Write-Host "Script introuvable : $fix" -ForegroundColor Red
    exit 1
}

Write-Host "Preparation Gradle..." -ForegroundColor Cyan
powershell -NoProfile -ExecutionPolicy Bypass -File $fix
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Appareils Flutter :" -ForegroundColor Cyan
& flutter devices
Write-Host ""
Write-Host "Lancement Android (Ctrl+C pour arreter)..." -ForegroundColor Cyan
& flutter run --dart-define=API_BASE_URL=$apiUrl
