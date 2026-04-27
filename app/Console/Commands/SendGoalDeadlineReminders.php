<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\TracksNotificationSetting;
use App\Models\Alert;
use App\Models\SavingGoal;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

class SendGoalDeadlineReminders extends Command
{
    use TracksNotificationSetting;

    protected $signature = 'waffer:goal-deadline-reminders 
                            {--days=7 : Number of days before deadline} 
                            {--dry-run} 
                            {--force : Run even when disabled in settings}';

    protected $description = 'Remind users when their saving goal deadline is approaching.';

    /**
     * Resolved dynamically from the --days option (e.g. goal_deadline_7d, goal_deadline_1d).
     */
    protected string $settingKey = 'goal_deadline_7d';

    protected function setting(): ?\App\Models\NotificationSetting
    {
        $days = (int) $this->option('days');
        $this->settingKey = "goal_deadline_{$days}d";

        return parent::setting();
    }

    public function handle(): int
    {
        if (! $this->ensureEnabled()) {
            return self::SUCCESS;
        }

        $days = (int) $this->option('days');
        $targetDate = now()->addDays($days)->toDateString();

        // Goals not yet achieved/cancelled, with deadline exactly N days from today.
        $goals = SavingGoal::query()
            ->with('user:id,language,is_active')
            ->whereDate('deadline', $targetDate)
            ->whereNotIn('status', ['achieved', 'cancelled'])
            ->get();

        if ($goals->isEmpty()) {
            $this->info("No goals with deadline on {$targetDate}.");

            return self::SUCCESS;
        }

        $this->info("Found {$goals->count()} goals with deadline on {$targetDate} ({$days}-day reminder).");

        $sent = 0;
        $skipped = 0;

        foreach ($goals as $goal) {
            if (! $goal->user || ! $goal->user->is_active) {
                $skipped++;
                continue;
            }

            // Avoid duplicate reminder if already sent today.
            $already = Alert::query()
                ->where('saving_goal_id', $goal->id)
                ->where('type', 'goal_progress')
                ->whereJsonContains('payload->reminder_kind', 'deadline_'.$days)
                ->whereDate('created_at', now()->toDateString())
                ->exists();

            if ($already) {
                $skipped++;
                continue;
            }

            $remaining = (float) $goal->remaining;
            $progress = round((float) $goal->progress_percentage, 1);
            $titleAr = "⏰ اقترب موعد هدفك: {$goal->title}";
            $titleEn = "⏰ Goal deadline approaching: {$goal->title}";

            $messageAr = $remaining > 0
                ? "باقي {$days} أيام للموعد، تبقّى عليك {$this->fmt($remaining)} {$goal->currency} ({$progress}% منجز). شمّر سواعدك!"
                : "باقي {$days} أيام للموعد — أنت قريب جداً ({$progress}%). أكمل الإنجاز!";

            $messageEn = $remaining > 0
                ? "{$days} days left, you still need {$this->fmt($remaining)} {$goal->currency} ({$progress}% done). Push harder!"
                : "{$days} days left — you're almost there ({$progress}%). Finish strong!";

            if ($this->option('dry-run')) {
                $this->line("• Goal #{$goal->id} for user #{$goal->user_id}: {$messageAr}");
                continue;
            }

            try {
                Alert::create([
                    'user_id' => $goal->user_id,
                    'saving_goal_id' => $goal->id,
                    'type' => 'goal_progress',
                    'severity' => $remaining > 0 ? 'warning' : 'info',
                    'title_ar' => $titleAr,
                    'title_en' => $titleEn,
                    'message_ar' => $messageAr,
                    'message_en' => $messageEn,
                    'payload' => [
                        'goal_id' => $goal->id,
                        'reminder_kind' => 'deadline_'.$days,
                        'days_left' => $days,
                        'remaining' => $remaining,
                        'progress' => $progress,
                    ],
                ]);

                $sent++;
            } catch (Throwable $e) {
                Log::warning('Goal deadline reminder failed.', [
                    'goal_id' => $goal->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        $this->info("✓ Sent: {$sent} | Skipped: {$skipped}");
        $this->recordRun('success', [
            'days' => $days,
            'target_date' => $targetDate,
            'sent' => $sent,
            'skipped' => $skipped,
        ]);

        return self::SUCCESS;
    }

    protected function fmt(float $n): string
    {
        return number_format($n, 2);
    }
}
