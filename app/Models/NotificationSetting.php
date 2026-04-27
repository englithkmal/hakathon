<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NotificationSetting extends Model
{
    protected $fillable = [
        'key',
        'label_ar',
        'label_en',
        'description_ar',
        'description_en',
        'command',
        'is_enabled',
        'schedule_time',
        'schedule_frequency',
        'schedule_day_of_month',
        'extra_config',
        'last_run_at',
        'last_run_stats',
        'last_run_status',
    ];

    protected $casts = [
        'is_enabled' => 'boolean',
        'schedule_time' => 'datetime:H:i',
        'schedule_day_of_month' => 'integer',
        'extra_config' => 'array',
        'last_run_at' => 'datetime',
        'last_run_stats' => 'array',
    ];

    public function getLabelAttribute(): string
    {
        return app()->getLocale() === 'ar' ? $this->label_ar : $this->label_en;
    }

    public function getDescriptionAttribute(): string
    {
        return app()->getLocale() === 'ar'
            ? ($this->description_ar ?? '')
            : ($this->description_en ?? '');
    }

    /**
     * Build the full artisan command (with any extra options from extra_config).
     */
    public function fullCommand(): string
    {
        $cmd = $this->command;
        $config = $this->extra_config ?? [];

        foreach ($config as $option => $value) {
            $cmd .= " --{$option}={$value}";
        }

        return $cmd;
    }

    /**
     * Convenience: fetch a setting by key, returns null if missing.
     */
    public static function find_by_key(string $key): ?self
    {
        return static::where('key', $key)->first();
    }

    public function recordRun(string $status, ?array $stats = null): void
    {
        $this->forceFill([
            'last_run_at' => now(),
            'last_run_status' => $status,
            'last_run_stats' => $stats,
        ])->save();
    }
}
