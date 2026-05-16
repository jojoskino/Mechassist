<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\HealthController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\PasswordResetController;
use App\Http\Controllers\InterventionRequestController;
use App\Http\Controllers\LocationController;
use App\Http\Controllers\MechanicSearchController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\ChatMessageController;
use App\Http\Controllers\PushTokenController;
use App\Http\Controllers\PresenceController;


Route::get('/db-test', function () {
    return DB::connection()->getPdo() ? 'DB OK' : 'DB FAIL';
});



Route::get('/health', HealthController::class);
Route::get('/health/ready', [HealthController::class, 'ready']);

Route::middleware(['throttle:mechassist-auth'])->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/auth/google', [AuthController::class, 'googleLogin']);
});

Route::middleware(['throttle:mechassist-password-reset'])->group(function () {
    Route::post('/forgot-password', [PasswordResetController::class, 'sendResetLink']);
    Route::post('/reset-password', [PasswordResetController::class, 'reset']);
});

Route::get('/client-config', [AuthController::class, 'clientConfig']);

Route::middleware(['auth:sanctum', 'throttle:mechassist-api'])->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me',      [AuthController::class, 'me']);

    Route::get('/profile', [ProfileController::class, 'show']);
    Route::patch('/profile', [ProfileController::class, 'update']);

    Route::post('/location', [LocationController::class, 'update']);
    Route::post('/presence/touch', [PresenceController::class, 'touch']);
    Route::get('/mechanics/nearby', [MechanicSearchController::class, 'nearby']);

    Route::get('/requests', [InterventionRequestController::class, 'index']);
    Route::post('/requests', [InterventionRequestController::class, 'store']);
    Route::get('/requests/{id}', [InterventionRequestController::class, 'show']);
    Route::post('/requests/{id}/accept', [InterventionRequestController::class, 'accept']);
    Route::post('/requests/{id}/decline', [InterventionRequestController::class, 'decline']);
    Route::post('/requests/{id}/cancel', [InterventionRequestController::class, 'cancel']);
    Route::post('/requests/{id}/mechanic-complete', [InterventionRequestController::class, 'markMechanicComplete']);
    Route::post('/requests/{id}/outcome', [InterventionRequestController::class, 'recordOutcome']);
    Route::post('/requests/{id}/rating', [InterventionRequestController::class, 'storeRating']);

    Route::get('/requests/{id}/messages', [ChatMessageController::class, 'index']);
    Route::post('/requests/{id}/messages', [ChatMessageController::class, 'store']);

    Route::post('/push/token', [PushTokenController::class, 'update']);
});