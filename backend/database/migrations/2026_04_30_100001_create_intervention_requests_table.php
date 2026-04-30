<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('intervention_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('client_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('mechanic_id')->constrained('users')->cascadeOnDelete();
            $table->string('vehicle_type', 32);
            $table->text('description');
            $table->string('photo_path')->nullable();
            $table->decimal('client_lat', 10, 7);
            $table->decimal('client_lng', 10, 7);
            $table->string('status', 24)->default('pending');
            $table->timestamps();

            $table->index(['mechanic_id', 'status']);
            $table->index(['client_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('intervention_requests');
    }
};
