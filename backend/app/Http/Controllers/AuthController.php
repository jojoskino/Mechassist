<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\FirestoreSyncService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function register(Request $request, FirestoreSyncService $firestore)
    {
        $validated = $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|email|unique:users',
            'phone'    => 'required|string|max:20',
            'password' => 'required|string|min:6|confirmed',
            'role'     => 'required|in:client,mecanicien',
            'fcm_token' => 'nullable|string|max:4096',
            'mechanic_specialty' => 'nullable|string|max:255',
        ]);

        $isMechanic = $validated['role'] === 'mecanicien';

        [$user, $token] = DB::transaction(function () use ($validated, $isMechanic) {
            $user = User::query()->create([
                'name'     => $validated['name'],
                'email'    => $validated['email'],
                'phone'    => $validated['phone'],
                'password' => Hash::make($validated['password']),
                'role'     => $validated['role'],
                'is_available' => $isMechanic,
                'last_seen_at' => $isMechanic ? now() : null,
                'fcm_token' => $validated['fcm_token'] ?? null,
                'mechanic_specialty' => $isMechanic ? ($validated['mechanic_specialty'] ?? null) : null,
            ]);

            $token = $user->createToken('auth_token')->plainTextToken;

            return [$user, $token];
        });

        $fresh = $user->fresh();
        if ($isMechanic) {
            dispatch(function () use ($firestore, $fresh): void {
                $firestore->syncMechanicPresence($fresh);
            })->afterResponse();
        }

        return response()->json(['user' => $fresh, 'token' => $token], 201);
    }

    public function login(Request $request)
    {
        $request->validate([
            'email'    => 'required|email',
            'password' => 'required',
            'fcm_token' => 'nullable|string|max:4096',
        ]);

        $user = User::where('email', $request->email)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            return response()->json([
                'message' => 'Identifiants incorrects.',
            ], 401);
        }

        $token = $user->createToken('auth_token')->plainTextToken;
        if ($request->filled('fcm_token')) {
            $user->fcm_token = $request->string('fcm_token')->toString();
            $user->save();
        }

        return response()->json(['user' => $user, 'token' => $token]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();
        return response()->json(['message' => 'Déconnecté avec succès']);
    }

    public function me(Request $request)
    {
        return response()->json($request->user());
    }

    /**
     * Identifiants publics pour le client (sans secrets).
     */
    public function clientConfig()
    {
        $data = Cache::remember('mechassist_client_config', 300, function () {
            $webClientId = (string) config('services.google.client_id', '');
            $mapsKey = (string) env('GOOGLE_MAPS_WEB_API_KEY', '');

            return [
                'google_client_id' => $webClientId !== '' ? $webClientId : null,
                'google_maps_web_api_key' => $mapsKey !== '' ? $mapsKey : null,
            ];
        });

        return response()
            ->json($data)
            ->header('Cache-Control', 'public, max-age=300');
    }

    /**
     * Connexion / inscription via id_token Google (Sanctum).
     */
    public function googleLogin(Request $request)
    {
        $validated = $request->validate([
            'id_token' => 'required|string',
            'role' => 'nullable|in:client,mecanicien',
            'fcm_token' => 'nullable|string|max:4096',
        ]);

        $expectedWeb = (string) config('services.google.client_id', '');
        $expectedAndroid = (string) config('services.google.android_client_id', '');

        if ($expectedWeb === '' && $expectedAndroid === '') {
            return response()->json([
                'message' => 'Connexion Google non configurée sur le serveur (GOOGLE_CLIENT_ID).',
            ], 503);
        }

        $http = Http::timeout(10)->get('https://oauth2.googleapis.com/tokeninfo', [
            'id_token' => $validated['id_token'],
        ]);

        if (! $http->successful()) {
            return response()->json(['message' => 'Jeton Google invalide ou expiré.'], 401);
        }

        /** @var array<string, mixed> $payload */
        $payload = $http->json();
        $aud = (string) ($payload['aud'] ?? '');
        $audOk = ($expectedWeb !== '' && $aud === $expectedWeb)
            || ($expectedAndroid !== '' && $aud === $expectedAndroid);
        if (! $audOk) {
            return response()->json(['message' => 'Audience du jeton incorrecte (vérifie GOOGLE_CLIENT_ID / serverClientId).'], 401);
        }

        $iss = (string) ($payload['iss'] ?? '');
        if ($iss !== 'https://accounts.google.com' && $iss !== 'accounts.google.com') {
            return response()->json(['message' => 'Émetteur du jeton invalide.'], 401);
        }

        $email = filter_var($payload['email'] ?? null, FILTER_VALIDATE_EMAIL);
        if (! is_string($email) || $email === '') {
            return response()->json(['message' => 'Email Google introuvable.'], 401);
        }

        $verifiedRaw = $payload['email_verified'] ?? false;
        $verified = filter_var($verifiedRaw, FILTER_VALIDATE_BOOLEAN);
        if (! $verified) {
            return response()->json(['message' => 'Email Google non vérifié.'], 401);
        }

        $name = is_string($payload['name'] ?? null) ? (string) $payload['name'] : Str::before($email, '@');

        $user = User::where('email', $email)->first();

        if (! $user) {
            $role = $validated['role'] ?? 'client';
            if (! in_array($role, ['client', 'mecanicien'], true)) {
                $role = 'client';
            }
            $isMechanic = $role === 'mecanicien';
            $user = DB::transaction(function () use ($name, $email, $role, $isMechanic, $validated) {
                return User::query()->create([
                    'name' => $name,
                    'email' => $email,
                    'phone' => null,
                    'password' => Hash::make(Str::random(48)),
                    'role' => $role,
                    'is_available' => $isMechanic,
                    'last_seen_at' => $isMechanic ? now() : null,
                    'fcm_token' => $validated['fcm_token'] ?? null,
                ]);
            });
        } else {
            if ($name !== '' && $user->name !== $name) {
                $user->name = $name;
            }
            if ($request->filled('fcm_token')) {
                $user->fcm_token = $request->string('fcm_token')->toString();
            }
            $user->save();
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        $fresh = $user->fresh();
        app(FirestoreSyncService::class)->syncMechanicPresence($fresh);

        return response()->json(['user' => $fresh, 'token' => $token]);
    }
}