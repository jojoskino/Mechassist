# MechAssist Web : UN seul serveur (port fixe), UN onglet navigateur, API locale.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$port = if ($env:MECHASSIST_WEB_PORT) { [int]$env:MECHASSIST_WEB_PORT } else { 53100 }
$repoRoot = Split-Path $PSScriptRoot

# Evite 4 serveurs / 4 onglets quand on relance plusieurs fois.
& (Join-Path $repoRoot "scripts\stop-flutter-web.ps1") -Port $port

$env:MECHASSIST_API_TARGET = "web"
. (Join-Path $repoRoot "scripts\mechassist-api-url.ps1") | Out-Null
$apiUrl = $env:API_BASE_URL

$url = "http://localhost:$port"
Write-Host ""
Write-Host "MechAssist Web -> $url" -ForegroundColor Cyan
Write-Host "API Laravel  -> $apiUrl" -ForegroundColor DarkGray
Write-Host "Un seul onglet s'ouvrira (device web-server, pas Edge/Chrome auto x4)." -ForegroundColor DarkGray
Write-Host ""

# Ouvre le navigateur une fois quand le serveur ecoute (pas a chaque retry Flutter).
$openBrowserJob = Start-Job -ScriptBlock {
    param($listenPort)
    for ($i = 0; $i -lt 180; $i++) {
        try {
            $client = [System.Net.Sockets.TcpClient]::new()
            $client.Connect("127.0.0.1", $listenPort)
            $client.Close()
            Start-Process "http://localhost:$listenPort"
            return
        } catch {
            Start-Sleep -Seconds 1
        }
    }
} -ArgumentList $port

try {
    flutter run -d web-server `
        --web-port=$port `
        --web-hostname=localhost `
        --dart-define=API_BASE_URL=$apiUrl
    exit $LASTEXITCODE
}
finally {
    Stop-Job $openBrowserJob -ErrorAction SilentlyContinue
    Remove-Job $openBrowserJob -Force -ErrorAction SilentlyContinue
}
