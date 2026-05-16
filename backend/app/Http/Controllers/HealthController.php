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
     * Readiness: vérifie la base PostgreSQL.
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

    /**
     * Diagnostic PostgreSQL (Supabase / Render).
     */
    public function dbTest(): JsonResponse
    {
        try {
            DB::connection()->getPdo();

            return response()->json(['status' => 'DB OK']);
        } catch (\Throwable $e) {
            $msg = $e->getMessage();
            $hint = null;
            if (str_contains($msg, 'Network is unreachable') || str_contains($msg, 'supabase.co')) {
                $hint = 'Sur Render: utilisez DATABASE_URL avec host *.pooler.supabase.com (Session pooler), pas db.*.supabase.co.';
            }

            return response()->json(array_filter([
                'status' => 'DB FAIL',
                'error' => $msg,
                'hint' => $hint,
            ]), 503);
        }
    }
}
