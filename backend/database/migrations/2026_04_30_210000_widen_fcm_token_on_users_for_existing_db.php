<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Les installations déjà migrées avec varchar(255) : élargir pour les jetons FCM.
     */
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'fcm_token')) {
            return;
        }
        $driver = Schema::getConnection()->getDriverName();
        if ($driver === 'pgsql') {
            DB::statement('ALTER TABLE users ALTER COLUMN fcm_token TYPE TEXT');
        } elseif (in_array($driver, ['mysql', 'mariadb'], true)) {
            DB::statement('ALTER TABLE users MODIFY fcm_token TEXT NULL');
        }
    }

    public function down(): void
    {
        // Non destructif : ne pas rétrécir pour éviter la troncature.
    }
};
