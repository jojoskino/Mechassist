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
     */
    public function run(): void
    {
        $password = Hash::make('MechAssist2026!');

        User::query()->updateOrCreate(
            ['email' => 'client@mechassist.local'],
            [
                'name' => 'Client Démo',
                'phone' => '+22890000001',
                'password' => $password,
                'role' => 'client',
                'is_available' => false,
            ]
        );

        User::query()->updateOrCreate(
            ['email' => 'mecanicien@mechassist.local'],
            [
                'name' => 'Mécanicien Démo',
                'phone' => '+22890000002',
                'password' => $password,
                'role' => 'mecanicien',
                'is_available' => true,
            ]
        );
    }
}
