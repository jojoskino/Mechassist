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
        if (! self::isConfiguredKey($serverKey)) {
            Log::warning('FCM: définis FCM_SERVER_KEY dans backend/.env (clé serveur Firebase Cloud Messaging).');

            return;
        }

        $stringData = [];
        foreach ($data as $k => $v) {
            $stringData[(string) $k] = is_scalar($v) ? (string) $v : json_encode($v);
        }
        if (! isset($stringData['title'])) {
            $stringData['title'] = $title;
        }
        if (! isset($stringData['body'])) {
            $stringData['body'] = $body;
        }

        $payload = [
            'to' => $token,
            'priority' => 'high',
            'content_available' => true,
            'notification' => [
                'title' => $title,
                'body' => $body,
                'sound' => 'default',
                'android_channel_id' => 'mechassist_high',
            ],
            'data' => $stringData,
            'android' => [
                'priority' => 'high',
                'ttl' => '0s',
            ],
        ];

        $response = Http::timeout(10)->withHeaders([
            'Authorization' => 'key='.$serverKey,
            'Content-Type' => 'application/json',
        ])->post('https://fcm.googleapis.com/fcm/send', $payload);

        if (! $response->successful()) {
            Log::warning('FCM send failed', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
        }
    }

    private static function isConfiguredKey(?string $key): bool
    {
        $key = trim((string) $key);
        if ($key === '' || strlen($key) < 20) {
            return false;
        }
        $placeholders = ['TA_CLE_FCM_SERVER', 'your-server-key', 'changeme', 'xxx'];
        foreach ($placeholders as $bad) {
            if (stripos($key, $bad) !== false) {
                return false;
            }
        }

        return true;
    }
}
