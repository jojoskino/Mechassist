<?php

namespace App\Support;

use Illuminate\Support\Facades\Storage;

class PublicStorageUrl
{
    /**
     * URL absolue pour un fichier du disque `public` (photos demandes, médias chat).
     */
    public static function forPath(?string $path): ?string
    {
        if ($path === null || $path === '') {
            return null;
        }

        $base = rtrim((string) config('app.url'), '/');
        $clean = ltrim($path, '/');

        return $base.'/media/'.$clean;
    }

    /**
     * Vérifie que le fichier existe sur le disque public.
     */
    public static function exists(?string $path): bool
    {
        if ($path === null || $path === '') {
            return false;
        }

        return Storage::disk('public')->exists($path);
    }
}
