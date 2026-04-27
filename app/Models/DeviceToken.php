<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeviceToken extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'token',
        'platform',
        'device_name',
        'device_model',
        'app_version',
        'locale',
        'is_active',
        'last_used_at',
        'failed_at',
        'failure_count',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'last_used_at' => 'datetime',
        'failed_at' => 'datetime',
        'failure_count' => 'integer',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function markUsed(): void
    {
        $this->forceFill([
            'last_used_at' => now(),
            'failed_at' => null,
            'failure_count' => 0,
            'is_active' => true,
        ])->save();
    }

    public function markFailed(?string $reason = null): void
    {
        $this->increment('failure_count');
        $this->forceFill([
            'failed_at' => now(),
            'is_active' => $this->failure_count < 5,
        ])->save();
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeForPlatform($query, string $platform)
    {
        return $query->where('platform', $platform);
    }
}
