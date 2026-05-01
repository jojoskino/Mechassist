<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmService
{
    /**
     * Envoie une notification FCM (API legacy). Toutes les clés/valeurs de `data` doivent être des chaînes.
     */
    public function sendToToken(?string $token, string $title, string $body, array $data = []): void
    {
        if (! $token) {
            return;
        }

        $serverKey = env('FCM_SERVER_KEY');
        if (! $serverKey) {
            return;
        }

        $stringData = [];
        foreach ($data as $k => $v) {
            $stringData[(string) $k] = is_scalar($v) ? (string) $v : json_encode($v);
        }

        $response = Http::timeout(15)->withHeaders([
            'Authorization' => 'key='.$serverKey,
            'Content-Type' => 'application/json',
        ])->post('https://fcm.googleapis.com/fcm/send', [
            'to' => $token,
            'priority' => 'high',
            'notification' => [
                'title' => $title,
                'body' => $body,
                'sound' => 'default',
            ],
            'data' => $stringData,
        ]);

        if (! $response->successful()) {
            Log::warning('FCM send failed', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
        }
    }
}
