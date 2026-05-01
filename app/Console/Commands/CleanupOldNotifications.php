<?php

namespace App\Console\Commands;

use App\Models\Alert;
use Illuminate\Console\Command;

class CleanupOldNotifications extends Command
{
    protected $signature = 'waffer:notifications-cleanup {--days=90 : Delete notifications older than this number of days}';

    protected $description = 'Delete old in-app notifications to keep the table small.';

    public function handle(): int
    {
        $days = max(1, (int) $this->option('days'));
        $cutoff = now()->subDays($days);

        $deleted = Alert::query()
            ->where('created_at', '<', $cutoff)
            ->delete();

        $this->info("Deleted {$deleted} notifications older than {$days} days.");

        return self::SUCCESS;
    }
}

