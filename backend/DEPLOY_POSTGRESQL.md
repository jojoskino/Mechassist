# PostgreSQL pour MechAssist

Ce guide part d’un **PostgreSQL installé sur ta machine** (développement local). Une section finale résume le cas d’une base **distante** (VPS, cloud) sans dépendre d’un fournisseur particulier.

## 1. Installer PostgreSQL

- **Windows** : [postgresql.org/download/windows](https://www.postgresql.org/download/windows/) (installeur officiel).
- **macOS** : `brew install postgresql@16` (ou version supportée), puis démarrer le service.
- **Linux** : paquet `postgresql` de ta distribution.

Assure-toi que l’extension PHP **pdo_pgsql** est activée (`php -m` doit lister `pdo_pgsql`).

## 2. Créer la base

Avec **psql** ou **pgAdmin** (adapte le nom d’utilisateur si besoin) :

```sql
CREATE DATABASE mechassist;
```

Si tu utilises l’utilisateur par défaut `postgres`, un mot de passe peut être défini à l’installation — renseigne-le dans `DB_PASSWORD` du `.env`.

## 3. Configurer Laravel (`backend/.env`)

À partir de `backend/.env.example`, garde par exemple :

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=mechassist
DB_USERNAME=postgres
DB_PASSWORD=ton_mot_de_passe_si_besoin
DB_SSLMODE=prefer
```

En local, `prefer` ou `disable` convient souvent ; un hébergeur distant imposera souvent `require`.

**Alternative SQLite** (sans installer Postgres) : voir les lignes commentées dans `.env.example`.

## 4. Appliquer le schéma MechAssist

Depuis le dossier `backend` :

```bash
php artisan migrate --seed
```

- Première fois : tables + comptes démo (`client@mechassist.local` / `mecanicien@mechassist.local`, mot de passe dans `.env.example`).
- **Production** : `php artisan migrate` **sans** `--seed` si tu ne veux pas les comptes démo.

## 5. Vérifier la connexion

```bash
php artisan migrate:status
```

## 6. Base PostgreSQL distante (optionnel)

Si la base tourne sur un **serveur distant** (VPS, PaaS, etc.) :

1. Renseigne `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` selon le fournisseur.
2. Si SSL est obligatoire : `DB_SSLMODE=require` ou une `DB_URL=postgresql://...?sslmode=require` conforme à la doc du fournisseur.
3. Vérifie pare-feu / IP autorisées côté hébergeur si besoin.

---

Après mise à jour du `.env`, redémarre `php artisan serve` et teste l’app Flutter avec la même API (`API_BASE_URL` si besoin).
