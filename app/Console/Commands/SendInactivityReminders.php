<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\TracksNotificationSetting;
use App\Models\Alert;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

class SendInactivityReminders extends Command
{
    use TracksNotificationSetting;

    protected $signature = 'waffer:inactivity-reminder 
                            {--days=5 : Min days of inactivity to trigger} 
                            {--dry-run} 
                            {--force : Run even when disabled in settings}';

    protected $description = 'Nudge users who have not logged a transaction in the last N days.';

    protected string $settingKey = 'inactivity_reminder';

    public function handle(): int
    {
        if (! $this->ensureEnabled()) {
            return self::SUCCESS;
        }

        $days = (int) $this->option('days');
        $cutoff = now()->subDays($days)->startOfDay();

        // User is "inactive" if their last transaction is older than cutoff (or has none).
        $users = User::query()
            ->where('is_active', true)
            ->where('is_admin', false)
            ->where(function ($q) use ($cutoff) {
                $q->whereDoesntHave('transactions')
                  ->orWhereHas('transactions', function ($qq) use ($cutoff) {
                      $qq->select('user_id')
                         ->groupBy('user_id')
                         ->havingRaw('MAX(transaction_date) < ?', [$cutoff]);
                  });
            })
            ->get(['id', 'name', 'language']);

        if ($users->isEmpty()) {
            $this->info("No inactive users with {$days}+ days of inactivity.");

            return self::SUCCESS;
        }

        $this->info("Found {$users->count()} users inactive for {$days}+ days.");

        $sent = 0;
        $skipped = 0;

        foreach ($users as $user) {
            // Avoid spamming: only one inactivity reminder per week.
            $already = Alert::query()
                ->where('user_id', $user->id)
                ->where('type', 'system')
                ->whereJsonContains('payload->kind', 'inactivity')
                ->where('created_at', '>=', now()->subDays(7))
                ->exists();

            if ($already) {
                $skipped++;
                continue;
            }

            $lastTxn = Transaction::query()
                ->where('user_id', $user->id)
                ->latest('transaction_date')
                ->value('transaction_date');

            $idleDays = $lastTxn
                ? max($days, (int) $lastTxn->diffInDays(now(), true))
                : $days;

            $titleAr = '👋 افتقدناك في وفر';
            $titleEn = "👋 We've missed you in Waffer";
            $messageAr = "مرّ {$idleDays} يوماً بلا تسجيل أي معاملة. خصّص دقيقتين لتحديث ميزانيتك وحافظ على هدفك.";
            $messageEn = "{$idleDays} days have passed without any logged transaction. Take 2 minutes to update your budget and stay on track.";

            if ($this->option('dry-run')) {
                $this->line("• {$user->name} (#{$user->id}) — idle {$idleDays}d");
                continue;
            }

            try {
                Alert::create([
                    'user_id' => $user->id,
                    'type' => 'system',
                    'severity' => 'info',
                    'title_ar' => $titleAr,
                    'title_en' => $titleEn,
                    'message_ar' => $messageAr,
                    'message_en' => $messageEn,
                    'payload' => [
                        'kind' => 'inactivity',
                        'idle_days' => $idleDays,
                    ],
                ]);

                $sent++;
            } catch (Throwable $e) {
                Log::warning('Inactivity reminder failed.', [
                    'user_id' => $user->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        $this->info("✓ Sent: {$sent} | Skipped (already nudged): {$skipped}");
        $this->recordRun('success', [
            'days' => $days,
            'sent' => $sent,
            'skipped' => $skipped,
        ]);

        return self::SUCCESS;
    }
}
