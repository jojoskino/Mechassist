<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;

class PasswordResetController extends Controller
{
    /**
     * Envoie un lien / jeton de réinitialisation par e-mail (table password_reset_tokens).
     */
    public function sendResetLink(Request $request)
    {
        $request->validate(['email' => ['required', 'email']]);

        $status = Password::broker('users')->sendResetLink(
            $request->only('email')
        );

        if ($status === Password::RESET_LINK_SENT) {
            return response()->json(['message' => __($status)]);
        }

        return response()->json([
            'message' => __($status),
        ], 422);
    }

    /**
     * Réinitialise le mot de passe avec le jeton reçu par e-mail.
     */
    public function reset(Request $request)
    {
        $request->validate([
            'token' => ['required', 'string'],
            'email' => ['required', 'email'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
        ]);

        $status = Password::broker('users')->reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function ($user, string $password): void {
                $user->forceFill([
                    'password' => Hash::make($password),
                ])->save();
            }
        );

        if ($status === Password::PASSWORD_RESET) {
            return response()->json(['message' => __($status)]);
        }

        return response()->json([
            'message' => __($status),
        ], 422);
    }
}
