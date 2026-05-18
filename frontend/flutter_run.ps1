# Client = 53100 | Mecanicien = 53101 | API Laravel = 8000 (jamais le meme port).
# Usage :
#   .\run_client.ps1
#   .\run_mechanic.ps1
#   .\flutter_run.ps1 -Role client
#   flutter run -d web-server --web-port=53101  (mecanicien uniquement sur 53101)

param(
    [ValidateSet('', 'client', 'mechanic')]
    [string]$Role = '',
    [switch]$OpenBrowser,
    [switch]$Force,
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$FlutterArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$repoRoot = Split-Path $PSScriptRoot
. (Join-Path $repoRoot "scripts\resolve-flutter-web-port.ps1")

function Test-ArgsContainWebPort {
    param([string[]]$Args, [ref]$PortOut)
    for ($i = 0; $i -lt $Args.Count; $i++) {
        if ($Args[$i] -match '^--web-port=(\d+)$') {
            $PortOut.Value = [int]$Matches[1]
            return $true
        }
        if ($Args[$i] -eq '--web-port' -and ($i + 1) -lt $Args.Count) {
            $PortOut.Value = [int]$Args[$i + 1]
            return $true
        }
    }
    return $false
}

function Test-ArgsDevice {
    param([string[]]$Args)
    for ($i = 0; $i -lt $Args.Count; $i++) {
        if ($Args[$i] -eq '-d' -and ($i + 1) -lt $Args.Count) {
            return $Args[$i + 1].ToLower()
        }
    }
    return $null
}

function Test-ArgsContainApiDefine {
    param([string[]]$Args)
    foreach ($a in $Args) {
        if ($a -match '^--dart-define=API_BASE_URL=') { return $true }
    }
    return $false
}

function Start-MechassistReadyWatcher {
    param([int]$Port, [string]$Label, [switch]$OpenBrowser)
    return Start-Job -ScriptBlock {
        param($listenPort, $roleLabel, $open)
        $url = "http://localhost:$listenPort"
        for ($i = 0; $i -lt 180; $i++) {
            try {
                $client = [System.Net.Sockets.TcpClient]::new()
                $client.Connect('127.0.0.1', $listenPort)
                $client.Close()
                Write-Output ""
                Write-Output "=============================================="
                Write-Output " $roleLabel PRET : $url"
                Write-Output "=============================================="
                if ($open) { Start-Process $url }
                return
            } catch {
                Start-Sleep -Seconds 1
            }
        }
    } -ArgumentList $Port, $Label, $OpenBrowser.IsPresent
}

function Invoke-MechassistWebRun {
    param(
        [ValidateSet('client', 'mechanic')]
        [string]$Role,
        [int]$WebPort,
        [string[]]$ExtraArgs
    )

    Assert-MechassistWebPortForRole -Role $Role -Port $WebPort

    $otherPort = if ($Role -eq 'client') { $script:MechassistMechanicWebPort } else { $script:MechassistClientWebPort }
    if (Test-MechassistPortListening -Port $WebPort) {
        if (-not $Force) {
            Write-Host ""
            Write-Host "$Role deja actif : http://localhost:$WebPort" -ForegroundColor Green
            Write-Host "L'autre role reste sur http://localhost:$otherPort" -ForegroundColor DarkGray
            Write-Host "Relance forcee : .\run_$Role.ps1 -Force" -ForegroundColor DarkGray
            Write-Host ""
            if ($OpenBrowser) { Start-Process "http://localhost:$WebPort" }
            return
        }
    }

    & (Join-Path $repoRoot "scripts\stop-flutter-web.ps1") -Ports @($WebPort)
    Start-Sleep -Milliseconds 400

    if (-not (& (Join-Path $repoRoot "scripts\wait-tcp-port-free.ps1") -Port $WebPort)) {
        Write-Host "ERREUR: port $WebPort occupe (pas Laravel). Essayez -Force ou:" -ForegroundColor Red
        Write-Host "  powershell -File scripts\stop-flutter-web.ps1 -Ports $WebPort" -ForegroundColor Yellow
        exit 1
    }

    $env:MECHASSIST_API_TARGET = 'web'
    . (Join-Path $repoRoot "scripts\mechassist-api-url.ps1") | Out-Null
    $apiUrl = $env:API_BASE_URL

    $label = if ($Role -eq 'client') { 'CLIENT (53100)' } else { 'MECANICIEN (53101)' }
    $appUrl = "http://localhost:$WebPort"

    Write-Host ""
    Write-Host "=== $label ===" -ForegroundColor Cyan
    Write-Host "App  -> $appUrl" -ForegroundColor White
    Write-Host "API  -> $apiUrl (port $($script:MechassistApiPort))" -ForegroundColor DarkGray
    Write-Host "Autre instance -> http://localhost:$otherPort" -ForegroundColor DarkGray
    Write-Host "Attendez ~30 s le message SERVEUR PRET." -ForegroundColor Yellow
    Write-Host ""

    $readyJob = Start-MechassistReadyWatcher -Port $WebPort -Label $label -OpenBrowser:$OpenBrowser
    try {
        & flutter run -d web-server `
            --web-port=$WebPort `
            --web-hostname=localhost `
            --dart-define=API_BASE_URL=$apiUrl `
            @ExtraArgs
        exit $LASTEXITCODE
    }
    finally {
        Receive-Job $readyJob -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
        Stop-Job $readyJob -ErrorAction SilentlyContinue
        Remove-Job $readyJob -Force -ErrorAction SilentlyContinue
    }
}

# --- Roles fixes : client 53100, mecanicien 53101 ---
if ($Role -eq 'client') {
    Invoke-MechassistWebRun -Role client -WebPort $script:MechassistClientWebPort -ExtraArgs $FlutterArgs
    exit $LASTEXITCODE
}
if ($Role -eq 'mechanic') {
    Invoke-MechassistWebRun -Role mechanic -WebPort $script:MechassistMechanicWebPort -ExtraArgs $FlutterArgs
    exit $LASTEXITCODE
}

# --- web-server avec --web-port explicite : verifier qu'il n'est pas 8000 ni le mauvais role ---
$portFromArgs = 0
$hasPort = Test-ArgsContainWebPort -Args $FlutterArgs -PortOut ([ref]$portFromArgs)
$device = Test-ArgsDevice -Args $FlutterArgs

if ($hasPort) {
    if ($portFromArgs -eq $script:MechassistApiPort) {
        Write-Host "ERREUR: --web-port=$portFromArgs = port API Laravel. Utilisez 53100 (client) ou 53101 (mecanicien)." -ForegroundColor Red
        exit 1
    }
    if ($portFromArgs -eq $script:MechassistClientWebPort) {
        Write-Host "Astuce: pour le client preferez .\run_client.ps1" -ForegroundColor DarkGray
    }
    if ($portFromArgs -eq $script:MechassistMechanicWebPort) {
        Write-Host "Astuce: pour le mecanicien preferez .\run_mechanic.ps1" -ForegroundColor DarkGray
    }
}

if ($device -eq 'web-server' -and -not $hasPort) {
    $webPort = Get-MechassistFlutterWebPort -Role auto
    & (Join-Path $repoRoot "scripts\stop-flutter-web.ps1") -Ports @($webPort)
    if (-not (Test-ArgsContainApiDefine -Args $FlutterArgs)) {
        $env:MECHASSIST_API_TARGET = 'web'
        . (Join-Path $repoRoot "scripts\mechassist-api-url.ps1") | Out-Null
        $FlutterArgs += "--dart-define=API_BASE_URL=$($env:API_BASE_URL)"
    }
    Write-Host "web-server port auto : $webPort -> http://localhost:$webPort" -ForegroundColor Cyan
    & flutter run @FlutterArgs -d web-server --web-port=$webPort --web-hostname=localhost
    exit $LASTEXITCODE
}

if ($device -in @('chrome', 'edge')) {
    Write-Host "Chrome/Edge ouvre souvent plusieurs onglets. Preferez:" -ForegroundColor Yellow
    Write-Host "  .\run_client.ps1   -> port 53100" -ForegroundColor DarkGray
    Write-Host "  .\run_mechanic.ps1 -> port 53101" -ForegroundColor DarkGray
}

& flutter run @FlutterArgs
exit $LASTEXITCODE
