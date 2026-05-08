<?php

namespace App\Services;

use App\Models\ChatMessage;
use App\Models\InterventionRequest;
use App\Models\User;
use Google\Auth\Credentials\ServiceAccountCredentials;
use Google\Auth\HttpHandler\HttpHandlerFactory;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Duplique les données vers Cloud Firestore (API REST, sans ext-grpc).
 * PostgreSQL reste la source de vérité ; si Firestore n’est pas configuré ou échoue, l’API reste fonctionnelle.
 */
class FirestoreSyncService
{
    public function enabled(): bool
    {
        $path = env('GOOGLE_APPLICATION_CREDENTIALS');
        $project = env('FIREBASE_PROJECT_ID');

        return is_string($project) && $project !== ''
            && is_string($path) && $path !== ''
            && is_readable($path);
    }

    private function documentsRoot(): string
    {
        $project = rawurlencode((string) env('FIREBASE_PROJECT_ID'));

        return "https://firestore.googleapis.com/v1/projects/{$project}/databases/(default)/documents";
    }

    private function accessToken(): ?string
    {
        if (! $this->enabled()) {
            return null;
        }
        try {
            $json = json_decode(
                (string) file_get_contents((string) env('GOOGLE_APPLICATION_CREDENTIALS')),
                true,
                512,
                JSON_THROW_ON_ERROR
            );
            $creds = new ServiceAccountCredentials(
                'https://www.googleapis.com/auth/datastore',
                $json
            );
            $token = $creds->fetchAuthToken(HttpHandlerFactory::build());

            return $token['access_token'] ?? null;
        } catch (\Throwable $e) {
            Log::warning('FirestoreSync: jeton OAuth impossible.', ['message' => $e->getMessage()]);

            return null;
        }
    }

    private function timestampValue(\DateTimeInterface $dt): array
    {
        $utc = \DateTimeImmutable::createFromInterface($dt)->setTimezone(new \DateTimeZone('UTC'));

        return ['timestampValue' => $utc->format(\DateTimeInterface::ATOM)];
    }

    /**
     * Crée un document dans une collection racine (ex: intervention_requests).
     *
     * @param  array<string, array<string, mixed>>  $fields
     */
    private function createRootCollectionDocument(string $collectionId, string $documentId, array $fields): bool
    {
        $token = $this->accessToken();
        if (! $token) {
            return false;
        }
        $url = $this->documentsRoot()
            .'?collectionId='.rawurlencode($collectionId)
            .'&documentId='.rawurlencode($documentId);

        $response = Http::withToken($token)
            ->withHeaders(['Content-Type' => 'application/json'])
            ->post($url, ['fields' => $fields]);

        if ($response->successful()) {
            return true;
        }
        if ($response->status() === 409 || str_contains($response->body(), 'ALREADY_EXISTS')) {
            return false;
        }
        Log::warning('FirestoreSync: création document racine', [
            'collection' => $collectionId,
            'id' => $documentId,
            'status' => $response->status(),
            'body' => $response->body(),
        ]);

        return false;
    }

