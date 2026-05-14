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
            if (! Schema::hasColumn('users', 'mechanic_specialty')) {
                $table->string('mechanic_specialty', 255)->nullable()->after('phone');
            }
        });

        Schema::table('intervention_requests', function (Blueprint $table) {
            if (! Schema::hasColumn('intervention_requests', 'mechanic_completed_at')) {
                $table->timestamp('mechanic_completed_at')->nullable()->after('status');
            }
            if (! Schema::hasColumn('intervention_requests', 'client_address')) {
                $table->string('client_address', 500)->nullable()->after('client_lng');
            }
        });

        // Anciennes demandes déjà terminées : le client avait tout clôturé seul ; on considère la période « mécanicien OK » antérieure implicitement satisfaite.
        DB::table('intervention_requests')
            ->where('status', 'completed')
            ->whereNull('mechanic_completed_at')
            ->update(['mechanic_completed_at' => DB::raw('COALESCE(outcome_at, updated_at)')]);
    }

    public function down(): void
    {
        Schema::table('intervention_requests', function (Blueprint $table) {
            if (Schema::hasColumn('intervention_requests', 'client_address')) {
                $table->dropColumn('client_address');
            }
            if (Schema::hasColumn('intervention_requests', 'mechanic_completed_at')) {
                $table->dropColumn('mechanic_completed_at');
            }
        });

        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'mechanic_specialty')) {
                $table->dropColumn('mechanic_specialty');
            }
        });
    }
};
