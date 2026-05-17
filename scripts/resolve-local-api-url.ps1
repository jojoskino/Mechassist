# URL API locale (Laravel + PostgreSQL sur le PC).
# Usage : . .\scripts\resolve-local-api-url.ps1  puis  Resolve-LocalApiUrl -Target web

param(
    [ValidateSet("web", "android", "lan")]
    [string]$Target = "web",
    [int]$Port = 8000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-LanIPv4 {
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
    return $ip
}

function Resolve-LocalApiUrl {
    param(
        [string]$Mode = "web",
        [int]$BackendPort = 8000
    )

    switch ($Mode) {
        "web" {
            return "http://127.0.0.1:$BackendPort"
        }
        "android" {
            # Emulateur Android Studio
            return "http://10.0.2.2:$BackendPort"
        }
        "lan" {
            $ip = Get-LanIPv4
            if ($ip) {
                return "http://${ip}:$BackendPort"
            }
            return "http://127.0.0.1:$BackendPort"
        }
        default {
            return "http://127.0.0.1:$BackendPort"
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Write-Output (Resolve-LocalApiUrl -Mode $Target -BackendPort $Port)
}
