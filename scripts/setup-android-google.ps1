# MechAssist — finaliser Google Sign-In (Android) + Firestore
# Exécuter : powershell -ExecutionPolicy Bypass -File scripts/setup-android-google.ps1

$ErrorActionPreference = "Continue"
function Find-Keytool {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($r in @($env:JAVA_HOME, "${env:ProgramFiles}\Android\Android Studio\jbr", "${env:ProgramFiles}\Android\Android Studio\jre")) {
        if (-not $r) { continue }
        $p = Join-Path $r "bin\keytool.exe"
        if (Test-Path $p) { return $p }
        $p2 = Join-Path $r "keytool.exe"
        if (Test-Path $p2) { return $p2 }
    }
    $adopt = Get-ChildItem "${env:ProgramFiles}\Eclipse Adoptium" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($adopt) {
        $p = Join-Path $adopt.FullName "bin\keytool.exe"
        if (Test-Path $p) { return $p }
    }
    return $null
}

Write-Host ""
Write-Host "=== SHA-1 keystore DEBUG (colle-le dans Firebase) ===" -ForegroundColor Cyan
$ks = Join-Path $env:USERPROFILE ".android\debug.keystore"
$kt = Find-Keytool
if (-not $kt) {
    Write-Host "keytool introuvable. Ajoute JDK au PATH ou definis JAVA_HOME, puis relance ce script." -ForegroundColor Yellow
} elseif (-not (Test-Path $ks)) {
    Write-Host "Keystore introuvable : $ks (lance une fois flutter run sur Android pour le creer)." -ForegroundColor Yellow
} else {
    & $kt -list -v -keystore $ks -alias androiddebugkey -storepass android -keypass android 2>$null | Select-String "SHA1:"
}
Write-Host ""
Write-Host "Etapes Firebase (projet mechassist-ed9dc) :" -ForegroundColor Cyan
Write-Host "  1. https://console.firebase.google.com/project/mechassist-ed9dc/settings/general"
Write-Host "  2. Ton application Android > Ajouter empreinte SHA-1 (ci-dessus)"
Write-Host "  3. Retelecharge google-services.json et remplace frontend/android/app/google-services.json"
Write-Host ""
Write-Host "ID client Web (pour backend/.env GOOGLE_CLIENT_ID) :" -ForegroundColor Cyan
Write-Host "  1. https://console.cloud.google.com/apis/credentials?project=mechassist-ed9dc"
Write-Host "  2. Creer > ID client OAuth > Application Web > copier l'ID client dans backend/.env"
Write-Host "     (ou Firebase > Parametres > Vos applications > Web si deja cree)"
Write-Host ""
Write-Host "Regles Firestore (lecture mechanic_presence) :" -ForegroundColor Cyan
Write-Host "  Depuis la racine du depot : npm install && npx firebase login && npx firebase deploy --only firestore:rules --project mechassist-ed9dc"
Write-Host "  (firebase.json + firestore.rules sont deja a la racine)"
Write-Host ""
