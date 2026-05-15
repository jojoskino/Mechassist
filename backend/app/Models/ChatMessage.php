<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Support\PublicStorageUrl;

class ChatMessage extends Model
{
    protected $fillable = [
        'intervention_request_id',
        'user_id',
        'kind',
        'body',
        'media_path',
        'read_at',
    ];

    protected $appends = ['media_url'];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
            'read_at' => 'datetime',
        ];
    }

    public function getMediaUrlAttribute(): ?string
    {
        if ($this->media_path === null || $this->media_path === '') {
            return null;
        }

        return PublicStorageUrl::forPath($this->media_path);
    }

    public function interventionRequest(): BelongsTo
    {
        return $this->belongsTo(InterventionRequest::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
