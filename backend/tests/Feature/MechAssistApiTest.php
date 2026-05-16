<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MechAssistApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_health_endpoint_returns_ok(): void
    {
        $this->getJson('/api/health')
            ->assertOk()
            ->assertExactJson(['status' => 'ok']);
    }

    public function test_login_returns_token_for_valid_credentials(): void
    {
        User::factory()->create([
            'email' => 'client@test.local',
            'password' => Hash::make('secret12'),
            'role' => 'client',
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'client@test.local',
            'password' => 'secret12',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['user', 'token']);
    }

    public function test_login_fails_for_invalid_credentials(): void
    {
        User::factory()->create([
            'email' => 'a@test.local',
            'password' => Hash::make('goodpass'),
            'role' => 'client',
        ]);

        $this->postJson('/api/login', [
            'email' => 'a@test.local',
            'password' => 'wrong',
        ])->assertStatus(401);
    }

    public function test_client_can_create_intervention_request(): void
    {
        $mechanic = User::factory()->create([
            'role' => 'mecanicien',
            'is_available' => true,
            'last_seen_at' => now(),
            'latitude' => 48.8566,
            'longitude' => 2.3522,
        ]);
        $client = User::factory()->create([
            'role' => 'client',
            'password' => Hash::make('secret12'),
        ]);

        $token = $client->createToken('t')->plainTextToken;

        $response = $this->postJson('/api/requests', [
            'mechanic_id' => $mechanic->id,
            'vehicle_type' => 'voiture',
            'description' => 'Batterie plate',
            'client_lat' => 48.85,
            'client_lng' => 2.35,
        ], [
            'Authorization' => 'Bearer '.$token,
        ]);

        $response->assertCreated()
            ->assertJsonFragment(['status' => 'pending']);
    }

    public function test_client_cannot_close_until_mechanic_marks_complete(): void
    {
        $mechanic = User::factory()->create([
            'role' => 'mecanicien',
            'is_available' => true,
            'last_seen_at' => now(),
            'latitude' => 48.8566,
            'longitude' => 2.3522,
        ]);
        $client = User::factory()->create([
            'role' => 'client',
            'password' => Hash::make('secret12'),
        ]);

        $clientToken = $client->createToken('c')->plainTextToken;

        $create = $this->withToken($clientToken)->postJson('/api/requests', [
            'mechanic_id' => $mechanic->id,
            'vehicle_type' => 'voiture',
            'description' => 'Batterie plate',
            'client_lat' => 48.85,
            'client_lng' => 2.35,
            'client_address' => 'Rue de Rivoli, Paris',
        ]);
        $create->assertCreated();
        $requestId = (int) $create->json('id');
        $this->assertGreaterThan(0, $requestId, json_encode($create->json(), JSON_THROW_ON_ERROR));

        Sanctum::actingAs($mechanic);
        $this->postJson("/api/requests/{$requestId}/accept")->assertOk();

        Sanctum::actingAs($client);
        $this->postJson("/api/requests/{$requestId}/outcome", [
            'outcome' => 'fixed',
        ])->assertStatus(422);

        Sanctum::actingAs($mechanic);
        $complete = $this->postJson("/api/requests/{$requestId}/mechanic-complete");
        $complete->assertOk();
        $this->assertNotNull($complete->json('mechanic_completed_at'));

        Sanctum::actingAs($client);
        $this->postJson("/api/requests/{$requestId}/outcome", [
            'outcome' => 'fixed',
        ])->assertOk()
            ->assertJsonPath('status', 'completed');
    }

    public function test_forgot_password_returns_json_for_known_user(): void
    {
        User::factory()->create(['email' => 'reset@test.local', 'role' => 'client']);

        $response = $this->postJson('/api/forgot-password', [
            'email' => 'reset@test.local',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['message']);
    }

    public function test_client_config_returns_json(): void
    {
        $this->getJson('/api/client-config')->assertOk()
            ->assertJsonStructure(['google_client_id', 'google_maps_web_api_key']);
    }

    public function test_client_can_cancel_pending_request(): void
    {
        $mechanic = User::factory()->create([
            'role' => 'mecanicien',
            'is_available' => true,
            'last_seen_at' => now(),
            'latitude' => 48.8566,
            'longitude' => 2.3522,
        ]);
        $client = User::factory()->create([
            'role' => 'client',
            'password' => Hash::make('secret12'),
        ]);

        $token = $client->createToken('c')->plainTextToken;

        $create = $this->withToken($token)->postJson('/api/requests', [
            'mechanic_id' => $mechanic->id,
            'vehicle_type' => 'voiture',
            'description' => 'Test annulation',
            'client_lat' => 48.85,
            'client_lng' => 2.35,
        ]);
        $create->assertCreated();
        $requestId = (int) $create->json('id');

        $this->withToken($token)->postJson("/api/requests/{$requestId}/cancel")
            ->assertOk()
            ->assertJsonPath('status', 'cancelled');
    }

    public function test_mechanic_can_decline_pending_request(): void
    {
        $mechanic = User::factory()->create([
            'role' => 'mecanicien',
            'is_available' => true,
            'last_seen_at' => now(),
            'latitude' => 48.8566,
            'longitude' => 2.3522,
        ]);
        $client = User::factory()->create([
            'role' => 'client',
            'password' => Hash::make('secret12'),
        ]);

        $clientToken = $client->createToken('c')->plainTextToken;
        $create = $this->withToken($clientToken)->postJson('/api/requests', [
            'mechanic_id' => $mechanic->id,
            'vehicle_type' => 'voiture',
            'description' => 'Test refus',
            'client_lat' => 48.85,
            'client_lng' => 2.35,
        ]);
        $create->assertCreated();
        $requestId = (int) $create->json('id');

        Sanctum::actingAs($mechanic);
        $this->postJson("/api/requests/{$requestId}/decline")
            ->assertOk()
            ->assertJsonPath('status', 'declined');
    }
}
