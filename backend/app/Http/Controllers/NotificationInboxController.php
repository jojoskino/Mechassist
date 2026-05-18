<?php

namespace App\Http\Controllers;

use App\Models\ChatMessage;
use App\Models\InterventionRequest;
use Illuminate\Http\Request;

class NotificationInboxController extends Controller
{
    /**
     * Messages non lus + meta pour le panneau in-app (web + mobile sans FCM).
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $userId = $user->id;

        $requestQuery = InterventionRequest::query();
        if ($user->isClient()) {
            $requestQuery->where('client_id', $userId);
        } else {
            $requestQuery->where('mechanic_id', $userId);
        }
        $requestIds = $requestQuery->pluck('id');

        if ($requestIds->isEmpty()) {
            return response()->json([]);
        }

        $messages = ChatMessage::query()
            ->with([
                'user:id,name,role',
                'interventionRequest:id,status,client_id,mechanic_id',
            ])
            ->whereIn('intervention_request_id', $requestIds)
            ->where('user_id', '!=', $userId)
            ->whereNull('read_at')
            ->orderByDesc('id')
            ->limit(40)
            ->get();

        $items = $messages->map(function (ChatMessage $m) use ($userId) {
            $sender = $m->user?->name ?? 'Utilisateur';
            $preview = match ($m->kind) {
                'image' => 'Photo',
                'audio' => 'Message vocal',
                default => mb_substr((string) $m->body, 0, 120),
            };

            return [
                'id' => 'msg-'.$m->id,
                'type' => 'chat_message',
                'title' => $sender,
                'body' => $preview,
                'request_id' => $m->intervention_request_id,
                'created_at' => $m->created_at?->toIso8601String(),
                'data' => [
                    'type' => 'chat_message',
                    'request_id' => (string) $m->intervention_request_id,
                    'sender_name' => $sender,
                    'message_preview' => $preview,
                ],
            ];
        })->values();

        return response()->json($items);
    }
}
