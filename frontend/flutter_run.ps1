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

# Sans -d : Web local (evite menu + Edge qui ouvre 4 onglets).
if (-not (Test-ArgsSpecifyDevice -Args $FlutterArgs)) {
    & "$PSScriptRoot\run_web.ps1"
    exit $LASTEXITCODE
}

# chrome / edge / web-server : toujours via run_web.ps1 (port fixe, 1 onglet).
if (Test-ArgsWebBrowserDevice -Args $FlutterArgs) {
    Write-Host "Navigateur auto Flutter desactive -> web-server (1 onglet, port 53100)." -ForegroundColor Yellow
    & "$PSScriptRoot\run_web.ps1"
    exit $LASTEXITCODE
}

& flutter run @FlutterArgs
exit $LASTEXITCODE
