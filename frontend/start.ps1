# Demarre uniquement l'API Laravel (8000). Lancez ensuite 2 terminaux Flutter :
#   .\run_client.ps1
#   .\run_mechanic.ps1
$repoRoot = Split-Path $PSScriptRoot
& (Join-Path $repoRoot "scripts\start-backend.ps1") -Port 8000
