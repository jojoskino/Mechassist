<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->index(['role', 'is_available'], 'users_role_available_idx');
        });

        Schema::table('intervention_requests', function (Blueprint $table) {
            $table->index(['client_id', 'mechanic_id', 'status'], 'ir_client_mech_status_idx');
        });

        Schema::table('chat_messages', function (Blueprint $table) {
            $table->index(
                ['intervention_request_id', 'user_id', 'read_at'],
                'chat_messages_mark_read_idx'
            );
        });

        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            DB::statement(
                'CREATE INDEX IF NOT EXISTS users_mechanics_geo_idx ON users (latitude, longitude) '
                ."WHERE role = 'mecanicien' AND is_available = true AND latitude IS NOT NULL AND longitude IS NOT NULL"
            );
        }
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            DB::statement('DROP INDEX IF EXISTS users_mechanics_geo_idx');
        }

        Schema::table('chat_messages', function (Blueprint $table) {
            $table->dropIndex('chat_messages_mark_read_idx');
        });

        Schema::table('intervention_requests', function (Blueprint $table) {
            $table->dropIndex('ir_client_mech_status_idx');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex('users_role_available_idx');
        });
    }
};
