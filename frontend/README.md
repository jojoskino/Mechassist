# MechAssist (Flutter)

## Démarrage rapide

- API Laravel : depuis `../backend`, `php artisan serve --host=127.0.0.1 --port=8000`
- App : `flutter run` (Android) ou `.\run_web.ps1` (navigateur via `web-server`)

## Build Android : erreur Gradle / `SocketException` au téléchargement

Souvent : **téléchargement Gradle coupé** (antivirus, VPN, pare-feu) ou **cache corrompu**, ou **trop de RAM** réservée à Gradle.

1. Depuis la racine du dépôt :  
   `powershell -ExecutionPolicy Bypass -File scripts/fix-flutter-android-build.ps1`
2. Puis : `cd frontend` → `flutter run`
3. Si ça échoue encore : désactive temporairement le **VPN** / l’inspection SSL de l’**antivirus** pour `java.exe`, ou teste une autre connexion réseau.

La config Android utilise **Gradle 8.13** (compatible AGP 8.11), `networkTimeout` du wrapper à 10 min, et une heap Gradle modérée (`android/gradle.properties`). Si tu vois **timeout exclusive access** sur un `.zip`, ferme Android Studio puis lance `scripts/fix-flutter-android-build.ps1` (il arrête les daemons Gradle et supprime le cache wrapper 8.13/8.14).

---

## Getting Started (Flutter default)

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
