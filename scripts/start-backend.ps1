# Demarre Laravel sur 0.0.0.0:8000 si le port est libre.
param(
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$backend = (Resolve-Path (Join-Path $PSScriptRoot "..\backend")).Path

function Test-PortListening([int]$p) {
    try {
        $c = [System.Net.Sockets.TcpClient]::new()
        $c.Connect("127.0.0.1", $p)
        $c.Close()
        return $true
    } catch {
        return $false
    }
}

if (Test-PortListening $Port) {
    Write-Host "Laravel deja actif sur le port $Port." -ForegroundColor DarkGray
    Write-Host "Si les donnees ne s'enregistrent pas, redemarrez Laravel (Ctrl+C puis relancez) apres modification du .env." -ForegroundColor DarkGray
    return
}

Push-Location $backend
try {
    $dbCheck = & php artisan db:show 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERREUR PostgreSQL / fichier .env invalide :" -ForegroundColor Red
        Write-Host $dbCheck
        Write-Host "Verifiez backend\.env (chaque commentaire doit commencer par #)." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "PostgreSQL OK ($((($dbCheck | Select-String 'Database').ToString() -replace '.*\.\s+','').Trim()))" -ForegroundColor DarkGray
}
finally {
    Pop-Location
}

Push-Location $backend
try {
    $storageLink = Join-Path $backend "public\storage"
    if (-not (Test-Path $storageLink)) {
        Write-Host "Lien storage public (photos)..." -ForegroundColor DarkGray
        php artisan storage:link 2>&1 | Out-Null
    }
}
finally {
    Pop-Location
}

Write-Host "Demarrage Laravel (port $Port)..." -ForegroundColor Cyan
Push-Location $backend
try {
    Start-Process -FilePath "php" `
        -ArgumentList "artisan", "serve", "--host=0.0.0.0", "--port=$Port" `
        -WorkingDirectory $backend `
        -WindowStyle Minimized
    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        if (Test-PortListening $Port) {
            Write-Host "Laravel pret: http://127.0.0.1:$Port" -ForegroundColor Green
            return
        }
        Start-Sleep -Milliseconds 400
    }
    Write-Host "Laravel demarre lentement - verifiez la fenetre php artisan serve." -ForegroundColor Yellow
}
finally {
    Pop-Location
}
