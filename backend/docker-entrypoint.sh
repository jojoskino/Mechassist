#!/bin/sh
set -e

cd /var/www/html

echo "[mechassist] Booting MechAssist API (PORT=${PORT:-10000})..."

# Writable dirs on ephemeral disk (Render)
chmod -R 775 storage bootstrap/cache 2>/dev/null || true

if [ -z "${APP_KEY}" ]; then
  echo "[mechassist] ERROR: APP_KEY is not set. Add it in Render Environment:"
  echo "  php artisan key:generate --show"
  exit 1
fi

if [ "${APP_ENV}" = "production" ] && [ "${APP_DEBUG}" = "true" ]; then
  echo "[mechassist] WARNING: APP_DEBUG=true in production — set APP_DEBUG=false"
fi

php artisan storage:link --force 2>/dev/null || true

echo "[mechassist] Running migrations..."
php artisan migrate --force --no-interaction

echo "[mechassist] Caching config, routes, views..."
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan optimize

PORT="${PORT:-10000}"
echo "[mechassist] Listening on 0.0.0.0:${PORT}"
exec php artisan serve --host=0.0.0.0 --port="${PORT}"
