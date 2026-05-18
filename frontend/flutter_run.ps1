# Remplacement recommande pour "flutter run" (Web : 1 onglet, port fixe 53100).
# Usage :
#   .\flutter_run.ps1
#   .\flutter_run.ps1 -d windows

param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$FlutterArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Test-ArgsSpecifyDevice {
    param([string[]]$Args)
    return ($Args -contains '-d')
}

function Test-ArgsWebBrowserDevice {
    param([string[]]$Args)
    for ($i = 0; $i -lt $Args.Count; $i++) {
        if ($Args[$i] -eq '-d' -and ($i + 1) -lt $Args.Count) {
            return ($Args[$i + 1].ToLower() -in @('chrome', 'edge', 'web-server'))
        }
    }
    return $false
}

function Test-ArgsBareFlutterRun {
    param([string[]]$Args)
    if ($Args.Count -eq 0) { return $true }
    $webFlags = @('--web-port', '--web-hostname', '-d', 'web-server', 'chrome', 'edge')
    foreach ($a in $Args) {
        if ($a -match '^--web-port') { return $true }
        if ($a -eq '-d' -or $a -in @('web-server', 'chrome', 'edge')) { return $true }
    }
    return $false
}

# Web (defaut ou chrome/edge/web-server) : toujours run_web.ps1 (arrete l'ancien, port 53100).
if (-not (Test-ArgsSpecifyDevice -Args $FlutterArgs) -or (Test-ArgsWebBrowserDevice -Args $FlutterArgs)) {
    if (Test-ArgsWebBrowserDevice -Args $FlutterArgs) {
        Write-Host "Navigateur auto Flutter -> web-server (port 53100, relance propre)." -ForegroundColor Yellow
    }
    & "$PSScriptRoot\run_web.ps1"
    exit $LASTEXITCODE
}

# "flutter run" avec flags web mais sans -d explicite
if (Test-ArgsBareFlutterRun -Args $FlutterArgs) {
    & "$PSScriptRoot\run_web.ps1"
    exit $LASTEXITCODE
}

& flutter run @FlutterArgs
exit $LASTEXITCODE
