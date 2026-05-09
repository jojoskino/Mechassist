<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class InterventionRequest extends Model
{
    protected $fillable = [
        'client_id',
        'mechanic_id',
        'vehicle_type',
        'description',
        'photo_path',
        'client_lat',
        'client_lng',
        'status',
        'outcome',
        'outcome_at',
    ];

    protected function casts(): array
    {
        return [
            'client_lat' => 'float',
            'client_lng' => 'float',
            'outcome_at' => 'datetime',
        ];
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(User::class, 'client_id');
    }

    public function mechanic(): BelongsTo
    {
        return $this->belongsTo(User::class, 'mechanic_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(ChatMessage::class)->orderBy('id');
    }

    public function mechanicRating(): HasOne
    {
        return $this->hasOne(MechanicRating::class);
    }
}
