# Attend qu'un port TCP soit libre (pour relancer Flutter Web).
param(
    [Parameter(Mandatory)]
    [int]$Port,
    [int]$TimeoutSeconds = 20
)

function Test-PortListening {
    param([int]$p)
    return (@(Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue)).Count -gt 0
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    if (-not (Test-PortListening -p $Port)) { return $true }
    Start-Sleep -Milliseconds 300
}
return -not (Test-PortListening -p $Port)
