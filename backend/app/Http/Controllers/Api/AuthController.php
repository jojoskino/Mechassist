<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $request->validate([
            'name' => 'required',
            'email' => 'required|email|unique:users',
            'password' => 'required|min:6',
            'role' => 'required|in:client,mecanicien'
        ]);

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => $request->password, // hash auto via cast
            'role' => $request->role,
            'phone' => $request->phone,
            'is_available' => false
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json(compact('user', 'token'));
    }

    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required',
            'password' => 'required'
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json(['message' => 'Identifiants incorrects'], 401);
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json(compact('user', 'token'));
    }
}