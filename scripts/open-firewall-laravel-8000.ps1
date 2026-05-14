# Ouvre le port TCP 8000 (Laravel `php artisan serve`) aux appareils sur le même réseau local.
# À lancer une fois en PowerShell **Administrateur** depuis la racine du dépôt :
#   powershell -ExecutionPolicy Bypass -File scripts/open-firewall-laravel-8000.ps1

$ruleName = "MechAssist Laravel dev port 8000"
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Règle pare-feu déjà présente : $ruleName"
    Write-Host "Navigateur sur ce PC : http://127.0.0.1:8000 (pas http://0.0.0.0:8000)."
    exit 0
}

try {
    New-NetFirewallRule -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 8000 `
        -Action Allow `
        -Profile Private,Domain,Public `
        -Description "Autorise les téléphones / tablettes sur le Wi-Fi local à joindre php artisan serve --host=0.0.0.0 --port=8000" `
        -ErrorAction Stop
    Write-Host "OK : règle pare-feu créée ($ruleName). Profils Private/Domain."
    Write-Host "Navigateur sur ce PC : http://127.0.0.1:8000 (pas http://0.0.0.0:8000 — Edge refuse 0.0.0.0)."
    Write-Host "Si le téléphone ne passe toujours pas, vérifie que le PC et le téléphone sont sur le même Wi-Fi et que l'URL dans l'app est http://IP_LAN_DU_PC:8000 (ipconfig)."
} catch {
    Write-Host "Échec pare-feu (lance ce script en PowerShell administrateur) : $_" -ForegroundColor Red
    exit 1
}
