# Repare Gradle : SocketException, zip corrompu, timeout "exclusive access" sur gradle-*-bin.zip.
# Usage : powershell -ExecutionPolicy Bypass -File scripts/fix-flutter-android-build.ps1

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== Arret des daemons Gradle (deverrouille le zip du wrapper) ===" -ForegroundColor Cyan
Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" -ErrorAction SilentlyContinue |
    Where-Object {
        $_.CommandLine -and (
            $_.CommandLine -match 'GradleDaemon' -or
            $_.CommandLine -match 'org\.gradle\.launcher' -or
            $_.CommandLine -match 'GradleWrapperMain'
        )
    } |
    ForEach-Object {
        Write-Host "Stop PID $($_.ProcessId)"
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "=== Suppression caches wrapper Gradle 8.13 / 8.14 (verrous + telechargements partiels) ===" -ForegroundColor Cyan
$dists = Join-Path $env:USERPROFILE ".gradle\wrapper\dists"
if (Test-Path $dists) {
    Get-ChildItem $dists -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like "gradle-8.13*" -or $_.Name -like "gradle-8.14*"
    } | ForEach-Object {
        Write-Host "Suppression : $($_.FullName)"
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    Get-ChildItem $dists -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\.(lck|part)$' } | ForEach-Object {
        Write-Host "Suppression verrou/partiel : $($_.FullName)"
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    }
}

$frontend = Join-Path $PSScriptRoot "..\frontend" | Resolve-Path
Write-Host ""
Write-Host "=== gradlew --stop (si disponible) ===" -ForegroundColor Cyan
$android = Join-Path $frontend "android"
if (Test-Path (Join-Path $android "gradlew.bat")) {
    Push-Location $android
    & .\gradlew.bat --stop 2>$null
    Pop-Location
}

Write-Host ""
Write-Host "=== flutter clean (frontend) ===" -ForegroundColor Cyan
Push-Location $frontend
& flutter clean 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter introuvable dans le PATH." -ForegroundColor Yellow
    Pop-Location
    exit 1
}

Write-Host ""
Write-Host "=== flutter pub get ===" -ForegroundColor Cyan
& flutter pub get
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "=== Telechargement / verification Gradle (wrapper) ===" -ForegroundColor Cyan
Push-Location $android
& .\gradlew.bat --version
$g = $LASTEXITCODE
Pop-Location
Pop-Location

if ($g -ne 0) {
    Write-Host ""
    Write-Host "Echec gradlew. Ferme Android Studio, desactive VPN/antivirus temporairement, relance ce script." -ForegroundColor Yellow
    exit $g
}

Write-Host ""
Write-Host "OK. Lance : cd frontend ; flutter run" -ForegroundColor Green
Write-Host ""
exit 0
