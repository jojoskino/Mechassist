<?php

namespace App\Support;

use Illuminate\Support\Facades\Request;

class PublicStorageUrl
{
    /**
     * URL absolue pour un fichier du disque `public` (photos demandes, médias chat).
     * Utilise l’hôte de la requête API pour que les téléphones n’obtiennent pas `http://localhost/...`.
     */
    public static function forPath(?string $path): ?string
    {
        if ($path === null || $path === '') {
            return null;
        }

        $relative = '/storage/'.ltrim($path, '/');

        if (! app()->runningInConsole() && Request::hasHeader('Host')) {
            return rtrim(Request::getSchemeAndHttpHost(), '/').$relative;
        }

        $base = config('app.asset_url') ?: config('app.url');

        return rtrim((string) $base, '/').$relative;
    }
}
