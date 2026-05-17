# MechAssist — lancer sur iPhone / simulateur iOS (nécessite un Mac avec Xcode).
# Sur Windows : compilation iOS impossible en local ; utilisez un Mac ou un service CI (Codex, Codemagic).
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host ""
Write-Host "Appareils Flutter :" -ForegroundColor Cyan
& flutter devices
Write-Host ""
Write-Host "Lancement iOS (API Render)..." -ForegroundColor Cyan
& flutter run --dart-define=API_BASE_URL=https://mechassist-api.onrender.com
