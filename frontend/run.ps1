# MechAssist — lancement standard (ngrok + API auto, puis Flutter).
# Usage : depuis frontend/
#   .\run.ps1
#   .\run.ps1 -Platform web
#   .\run.ps1 -Platform android
param(
    [ValidateSet("web", "android", "ios")]
    [string]$Platform = "web"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$launcher = Join-Path $PSScriptRoot "run_$Platform.ps1"
if (-not (Test-Path $launcher)) {
    Write-Host "Script introuvable : $launcher" -ForegroundColor Red
    exit 1
}

& $launcher
