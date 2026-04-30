<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class PushTokenController extends Controller
{
    public function update(Request $request)
    {
        $validated = $request->validate([
            'fcm_token' => 'nullable|string|max:512',
        ]);

        $user = $request->user();
        $user->fcm_token = $validated['fcm_token'] ?? null;
        $user->save();

        return response()->json(['message' => 'Token push mis a jour.']);
    }
}
