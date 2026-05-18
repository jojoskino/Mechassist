# Depuis backend/ : verifie PostgreSQL (delegue au script racine).
$repoRoot = Split-Path $PSScriptRoot
& (Join-Path $repoRoot "scripts\verify-postgres.ps1")
exit $LASTEXITCODE
