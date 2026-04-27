<?php

use App\Models\NotificationSetting;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// ─── Waffer scheduled jobs (driven by notification_settings table) ───────────
// Dev:   php artisan schedule:work
// Prod:  add to crontab → "* * * * * cd /path && php artisan schedule:run"

try {
    $settings = NotificationSetting::query()
        ->where('is_enabled', true)
        ->whereNotNull('schedule_time')
        ->whereIn('schedule_frequency', ['daily', 'monthly'])
        ->get();

    foreach ($settings as $setting) {
        $time = $setting->schedule_time?->format('H:i') ?? '09:00';
        $command = $setting->fullCommand();

        $event = Schedule::command($command)
            ->timezone('Asia/Riyadh')
            ->withoutOverlapping()
            ->onOneServer();

        match ($setting->schedule_frequency) {
            'monthly' => $event->monthlyOn($setting->schedule_day_of_month ?? 1, $time),
            default   => $event->dailyAt($time),
        };
    }
} catch (\Throwable $e) {
    // Migration may not have run yet during initial install — fail silently.
    // Once notification_settings table exists, schedule will populate automatically.
    if (! str_contains($e->getMessage(), 'notification_settings')) {
        throw $e;
    }
}
