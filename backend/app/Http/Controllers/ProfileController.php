<?php

namespace App\Http\Controllers;

use App\Services\FirestoreSyncService;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function show(Request $request)
    {
        return response()->json($request->user());
    }

    public function update(Request $request, FirestoreSyncService $firestore)
    {
        $user = $request->user();
        $rules = [
            'name' => 'sometimes|string|max:255',
            'phone' => 'sometimes|nullable|string|max:20',
        ];
        if ($user->role === 'mecanicien') {
            $rules['is_available'] = 'sometimes|boolean';
            $rules['mechanic_specialty'] = 'sometimes|nullable|string|max:255';
        }

        if ($request->hasFile('avatar')) {
            $request->validate([
                'avatar' => ['required', 'image', 'max:5120', 'mimes:jpeg,jpg,png,webp'],
            ]);
            $path = $request->file('avatar')->store('avatars/'.$user->id, 'public');
            $user->avatar_path = $path;
        }

        $validated = $request->validate($rules);
        $user->fill($validated);
        if ($user->role === 'mecanicien' && array_key_exists('is_available', $validated)) {
            $user->last_seen_at = now();
        }
        $user->save();

        $fresh = $user->fresh();
        $firestore->syncMechanicPresence($fresh);

        return response()->json($fresh);
    }
}
