<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

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
    ];

    protected function casts(): array
    {
        return [
            'client_lat' => 'float',
            'client_lng' => 'float',
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
}
