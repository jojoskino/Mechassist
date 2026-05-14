# MechAssist (Flutter)

## CI

Un workflow GitHub Actions (`.github/workflows/ci.yml`) exécute `php artisan test` (backend) et `flutter analyze` / `flutter test` (frontend) sur push/PR vers `main` ou `master`.

## Démarrage rapide

- API Laravel : depuis `../backend`, `php artisan serve --host=127.0.0.1 --port=8000` (local). Pour un **téléphone sur le Wi‑Fi** : `php artisan serve --host=0.0.0.0 --port=8000` puis dans l’app **Aide**, URL `http://IP_LAN_DU_PC:8000`. **Ne pas ouvrir `http://0.0.0.0:8000` dans Edge/Chrome** : ce n’est pas une adresse valide pour un navigateur (`ERR_ADDRESS_INVALID`). Sur le **même PC**, teste avec `http://127.0.0.1:8000` ou `http://localhost:8000`.
- Documentation Swagger de l’API : `http://127.0.0.1:8000/api/documentation` (après `php artisan l5-swagger:generate` dans le backend).
- App : `flutter run` (Android) ou `.\run_web.ps1` (navigateur via `web-server`)
- Depuis l’app : écran **Aide** — saisir l’URL `http://IP_LAN_DU_PC:8000` puis **Enregistrer** et **Tester la connexion**. Sur **émulateur** Android, `10.0.2.2:8000` par défaut.
- **Téléphone + même URL au build** : à la racine du dépôt, `powershell -ExecutionPolicy Bypass -File scripts/flutter-android-with-lan-api.ps1` (détecte l’IP LAN et lance `flutter run` avec `--dart-define=API_BASE_URL=...`). Pour **seulement compiler** l’APK : ajouter `-BuildOnly` (APK dans `frontend/build/app/outputs/flutter-apk/`). Forcer l’URL : `-ApiBaseUrl "http://172.20.10.2:8000"`.
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