    /**
     * @param  array<string, array<string, mixed>>  $fields
     */
    private function patchDocument(string $relativePath, array $fields, array $updateMaskFieldPaths): void
    {
        $token = $this->accessToken();
        if (! $token) {
            return;
        }
        $url = $this->documentsRoot().'/'.$relativePath;
        $parts = [];
        foreach ($updateMaskFieldPaths as $p) {
            $parts[] = 'updateMask.fieldPaths='.rawurlencode($p);
        }
        $url .= '?'.implode('&', $parts);

        $response = Http::withToken($token)
            ->withHeaders(['Content-Type' => 'application/json'])
            ->patch($url, ['fields' => $fields]);

        if (! $response->successful()) {
            Log::warning('FirestoreSync: PATCH', [
                'path' => $relativePath,
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
        }
    }

    /**
     * Crée un document dans une sous-collection.
     *
     * @param  array<string, array<string, mixed>>  $fields
     */
    private function createChildDocument(string $parentDocumentPath, string $collectionId, string $documentId, array $fields): void
    {
        $token = $this->accessToken();
        if (! $token) {
            return;
        }
        $url = $this->documentsRoot().'/'.$parentDocumentPath
            .'?collectionId='.rawurlencode($collectionId)
            .'&documentId='.rawurlencode($documentId);

        $response = Http::withToken($token)
            ->withHeaders(['Content-Type' => 'application/json'])
            ->post($url, ['fields' => $fields]);

        if (! $response->successful()) {
            Log::warning('FirestoreSync: création sous-document', [
                'parent' => $parentDocumentPath,
                'collection' => $collectionId,
                'id' => $documentId,
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
        }
    }

    public function syncInterventionRequest(InterventionRequest $row): void
    {
        if (! $this->enabled()) {
            return;
        }
        try {
            $id = (string) $row->id;
            $fields = [
                'laravel_id' => ['integerValue' => (string) $row->id],
                'client_id' => ['integerValue' => (string) $row->client_id],
                'mechanic_id' => ['integerValue' => (string) $row->mechanic_id],
                'vehicle_type' => ['stringValue' => (string) $row->vehicle_type],
                'description' => ['stringValue' => (string) $row->description],
                'status' => ['stringValue' => (string) $row->status],
                'client_lat' => ['doubleValue' => (float) $row->client_lat],
                'client_lng' => ['doubleValue' => (float) $row->client_lng],
                'updated_at' => $this->timestampValue($row->updated_at ?? new \DateTimeImmutable),
            ];
            if ($row->photo_path) {
                $fields['photo_path'] = ['stringValue' => (string) $row->photo_path];
            }
            $created = $this->createRootCollectionDocument('intervention_requests', $id, $fields);
            if (! $created) {
                $this->patchDocument(
                    'intervention_requests/'.$id,
                    $fields,
                    array_keys($fields)
                );
            }
        } catch (\Throwable $e) {
            Log::warning('FirestoreSync: intervention', ['message' => $e->getMessage()]);
        }
    }

    public function syncChatRoomMeta(int $requestId): void
    {
        if (! $this->enabled()) {
            return;
        }
        try {
            $docId = 'request_'.$requestId;
            $fields = [
                'requestId' => ['integerValue' => (string) $requestId],
                'updatedAt' => $this->timestampValue(new \DateTimeImmutable),
            ];
            $created = $this->createRootCollectionDocument('chats', $docId, $fields);
            if (! $created) {
                $this->patchDocument('chats/'.$docId, $fields, ['requestId', 'updatedAt']);
            }
        } catch (\Throwable $e) {
            Log::warning('FirestoreSync: chat meta', ['message' => $e->getMessage()]);
        }
    }

    public function syncChatMessage(ChatMessage $message, User $sender): void
    {
        if (! $this->enabled()) {
            return;
        }
        try {
            $requestId = (int) $message->intervention_request_id;
            $this->syncChatRoomMeta($requestId);

            $docId = 'laravel_msg_'.$message->id;
            $parentPath = 'chats/request_'.$requestId;
            $fields = [
                'text' => ['stringValue' => (string) $message->body],
                'userId' => ['integerValue' => (string) $sender->id],
                'userName' => ['stringValue' => (string) $sender->name],
                'role' => ['stringValue' => (string) $sender->role],
                'laravel_message_id' => ['integerValue' => (string) $message->id],
                'createdAt' => $this->timestampValue($message->created_at ?? new \DateTimeImmutable),
            ];
            $this->createChildDocument($parentPath, 'messages', $docId, $fields);
        } catch (\Throwable $e) {
            Log::warning('FirestoreSync: message', ['message' => $e->getMessage()]);
        }
    }

    /**
     * Publie la présence d’un mécanicien pour que les clients puissent s’abonner en temps quasi réel.
     */
    public function syncMechanicPresence(User $user): void
    {
        if (! $this->enabled() || $user->role !== 'mecanicien') {
            return;
        }
        try {
            $id = (string) $user->id;
            $fields = [
                'laravel_id' => ['integerValue' => $id],
                'name' => ['stringValue' => (string) $user->name],
                'phone' => ['stringValue' => (string) ($user->phone ?? '')],
                'is_available' => ['booleanValue' => (bool) $user->is_available],
                'updated_at' => $this->timestampValue($user->updated_at ?? new \DateTimeImmutable),
            ];
            if ($user->last_seen_at !== null) {
                $fields['last_seen_at'] = $this->timestampValue($user->last_seen_at);
            } else {
                $fields['last_seen_at'] = ['nullValue' => null];
            }
            if ($user->latitude !== null && $user->longitude !== null) {
                $fields['latitude'] = ['doubleValue' => (float) $user->latitude];
                $fields['longitude'] = ['doubleValue' => (float) $user->longitude];
            } else {
                $fields['latitude'] = ['nullValue' => null];
                $fields['longitude'] = ['nullValue' => null];
            }
            $created = $this->createRootCollectionDocument('mechanic_presence', $id, $fields);
            if (! $created) {
                $this->patchDocument(
                    'mechanic_presence/'.$id,
                    $fields,
                    array_keys($fields)
                );
            }
        } catch (\Throwable $e) {
            Log::warning('FirestoreSync: mechanic_presence', ['message' => $e->getMessage()]);
        }
    }
}
