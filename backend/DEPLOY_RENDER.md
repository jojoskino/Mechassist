# Déploiement Render (Docker) + Supabase

## Prérequis

1. Base **PostgreSQL** sur [Supabase](https://supabase.com) (Settings → Database → connection string).
2. Service **Web Service** sur [Render](https://render.com) avec **Docker** et racine = dossier `backend`.

## Variables d'environnement Render (obligatoires)

| Variable | Exemple | Notes |
|----------|---------|--------|
| `APP_NAME` | `MechAssist` | |
| `APP_ENV` | `production` | |
| `APP_DEBUG` | `false` | **Jamais** `true` en prod |
| `APP_KEY` | `base64:...` | `php artisan key:generate --show` en local |
| `APP_URL` | `https://mechassist-api.onrender.com` | URL publique Render (sans slash final) |
| `DB_CONNECTION` | `pgsql` | |
| `DB_HOST` | `db.xxx.supabase.co` | Ou utiliser `DATABASE_URL` seul |
| `DB_PORT` | `5432` | Pooler transaction : `6543` |
| `DB_DATABASE` | `postgres` | |
| `DB_USERNAME` | `postgres` | |
| `DB_PASSWORD` | *(secret Supabase)* | |
| `DB_SSLMODE` | `require` | Obligatoire Supabase |
| `DATABASE_URL` | `postgresql://...` | Alternative : Laravel lit aussi cette variable |
| `LOG_CHANNEL` | `stderr` | Logs visibles dans Render |
| `LOG_LEVEL` | `warning` | |
| `L5_SWAGGER_UI_ENABLED` | `false` | Masque Swagger en prod |

Optionnel : `ASSET_URL` = même URL que `APP_URL` (photos `/storage/...`).

## Render — configuration Docker

- **Root Directory** : `backend`
- **Dockerfile Path** : `Dockerfile` (défaut)
- **Port** : Render définit `PORT` (souvent `10000`) — le script d’entrée l’utilise automatiquement.
- **Health Check Path** : `/api/health` (ou `/up` si l’image n’est pas encore à jour)

## Vérifications après déploiement

```bash
curl https://VOTRE-SERVICE.onrender.com/api/health
# {"status":"ok"}

curl https://VOTRE-SERVICE.onrender.com/api/health/ready
# {"status":"ok","database":"connected"}

curl https://VOTRE-SERVICE.onrender.com/api/db-test
# {"status":"DB OK"} ou {"status":"DB FAIL","error":"..."}

curl https://VOTRE-SERVICE.onrender.com/api/client-config
# JSON (clés publiques, pas d'erreur 500)
```

## Flutter

Dans l’app : URL API = `https://VOTRE-SERVICE.onrender.com` (écran Aide ou `--dart-define=API_BASE_URL=...`).

CORS : `config/cors.php` autorise `*` sur `api/*` (phase test mobile).

## Dépannage 500

1. **Logs Render** → onglet Logs (erreurs PHP / SQL).
2. `APP_KEY` manquant → 500 sur presque toutes les requêtes.
3. **PostgreSQL** : `DB_SSLMODE=require`, IP autorisées Supabase (Render = accès internet).
4. Migrations : le conteneur exécute `php artisan migrate --force` au démarrage.
5. Ne pas lancer `config:cache` au **build** Docker — uniquement au **start** (déjà fait dans `docker-entrypoint.sh`).

## Commandes locales (avant push)

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan test
php artisan config:cache && php artisan route:cache && php artisan optimize
php artisan config:clear && php artisan route:clear
```
