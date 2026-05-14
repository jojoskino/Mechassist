# Lance Flutter Android avec API_BASE_URL = http://<IP_LAN_PC>:<port> (détection auto).
# Évite de saisir l’IP à la main dans l’app ; prérequis : Laravel sur le PC avec
#   php artisan serve --host=0.0.0.0 --port=8000
# (0.0.0.0 = écoute sur toutes les interfaces ; dans le navigateur du PC utilise http://127.0.0.1:8000.)
#
# Usage (depuis la racine du dépôt Mechassist, PowerShell) :
#   powershell -ExecutionPolicy Bypass -File scripts/flutter-android-with-lan-api.ps1
# Compilation APK debug uniquement (test sans appareil branché) :
#   powershell -ExecutionPolicy Bypass -File scripts/flutter-android-with-lan-api.ps1 -BuildOnly
# Forcer une URL :
#   powershell -ExecutionPolicy Bypass -File scripts/flutter-android-with-lan-api.ps1 -ApiBaseUrl "http://172.20.10.2:8000"
# Choisir l’appareil :
#   powershell -ExecutionPolicy Bypass -File scripts/flutter-android-with-lan-api.ps1 -Device "R58XXXX"

param(
    [switch]$BuildOnly,
    [int]$Port = 8000,
    [string]$ApiBaseUrl = "",
    [string]$Device = ""
)

$ErrorActionPreference = "Stop"
$frontend = (Resolve-Path (Join-Path $PSScriptRoot "..\frontend")).Path

function Get-PreferredLanIPv4 {
    $list = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {
            $_.IPAddress -notmatch '^127\.' -and $_.IPAddress -notmatch '^169\.254\.'
        })
    if (-not $list) { return $null }
    # RFC1918 / partage de connexion (172.16–172.31)
    $rfc = @($list | Where-Object {
            $_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)'
        })
    $pick = $rfc
    if (-not $pick) { $pick = $list }
    $wifiFirst = @($pick | Sort-Object @{
            Expression = {
                if ($_.InterfaceAlias -match 'Wi-Fi|WLAN|Wireless|802\.11') { 0 } else { 1 }
            }
        }, InterfaceMetric)
    return $wifiFirst[0].IPAddress
}

function Resolve-ApiBase {
    if ($ApiBaseUrl -and $ApiBaseUrl.Trim().Length -gt 0) {
        return $ApiBaseUrl.Trim().TrimEnd('/')
    }
    $ip = Get-PreferredLanIPv4
    if (-not $ip) {
        Write-Host ""
        Write-Host "ERREUR : aucune IPv4 utilisable (Wi‑Fi / Ethernet actif). Branche le réseau ou lance :" -ForegroundColor Red
        Write-Host "  -ApiBaseUrl `"http://172.20.10.2:$Port`"   (remplace par ton ipconfig)" -ForegroundColor Yellow
        exit 1
    }
    return "http://${ip}:$Port"
}

$base = Resolve-ApiBase
$define = "API_BASE_URL=$base"
Write-Host "Dart define : $define" -ForegroundColor Cyan
Write-Host "L’app appellera : ${base}/api ..." -ForegroundColor Gray

Push-Location $frontend
try {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw "flutter introuvable dans le PATH. Installe le SDK Flutter et rouvre le terminal."
    }

    if ($BuildOnly) {
        Write-Host "`n>>> flutter build apk --debug ..." -ForegroundColor Green
        flutter build apk --debug "--dart-define=$define"
        Write-Host "`nAPK : build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Green
    }
    else {
        $run = @('run', "--dart-define=$define")
        if ($Device) {
            $run += '-d', $Device
        }
        Write-Host "`n>>> flutter $($run -join ' ') ..." -ForegroundColor Green
        & flutter @run
    }
}
finally {
    Pop-Location
}
