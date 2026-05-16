<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class HealthController
{
    /**
     * Liveness probe (Render / load balancers).
     */
    public function __invoke(): JsonResponse
    {
        return response()->json(['status' => 'ok']);
    }

    /**
     * Optional readiness: vérifie la base PostgreSQL.
     */
    public function ready(): JsonResponse
    {
        try {
            DB::connection()->getPdo();

            return response()->json(['status' => 'ok', 'database' => 'connected']);
        } catch (\Throwable $e) {
            return response()->json(
                ['status' => 'error', 'database' => 'unavailable'],
                503
            );
        }
    }
}
