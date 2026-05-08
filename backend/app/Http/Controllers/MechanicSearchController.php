<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;

class MechanicSearchController extends Controller
{
    public function nearby(Request $request)
    {
        $validated = $request->validate([
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'radius_km' => 'sometimes|numeric|min:1|max:500',
        ]);

        $radius = (float) ($validated['radius_km'] ?? 50);
        $lat = (float) $validated['latitude'];
        $lng = (float) $validated['longitude'];

        $onlineBefore = now()->subMinutes(5);

        $mechanics = User::query()
            ->where('role', 'mecanicien')
            ->where('is_available', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->where(function ($q) use ($onlineBefore) {
                $q->where(function ($q2) use ($onlineBefore) {
                    $q2->whereNotNull('last_seen_at')
                        ->where('last_seen_at', '>=', $onlineBefore);
                })->orWhere(function ($q2) use ($onlineBefore) {
                    $q2->whereNull('last_seen_at')
                        ->whereNotNull('last_location_at')
                        ->where('last_location_at', '>=', $onlineBefore);
                });
            })
            ->get(['id', 'name', 'phone', 'latitude', 'longitude', 'is_available', 'last_location_at', 'last_seen_at']);

        $withDistance = $mechanics->map(function (User $u) use ($lat, $lng, $onlineBefore) {
            $km = self::haversineKm($lat, $lng, (float) $u->latitude, (float) $u->longitude);
            $u->setAttribute('distance_km', round($km, 2));
            $seen = $u->last_seen_at ?? $u->last_location_at;
            $u->setAttribute('is_online', $seen !== null && $seen->gte($onlineBefore));

            return $u;
        })->filter(fn (User $u) => $u->distance_km <= $radius)
            ->sortBy('distance_km')
            ->values();

        return response()->json($withDistance);
    }

    public static function haversineKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earth = 6371.0;
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) ** 2;

        return $earth * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
