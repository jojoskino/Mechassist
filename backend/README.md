<p align="center"><a href="https://laravel.com" target="_blank"><img src="https://raw.githubusercontent.com/laravel/art/master/logo-lockup/5%20SVG/2%20CMYK/1%20Full%20Color/laravel-logolockup-cmyk-red.svg" width="400" alt="Laravel Logo"></a></p>

<p align="center">
<a href="https://github.com/laravel/framework/actions"><img src="https://github.com/laravel/framework/workflows/tests/badge.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/dt/laravel/framework" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/v/laravel/framework" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/l/laravel/framework" alt="License"></a>
</p>

## MechAssist (API locale)

```bash
composer install
php artisan migrate --seed
# Émulateur / navigateur sur la même machine :
php artisan serve --host=127.0.0.1 --port=8000
# Téléphone sur le même Wi‑Fi que le PC (écoute sur toutes les interfaces) :
# php artisan serve --host=0.0.0.0 --port=8000
# Laravel peut afficher « http://0.0.0.0:8000 » : c’est seulement l’adresse d’écoute, pas une URL à coller dans le navigateur.
# Sur ce PC : http://127.0.0.1:8000 ou http://localhost:8000. Depuis le téléphone : http://IP_LAN_DU_PC:8000 (ipconfig).
```

Copie `.env.example` vers `.env`, configure `DB_*` pour **PostgreSQL local** (valeurs par défaut dans l’exemple), `FCM_SERVER_KEY` (notifications push), et optionnellement `GOOGLE_MAPS_WEB_API_KEY` (carte Flutter Web).

**PostgreSQL** : guide [DEPLOY_POSTGRESQL.md](DEPLOY_POSTGRESQL.md) (création de la base, variables `DB_*`, `migrate`, option distant).

L’app Flutter est dans `../frontend`. Build Android : voir `../frontend/README.md` et `../scripts/fix-flutter-android-build.ps1`.

Après `composer install`, génère la spec OpenAPI avec `php artisan l5-swagger:generate` puis ouvre **Swagger UI** à l’adresse `{APP_URL}/api/documentation` (ex. `http://127.0.0.1:8000/api/documentation`). En **production**, mets `L5_SWAGGER_UI_ENABLED=false` dans `.env` pour masquer cette UI (404), sauf besoin explicite.

Mot de passe oublié : la route web nommée `password.reset` (`GET /password/reset/{token}`) sert de cible au lien dans l’e-mail ; la réinitialisation effective se fait via `POST /api/reset-password` ou l’app Flutter.

Pour les **photos** des demandes (`storage/app/public`) : `php artisan storage:link` une fois sur le serveur.

## About Laravel

Documentation du framework : [laravel.com/docs](https://laravel.com/docs).
