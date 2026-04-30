<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

class FcmService
{
    public function sendToToken(?string $token, string $title, string $body, array $data = []): void
    {
        if (! $token) {
            return;
        }

        $serverKey = env('FCM_SERVER_KEY');
        if (! $serverKey) {
            return;
        }

        Http::withHeaders([
            'Authorization' => 'key='.$serverKey,
            'Content-Type' => 'application/json',
        ])->post('https://fcm.googleapis.com/fcm/send', [
            'to' => $token,
            'priority' => 'high',
            'notification' => [
                'title' => $title,
                'body' => $body,
            ],
            'data' => $data,
        ]);
    }
}
