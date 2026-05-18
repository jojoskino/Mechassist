# MechAssist (Flutter)

## CI

Un workflow GitHub Actions (`.github/workflows/ci.yml`) exécute `php artisan test` (backend) et `flutter analyze` / `flutter test` (frontend) sur push/PR vers `main` ou `master`.

## Démarrage rapide

- **PostgreSQL local** : base `MechAssist_db` sur `127.0.0.1:5432` (voir `backend/.env`).
- **Ports fixes (obligatoires)** : API **8000** | client **53100** | mécanicien **53101**
- **2 terminaux** : `.\run_client.ps1` puis `.\run_mechanic.ps1` (ne jamais les deux sur 53100)
- **Ou une commande** : `powershell -File ..\scripts\start-both-frontends.ps1` (2 fenêtres)
- API seule : `.\start.ps1` ou `php artisan serve --port=8000`
- **`flutter run` seul** : menu Flutter normal ; évitez `chrome`/`edge` (multi-onglets), préférez `web-server`
- Une instance web : `.\flutter_run.ps1 -Role client` ou `-Role mechanic`
  - Android émulateur : `.\run_android.ps1` → `http://10.0.2.2:8000`
  - Téléphone physique (Wi‑Fi) : `powershell -ExecutionPolicy Bypass -File scripts/flutter-android-with-lan-api.ps1` → IP LAN du PC
- Swagger : `http://127.0.0.1:8000/api/documentation`
- Tunnel ngrok (optionnel) : `$env:MECHASSIST_TUNNEL='ngrok'` avant `.\run_web.ps1`
- **Pare-feu Windows** (souvent la cause si le test échoue) : une fois en PowerShell **administrateur**, à la racine du dépôt :  
  `powershell -ExecutionPolicy Bypass -File scripts/open-firewall-laravel-8000.ps1`

### Mot de passe oublié

- L’app appelle `POST /api/forgot-password` puis `POST /api/reset-password` (jeton reçu par e-mail).
- Le backend doit avoir une config **MAIL_** valide pour l’envoi réel ; en local, `MAIL_MAILER=log` enregistre le lien dans `storage/logs`.

## Build Android : erreur Gradle / `SocketException` au téléchargement

Souvent : **téléchargement Gradle coupé** (antivirus, VPN, pare-feu) ou **cache corrompu**, ou **trop de RAM** réservée à Gradle.

1. Depuis la racine du dépôt :  
   `powershell -ExecutionPolicy Bypass -File scripts/fix-flutter-android-build.ps1`
2. Puis : `cd frontend` → `flutter run`
3. Si ça échoue encore : désactive temporairement le **VPN** / l’inspection SSL de l’**antivirus** pour `java.exe`, ou teste une autre connexion réseau.

La config Android utilise **Gradle 8.13** (compatible AGP 8.11), `networkTimeout` du wrapper à 10 min, et une heap Gradle modérée (`android/gradle.properties`). Si tu vois **timeout exclusive access** sur un `.zip`, ferme Android Studio puis lance `scripts/fix-flutter-android-build.ps1` (il arrête les daemons Gradle et supprime le cache wrapper 8.13/8.14).
