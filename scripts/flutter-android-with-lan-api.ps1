# Lance Flutter Android avec API_BASE_URL auto (ngrok, repli LAN).
# Prérequis : php artisan serve --host=0.0.0.0 --port=8000
#
# Usage :
#   powershell -ExecutionPolicy Bypass -File scripts/flutter-android-with-lan-api.ps1
#   ... -BuildOnly
#   ... -ApiBaseUrl "https://xxx.ngrok-free.dev"  (forcer)

param(
    [switch]$BuildOnly,
    [int]$Port = 8000,
    [string]$ApiBaseUrl = "",
    [string]$Device = ""
)

$ErrorActionPreference = "Stop"
$frontend = (Resolve-Path (Join-Path $PSScriptRoot "..\frontend")).Path

if ($ApiBaseUrl -and $ApiBaseUrl.Trim().Length -gt 0) {
    $base = $ApiBaseUrl.Trim().TrimEnd('/')
} else {
    . (Join-Path $PSScriptRoot "resolve-ngrok-api-url.ps1")
    $base = Resolve-MechassistApiUrl -TargetPort $Port
}

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
