# MechAssist — iOS (Mac + Xcode). URL API ngrok auto.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$repoRoot = Split-Path $PSScriptRoot
. (Join-Path $repoRoot "scripts\mechassist-api-url.ps1") | Out-Null
$apiUrl = $env:API_BASE_URL

Write-Host ""
Write-Host "Appareils Flutter :" -ForegroundColor Cyan
& flutter devices
Write-Host ""
Write-Host "Lancement iOS..." -ForegroundColor Cyan
& flutter run --dart-define=API_BASE_URL=$apiUrl
