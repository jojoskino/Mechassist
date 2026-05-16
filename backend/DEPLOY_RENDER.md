# Déploiement Render (Docker) + Supabase

## Erreur fréquente (IPv6)

```
connection to db.xxxxx.supabase.co ... Network is unreachable
```

**Cause :** host direct `db.*.supabase.co` → IPv6, inaccessible depuis Render.

**Fix :** utiliser le **Session pooler** Supabase (`*.pooler.supabase.com`), pas la connexion directe.

1. Supabase → projet → **Connect** (bouton en haut)
2. **Session pooler** (ou Connection pooling → Session)
3. Copier l’**URI** entière (host `*.pooler.supabase.com`, user **`postgres.VOTRE_REF`** — ex. `postgres.ejyqsfqrhdydrrhyajww`, **pas** `postgres` seul)
4. Render → **Environment** :
   - Coller `DATABASE_URL=...` (URI complète telle quelle)
   - `DB_SSLMODE=require`
   - **Supprimer** `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD` si vous utilisez `DATABASE_URL` (évite les conflits)
5. **Manual Deploy** → latest commit

Voir aussi `RENDER_ENV.example`.

## Variables Render (obligatoires)

| Variable | Valeur |
|----------|--------|
| `APP_KEY` | `php artisan key:generate --show` |
| `APP_ENV` | `production` |
| `APP_DEBUG` | `false` |
| `APP_URL` | `https://mechassist-api.onrender.com` |
| `DB_CONNECTION` | `pgsql` |
| `DB_SSLMODE` | `require` |
| `DATABASE_URL` | URI **pooler** Supabase (voir ci-dessus) |

## Configuration service

- **Root Directory** : `backend`
- **Docker**
- **Health Check Path** : `/api/health`

## Tests après déploiement

```bash
curl https://mechassist-api.onrender.com/api/health
curl https://mechassist-api.onrender.com/api/db-test
curl https://mechassist-api.onrender.com/api/health/ready
```

## Local vs Render

| | Local | Render |
|---|--------|--------|
| DB | `DB_HOST=127.0.0.1` ou Supabase direct | `DATABASE_URL` **pooler** uniquement |
| SSL | `prefer` | `require` |

```bash
cd backend
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan test
```
