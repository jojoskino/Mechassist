# Attend qu'un port TCP soit libre (pour relancer Flutter Web).
param(
    [Parameter(Mandatory)]
    [int]$Port,
    [int]$TimeoutSeconds = 15
)

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    $busy = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    if ($busy.Count -eq 0) { return $true }
    Start-Sleep -Milliseconds 250
}
return $false
