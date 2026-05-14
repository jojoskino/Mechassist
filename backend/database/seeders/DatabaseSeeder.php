<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Comptes de démonstration MechAssist (mot de passe commun pour le dev local).
     *
     * Important : `migrate:fresh --seed` supprime toutes les données PostgreSQL locales.
     * En production, n’utilise que `php artisan migrate` (sans fresh) pour conserver les données.
     */
    public function run(): void
    {
        $password = Hash::make('MechAssist2026!');

        // Coordonnées de démo (Lomé, Togo) — le client et le mécanicien sont proches pour tester la recherche.
        $demoLat = 6.137;
        $demoLng = 1.2194;

        User::query()->updateOrCreate(
            ['email' => 'client@mechassist.local'],
            [
                'name' => 'Client Démo',
                'phone' => '+22890000001',
                'password' => $password,
                'role' => 'client',
                'is_available' => false,
                'latitude' => $demoLat - 0.002,
                'longitude' => $demoLng - 0.002,
                'last_location_at' => now(),
            ]
        );

        User::query()->updateOrCreate(
            ['email' => 'mecanicien@mechassist.local'],
            [
                'name' => 'Mécanicien Démo',
                'phone' => '+22890000002',
                'password' => $password,
                'role' => 'mecanicien',
                'mechanic_specialty' => 'Moteur, batterie, pneumatiques',
                'is_available' => true,
                'latitude' => $demoLat,
                'longitude' => $demoLng,
                'last_location_at' => now(),
                'last_seen_at' => now(),
            ]
        );
    }
}
