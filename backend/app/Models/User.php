<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'phone',
        'password',
        'role',
        'is_available',
        'latitude',
        'longitude',
        'last_location_at',
        'fcm_token',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'fcm_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'is_available' => 'boolean',
            'latitude' => 'float',
            'longitude' => 'float',
            'last_location_at' => 'datetime',
        ];
    }

    public function clientRequests(): HasMany
    {
        return $this->hasMany(InterventionRequest::class, 'client_id');
    }

    public function mechanicRequests(): HasMany
    {
        return $this->hasMany(InterventionRequest::class, 'mechanic_id');
    }
}