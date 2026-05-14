<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'phone' => '+3306'.fake()->numerify('########'), // max 20 car. (validation register)
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'role' => 'client',
            'is_available' => false,
            'remember_token' => Str::random(10),
        ];
    }

    /**
     * Indicate that the model's email address should be unverified.
     */
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }

    public function mechanic(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'mecanicien',
            'is_available' => true,
            'last_seen_at' => now(),
        ]);
    }
}
