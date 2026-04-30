<?php

namespace App\Http\Controllers;

use App\Models\ChatMessage;
use App\Models\InterventionRequest;
use App\Services\FcmService;
use Illuminate\Http\Request;

class ChatMessageController extends Controller
{
    public function __construct(private readonly FcmService $fcmService)
    {
    }

    public function index(Request $request, int $id)
    {
        $row = InterventionRequest::query()->findOrFail($id);
        $this->authorizeParticipant($request->user()->id, $row);

        $messages = ChatMessage::query()
            ->with('user:id,name,role')
            ->where('intervention_request_id', $row->id)
            ->orderBy('id')
            ->get();

        return response()->json($messages);
    }

    public function store(Request $request, int $id)
    {
        $row = InterventionRequest::query()->findOrFail($id);
        $this->authorizeParticipant($request->user()->id, $row);

        if ($row->status !== 'accepted') {
            return response()->json(['message' => 'Chat indisponible pour cette demande.'], 422);
        }

        $validated = $request->validate([
            'body' => 'required|string|max:2000',
        ]);

        $message = ChatMessage::query()->create([
            'intervention_request_id' => $row->id,
            'user_id' => $request->user()->id,
            'body' => $validated['body'],
        ])->load('user:id,name,role');

        $target = $request->user()->id === $row->client_id
            ? $row->mechanic
            : $row->client;
        $senderName = $request->user()->name ?? 'Utilisateur';

        $this->fcmService->sendToToken(
            $target?->fcm_token,
            'Nouveau message',
            $senderName.': '.$validated['body'],
            ['type' => 'chat_message', 'request_id' => (string) $row->id]
        );

        return response()->json($message, 201);
    }

    private function authorizeParticipant(int $userId, InterventionRequest $row): void
    {
        if ($row->client_id !== $userId && $row->mechanic_id !== $userId) {
            abort(403, 'Non autorisé.');
        }
    }
}
