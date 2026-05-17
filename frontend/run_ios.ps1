# MechAssist — iOS (Mac + Xcode). API locale (LAN si MECHASSIST_API_TARGET=lan).
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$env:MECHASSIST_API_TARGET = "lan"
$repoRoot = Split-Path $PSScriptRoot
. (Join-Path $repoRoot "scripts\mechassist-api-url.ps1") | Out-Null
$apiUrl = $env:API_BASE_URL

Write-Host ""
Write-Host "Appareils Flutter :" -ForegroundColor Cyan
& flutter devices
Write-Host ""
Write-Host "Lancement iOS..." -ForegroundColor Cyan
& flutter run --dart-define=API_BASE_URL=$apiUrl
