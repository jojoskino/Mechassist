# MechAssist (Flutter)

## CI

Un workflow GitHub Actions (`.github/workflows/ci.yml`) exécute `php artisan test` (backend) et `flutter analyze` / `flutter test` (frontend) sur push/PR vers `main` ou `master`.

## Démarrage rapide

- API Laravel : depuis `../backend`, `php artisan serve --host=0.0.0.0 --port=8000`.
- **Lancement normal (recommandé)** : depuis `frontend/`, les scripts démarrent **ngrok** si besoin et injectent l’URL automatiquement :
  - Web : `.\run_web.ps1` ou `.\run.ps1`
  - Android : `.\run_android.ps1` ou `.\run.ps1 -Platform android`
  - iOS (Mac) : `.\run_ios.ps1`
- **Téléphone / APK** : `powershell -ExecutionPolicy Bypass -File scripts/flutter-android-with-lan-api.ps1` (ngrok auto, repli IP LAN).
- Swagger : `http://127.0.0.1:8000/api/documentation` (après `php artisan l5-swagger:generate` dans le backend).
- Surcharge manuelle : écran **Aide** (sans `/api` à la fin). Éviter `flutter run` seul : l’URL ngrok ne sera pas injectée.
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
