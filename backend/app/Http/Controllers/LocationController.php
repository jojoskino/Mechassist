<?php

namespace App\Http\Controllers;

use App\Services\FirestoreSyncService;
use Illuminate\Http\Request;

class LocationController extends Controller
{
    public function update(Request $request, FirestoreSyncService $firestore)
    {
        $validated = $request->validate([
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
        ]);

        $user = $request->user();
        $user->latitude = $validated['latitude'];
        $user->longitude = $validated['longitude'];
        $user->last_location_at = now();
        if ($user->role === 'mecanicien') {
            $user->last_seen_at = now();
        }
        $user->save();

        $fresh = $user->fresh();
        $firestore->syncMechanicPresence($fresh);

        return response()->json($fresh);
    }
}
