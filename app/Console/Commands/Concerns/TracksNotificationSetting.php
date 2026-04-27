<?php

namespace App\Console\Commands\Concerns;

use App\Models\NotificationSetting;

trait TracksNotificationSetting
{
    /**
     * Setting key bound to this command. Each consuming class MUST define this property.
     *
     * @var string
     */
    // protected string $settingKey = '...';  // declared by each command class

    /**
     * Should we honor the is_enabled flag in DB?
     * --force option flips this to false, allowing manual "Send Now" via Filament.
     */
    protected function shouldRespectEnabledFlag(): bool
    {
        return ! $this->option('force');
    }

    protected function setting(): ?NotificationSetting
    {
        $key = $this->settingKey ?? '';

        if ($key === '') {
            return null;
        }

        return NotificationSetting::where('key', $key)->first();
    }

    /**
     * Returns true if execution should continue, false if disabled.
     */
    protected function ensureEnabled(): bool
    {
        if (! $this->shouldRespectEnabledFlag()) {
            return true;
        }

        $setting = $this->setting();

        if ($setting && ! $setting->is_enabled) {
            $this->warn("Notification '{$this->settingKey}' is disabled in settings — skipping (use --force to override).");

            return false;
        }

        return true;
    }

    protected function recordRun(string $status, ?array $stats = null): void
    {
        $this->setting()?->recordRun($status, $stats);
    }
}
