<?php

namespace App\Models;

use Illuminate\Auth\Passwords\CanResetPassword;
use Illuminate\Contracts\Auth\CanResetPassword as CanResetPasswordContract;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use App\Support\PublicStorageUrl;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable implements CanResetPasswordContract
{
    use CanResetPassword, HasApiTokens, HasFactory, Notifiable;

    protected $appends = ['avatar_url', 'is_online'];

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
        'last_seen_at',
        'fcm_token',
        'mechanic_specialty',
        'avatar_path',
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
            'last_seen_at' => 'datetime',
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

    public function ratingsReceived(): HasMany
    {
        return $this->hasMany(MechanicRating::class, 'mechanic_id');
    }

    /**
     * Même logique que la liste « mécaniciens proches » : dispo + activité récente.
     */
    public function isReachableMechanic(?\DateTimeInterface $since = null): bool
    {
        if ($this->role !== 'mecanicien' || ! $this->is_available) {
            return false;
        }
        $cutoff = $since !== null
            ? \Illuminate\Support\Carbon::instance(\DateTimeImmutable::createFromInterface($since))
            : now()->subMinutes(5);
        $seen = $this->last_seen_at ?? $this->last_location_at;

        return $seen !== null && $seen->gte($cutoff);
    }

    public function getAvatarUrlAttribute(): ?string
    {
        return PublicStorageUrl::forPath($this->avatar_path);
    }

    public function getIsOnlineAttribute(): bool
    {
        if ($this->role === 'mecanicien' && ! $this->is_available) {
            return false;
        }
        $cutoff = now()->subMinutes(5);
        $seen = $this->last_seen_at ?? $this->last_location_at;

        return $seen !== null && $seen->gte($cutoff);
    }
}