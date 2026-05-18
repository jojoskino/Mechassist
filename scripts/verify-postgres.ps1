# Verifie que Laravel lit bien PostgreSQL (fichier .env + connexion).
$ErrorActionPreference = "Stop"
$backend = (Resolve-Path (Join-Path $PSScriptRoot "..\backend")).Path

Push-Location $backend
try {
    Write-Host "Verification .env et PostgreSQL..." -ForegroundColor Cyan
    php artisan config:clear | Out-Null
    php artisan db:show
    if ($LASTEXITCODE -ne 0) { exit 1 }

    $counts = php artisan tinker --execute="echo 'users='.\App\Models\User::count().' requests='.\App\Models\InterventionRequest::count();" 2>&1
    Write-Host $counts -ForegroundColor Green
    Write-Host "OK - les ecritures API iront dans PostgreSQL." -ForegroundColor Green
}
finally {
    Pop-Location
}
