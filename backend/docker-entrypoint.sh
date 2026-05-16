#!/bin/sh
cd /var/www/html

echo "[mechassist] Booting MechAssist API (PORT=${PORT:-10000})..."

chmod -R 775 storage bootstrap/cache 2>/dev/null || true

if [ -z "${APP_KEY}" ]; then
  echo "[mechassist] ERROR: APP_KEY is not set. Render > Environment > Add:"
  echo "  php artisan key:generate --show"
  exit 1
fi

# Supabase direct host (db.*.supabase.co) résout souvent en IPv6 → échec sur Render
case "${DB_HOST:-}" in
  db.*.supabase.co)
    echo "[mechassist] WARNING: DB_HOST=${DB_HOST} = connexion directe (IPv6)."
    echo "[mechassist] Sur Render, utilisez DATABASE_URL avec *.pooler.supabase.com (Supabase > Connect > Session pooler)."
    ;;
esac

php artisan storage:link --force 2>/dev/null || true

echo "[mechassist] Caching config, routes, views..."
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan optimize

echo "[mechassist] Running migrations..."
if php artisan migrate --force --no-interaction; then
  echo "[mechassist] Migrations OK."
else
  echo "[mechassist] WARNING: migrations failed — l'API démarre quand même."
  echo "[mechassist] Corrigez DATABASE_URL (pooler Supabase) puis redéployez. Test: GET /api/db-test"
fi

PORT="${PORT:-10000}"
echo "[mechassist] Listening on 0.0.0.0:${PORT}"
exec php artisan serve --host=0.0.0.0 --port="${PORT}"
