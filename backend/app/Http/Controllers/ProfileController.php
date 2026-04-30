<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function show(Request $request)
    {
        return response()->json($request->user());
    }

    public function update(Request $request)
    {
        $user = $request->user();
        $rules = [
            'name' => 'sometimes|string|max:255',
            'phone' => 'sometimes|string|max:20',
        ];
        if ($user->role === 'mecanicien') {
            $rules['is_available'] = 'sometimes|boolean';
        }

        $validated = $request->validate($rules);
        $user->fill($validated);
        $user->save();

        return response()->json($user->fresh());
    }
}
