<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('intervention_requests', function (Blueprint $table) {
            $table->string('outcome', 32)->nullable()->after('status');
            $table->timestamp('outcome_at')->nullable()->after('outcome');
        });

        Schema::create('mechanic_ratings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('intervention_request_id')->constrained('intervention_requests')->cascadeOnDelete();
            $table->foreignId('client_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('mechanic_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedTinyInteger('stars');
            $table->text('comment')->nullable();
            $table->timestamps();

            $table->unique('intervention_request_id');
            $table->index(['mechanic_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('mechanic_ratings');

        Schema::table('intervention_requests', function (Blueprint $table) {
            $table->dropColumn(['outcome', 'outcome_at']);
        });
    }
};
