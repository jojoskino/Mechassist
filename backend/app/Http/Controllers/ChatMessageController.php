<?php

namespace App\Http\Controllers;

use App\Models\ChatMessage;
use App\Models\InterventionRequest;
use App\Services\FcmService;
use App\Services\FirestoreSyncService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ChatMessageController extends Controller
{
    public function __construct(
        private readonly FcmService $fcmService,
        private readonly FirestoreSyncService $firestoreSync,
    ) {
    }

    public function index(Request $request, int $id)
    {
        $row = InterventionRequest::query()->findOrFail($id);
        $this->authorizeParticipant($request->user()->id, $row);

        $userId = $request->user()->id;

        if ($request->boolean('mark_read')) {
            ChatMessage::query()
                ->where('intervention_request_id', $row->id)
                ->where('user_id', '!=', $userId)
                ->whereNull('read_at')
                ->update(['read_at' => now()]);
        }

        $messages = ChatMessage::query()
            ->with('user:id,name,role')
            ->where('intervention_request_id', $row->id)
            ->orderByDesc('id')
            ->limit(120)
            ->get()
            ->reverse()
            ->values();

        return response()->json($messages);
    }

    public function store(Request $request, int $id)
    {
        $row = InterventionRequest::query()->findOrFail($id);
        $row->loadMissing(['client', 'mechanic']);
        $this->authorizeParticipant($request->user()->id, $row);

        if ($row->status !== 'accepted') {
            return response()->json(['message' => 'Chat indisponible pour cette demande.'], 422);
        }

        if ($request->hasFile('media')) {
            $validated = $request->validate([
                'message_type' => ['required', Rule::in(['image', 'audio'])],
                'body' => 'nullable|string|max:2000',
            ]);
            $mimeRule = $validated['message_type'] === 'image'
                ? 'mimes:jpeg,jpg,png,webp,gif'
                : 'mimes:mp3,m4a,wav,webm,ogg,aac,mpeg,mp4,x-m4a,octet-stream';
            $request->validate([
                'media' => ['required', 'file', 'max:20480', $mimeRule],
            ]);

            $type = $validated['message_type'];
            $path = $request->file('media')->store('chat/'.$row->id, 'public');
            $caption = isset($validated['body']) ? trim((string) $validated['body']) : '';

            $message = ChatMessage::query()->create([
                'intervention_request_id' => $row->id,
                'user_id' => $request->user()->id,
                'kind' => $type,
                'body' => $caption,
                'media_path' => $path,
            ])->load('user:id,name,role');
        } else {
            $validated = $request->validate([
                'body' => 'required|string|max:2000',
            ]);

            $message = ChatMessage::query()->create([
                'intervention_request_id' => $row->id,
                'user_id' => $request->user()->id,
                'kind' => 'text',
                'body' => $validated['body'],
                'media_path' => null,
            ])->load('user:id,name,role');
        }

        $target = $request->user()->id === $row->client_id
            ? $row->mechanic
            : $row->client;
        $senderName = $request->user()->name ?? 'Utilisateur';
        $preview = match ($message->kind) {
            'image' => '📷 Photo',
            'audio' => '🎤 Message vocal',
            default => mb_substr((string) $message->body, 0, 120),
        };

        $this->fcmService->sendToToken(
            $target?->fcm_token,
            $senderName,
            $preview,
            [
                'type' => 'chat_message',
                'request_id' => (string) $row->id,
                'sender_id' => (string) $request->user()->id,
                'sender_name' => $senderName,
                'message_preview' => $preview,
            ]
        );

        $this->firestoreSync->syncChatMessage($message, $request->user());

        return response()->json($message, 201);
    }

    private function authorizeParticipant(int $userId, InterventionRequest $row): void
    {
        if ($row->client_id !== $userId && $row->mechanic_id !== $userId) {
            abort(403, 'Non autorisé.');
        }
    }
}
