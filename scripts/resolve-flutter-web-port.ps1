# Ports Flutter Web fixes (ne jamais inverser).
$script:MechassistClientWebPort = 53100
$script:MechassistMechanicWebPort = 53101
$script:MechassistApiPort = 8000

function Test-MechassistPortListening {
    param([int]$Port)
    return (@(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)).Count -gt 0
}

function Get-MechassistFlutterWebPort {
    param(
        [ValidateSet('client', 'mechanic', 'auto')]
        [string]$Role = 'auto'
    )

    if ($Role -eq 'client') { return $script:MechassistClientWebPort }
    if ($Role -eq 'mechanic') { return $script:MechassistMechanicWebPort }

    # auto : client libre -> 53100, sinon mecanicien -> 53101, sinon 53102+
    if (-not (Test-MechassistPortListening -Port $script:MechassistClientWebPort)) {
        return $script:MechassistClientWebPort
    }
    if (-not (Test-MechassistPortListening -Port $script:MechassistMechanicWebPort)) {
        return $script:MechassistMechanicWebPort
    }
    foreach ($p in 53102..53109) {
        if (-not (Test-MechassistPortListening -Port $p)) { return $p }
    }
    throw "Ports 53100-53101 occupes. Fermez une instance ou: stop-flutter-web.ps1 -Ports 53100,53101"
}

function Assert-MechassistWebPortForRole {
    param(
        [ValidateSet('client', 'mechanic')]
        [string]$Role,
        [int]$Port
    )
    $expected = if ($Role -eq 'client') { $script:MechassistClientWebPort } else { $script:MechassistMechanicWebPort }
    if ($Port -ne $expected) {
        throw "Le role '$Role' doit utiliser le port $expected, pas $Port."
    }
}
