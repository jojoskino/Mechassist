# MechAssist — Web sans ouverture auto de Chrome (contourne "Failed to launch browser").
# Après le démarrage, ouvre dans le navigateur : http://localhost:8120
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
flutter run -d web-server --web-port=8120 --web-hostname=localhost
