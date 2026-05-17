# Resout l'URL publique de l'API MechAssist (ngrok -> Laravel local :8000).
# Demarre ngrok si besoin, lit l'URL sur http://127.0.0.1:4040/api/tunnels.
#
# Usage :
#   . .\scripts\resolve-ngrok-api-url.ps1
#   $url = Resolve-MechassistApiUrl
#   - ou -
#   powershell -File scripts\resolve-ngrok-api-url.ps1

param(
    [int]$Port = 8000,
    [int]$MaxWaitSeconds = 45,
    [switch]$StartIfMissing = $true,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info([string]$Message) {
    if (-not $Quiet) {
        Write-Host $Message -ForegroundColor DarkGray
    }
}

function Get-NgrokExecutable {
    $candidates = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\ngrok.exe",
        "$env:LOCALAPPDATA\Programs\ngrok\ngrok.exe",
        "$env:ProgramFiles\ngrok\ngrok.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    $cmd = Get-Command ngrok -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-NgrokTunnelUrl([int]$TargetPort) {
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 4
        foreach ($tunnel in @($resp.tunnels)) {
            $addr = [string]$tunnel.config.addr
            $public = [string]$tunnel.public_url
            if ($public -notlike "https://*") { continue }
            $portSuffix = ":$TargetPort"
            if ($addr.EndsWith($portSuffix)) {
                return $public.TrimEnd("/")
            }
        }
        $anyHttps = @($resp.tunnels | Where-Object { $_.public_url -like "https://*" } | Select-Object -First 1)
        if ($anyHttps) {
            return ([string]$anyHttps.public_url).TrimEnd("/")
        }
    } catch {
        return $null
    }
    return $null
}

function Test-LaravelPort([int]$TargetPort) {
    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $client.Connect("127.0.0.1", $TargetPort)
        $client.Close()
        return $true
    } catch {
        return $false
    }
}

function Get-LanApiUrl([int]$TargetPort) {
    $list = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {
            $_.IPAddress -notmatch '^127\.' -and $_.IPAddress -notmatch '^169\.254\.'
        })
    if (-not $list) { return $null }
    $rfc = @($list | Where-Object {
            $_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)'
        })
    $pick = if ($rfc) { $rfc } else { $list }
    $ip = @($pick | Sort-Object @{
            Expression = {
                if ($_.InterfaceAlias -match 'Wi-Fi|WLAN|Wireless|802\.11') { 0 } else { 1 }
            }
        }, InterfaceMetric)[0].IPAddress
    if (-not $ip) { return $null }
    return "http://${ip}:$TargetPort"
}

function Resolve-MechassistApiUrl {
    param(
        [int]$TargetPort = 8000,
        [int]$WaitSeconds = 45,
        [bool]$AllowStart = $true
    )

    if (-not (Test-LaravelPort $TargetPort)) {
        Write-Info "Attention: rien n'ecoute sur 127.0.0.1:$TargetPort - lancez: php artisan serve --host=0.0.0.0 --port=$TargetPort"
    }

    $url = Get-NgrokTunnelUrl $TargetPort
    if ($url) {
        Write-Info "Tunnel ngrok actif: $url"
        return $url
    }

    $ngrok = Get-NgrokExecutable
    if (-not $ngrok) {
        Write-Info "ngrok introuvable - repli sur IP LAN."
        $lan = Get-LanApiUrl $TargetPort
        if ($lan) { return $lan }
        throw "ngrok introuvable et aucune IP LAN. Installez ngrok ou definissez API_BASE_URL."
    }

    if ($AllowStart) {
        $running = Get-Process -Name ngrok -ErrorAction SilentlyContinue
        if (-not $running) {
            Write-Info "Demarrage ngrok http $TargetPort ..."
            Start-Process -FilePath $ngrok -ArgumentList "http", "$TargetPort" -WindowStyle Minimized | Out-Null
        } else {
            Write-Info "ngrok deja lance - attente du tunnel port $TargetPort ..."
        }
    }

    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $url = Get-NgrokTunnelUrl $TargetPort
        if ($url) {
            Write-Info "Tunnel ngrok pret: $url"
            return $url
        }
    }

    Write-Info "Timeout ngrok - repli sur IP LAN (meme Wi-Fi requis sur telephone)."
    $lan = Get-LanApiUrl $TargetPort
    if ($lan) { return $lan }
    throw "Impossible d'obtenir une URL API (ngrok ou LAN). Verifiez ngrok et Laravel sur le port $TargetPort."
}

if ($MyInvocation.InvocationName -ne '.') {
    $resolved = Resolve-MechassistApiUrl -TargetPort $Port -WaitSeconds $MaxWaitSeconds -AllowStart:$StartIfMissing
    Write-Output $resolved
}
