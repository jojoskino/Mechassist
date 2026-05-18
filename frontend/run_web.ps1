Write-Host "run_web.ps1 = client uniquement (port 53100)." -ForegroundColor Yellow
Write-Host "Mecanicien : .\run_mechanic.ps1 (port 53101)" -ForegroundColor Yellow
& "$PSScriptRoot\run_client.ps1" @args
