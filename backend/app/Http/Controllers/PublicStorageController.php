<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;

class PublicStorageController extends Controller
{
    /**
     * Sert les fichiers du disque public (photos demandes, chat, avatars).
     */
    public function show(string $path): Response
    {
        $path = str_replace('\\', '/', $path);
        if (str_contains($path, '..')) {
            abort(404);
        }

        $disk = Storage::disk('public');
        if (! $disk->exists($path)) {
            abort(404);
        }

        return $disk->response($path, headers: [
            'Access-Control-Allow-Origin' => '*',
            'Cache-Control' => 'public, max-age=86400',
        ]);
    }
}
