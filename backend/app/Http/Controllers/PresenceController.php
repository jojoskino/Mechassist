<?php

namespace App\Http\Controllers;

use App\Services\FirestoreSyncService;
use Illuminate\Http\Request;

class PresenceController extends Controller
{
    public function touch(Request $request, FirestoreSyncService $firestore)
    {
        $user = $request->user();
        if ($user->role !== 'mecanicien') {
            return response()->json(['message' => 'Réservé aux mécaniciens.'], 403);
        }

        $user->last_seen_at = now();
        $user->save();

        $fresh = $user->fresh();
        dispatch(function () use ($firestore, $fresh): void {
            $firestore->syncMechanicPresence($fresh);
        })->afterResponse();

        return response()->json([
            'ok' => true,
            'last_seen_at' => $fresh->last_seen_at?->toIso8601String(),
        ]);
    }
}
