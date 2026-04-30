<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class LocationController extends Controller
{
    public function update(Request $request)
    {
        $validated = $request->validate([
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
        ]);

        $user = $request->user();
        $user->latitude = $validated['latitude'];
        $user->longitude = $validated['longitude'];
        $user->last_location_at = now();
        $user->save();

        return response()->json($user->fresh());
    }
}
