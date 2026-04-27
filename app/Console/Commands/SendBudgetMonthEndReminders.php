<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\TracksNotificationSetting;
use App\Models\Alert;
use App\Models\Budget;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

class SendBudgetMonthEndReminders extends Command
{
    use TracksNotificationSetting;

    protected $signature = 'waffer:budget-month-end 
                            {--dry-run} 
                            {--force : Run even when disabled in settings}';

    protected $description = 'Run during the last 3 days of the month: nudge users about their current budget status.';

    protected string $settingKey = 'budget_month_end';

    public function handle(): int
    {
        if (! $this->ensureEnabled()) {
            return self::SUCCESS;
        }

        $today = now();
        $daysLeft = $today->daysInMonth - $today->day;

        if ($daysLeft > 3) {
            $this->info("Today is {$today->toDateString()} — {$daysLeft} days left in month. Reminder skipped (only fires in the last 3 days).");

            return self::SUCCESS;
        }

        $budgets = Budget::query()
            ->with('user:id,language,is_active')
            ->where('month', $today->month)
            ->where('year', $today->year)
            ->where('status', 'active')
            ->get();

        if ($budgets->isEmpty()) {
            $this->info('No active budgets for this month.');

            return self::SUCCESS;
        }

        $this->info("Processing {$budgets->count()} active budgets ({$daysLeft} days remaining in month).");

        $sent = 0;
        $skipped = 0;

        foreach ($budgets as $budget) {
            if (! $budget->user || ! $budget->user->is_active) {
                $skipped++;
                continue;
            }

            // Only one month-end reminder per budget per month.
            $already = Alert::query()
                ->where('user_id', $budget->user_id)
                ->where('type', 'system')
                ->whereJsonContains('payload->kind', 'budget_month_end')
                ->whereJsonContains('payload->budget_id', $budget->id)
                ->exists();

            if ($already) {
                $skipped++;
                continue;
            }

            $progress = (float) $budget->progress_percentage;
            $remaining = (float) $budget->remaining;
            $spent = (float) $budget->total_spent;
            $allocated = (float) $budget->total_amount;
            $currency = $budget->currency;

            [$severity, $titleAr, $titleEn, $messageAr, $messageEn] = $this->buildMessage(
                progress: $progress,
                daysLeft: $daysLeft,
                remaining: $remaining,
                spent: $spent,
                allocated: $allocated,
                currency: $currency,
            );

            if ($this->option('dry-run')) {
                $this->line("• User #{$budget->user_id} | {$progress}% used | {$daysLeft}d left → {$titleAr}");
                continue;
            }

            try {
                Alert::create([
                    'user_id' => $budget->user_id,
                    'type' => 'system',
                    'severity' => $severity,
                    'title_ar' => $titleAr,
                    'title_en' => $titleEn,
                    'message_ar' => $messageAr,
                    'message_en' => $messageEn,
                    'payload' => [
                        'kind' => 'budget_month_end',
                        'budget_id' => $budget->id,
                        'days_left' => $daysLeft,
                        'progress' => $progress,
                        'remaining' => $remaining,
                        'spent' => $spent,
                        'allocated' => $allocated,
                    ],
                ]);

                $sent++;
            } catch (Throwable $e) {
                Log::warning('Budget month-end reminder failed.', [
                    'budget_id' => $budget->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        $this->info("✓ Sent: {$sent} | Skipped: {$skipped}");
        $this->recordRun('success', [
            'days_left' => $daysLeft,
            'sent' => $sent,
            'skipped' => $skipped,
        ]);

        return self::SUCCESS;
    }

    /**
     * @return array{0:string,1:string,2:string,3:string,4:string} severity, titles, messages
     */
    protected function buildMessage(float $progress, int $daysLeft, float $remaining, float $spent, float $allocated, string $currency): array
    {
        if ($progress >= 100) {
            return [
                'critical',
                '⚠️ تجاوزت ميزانية الشهر',
                '⚠️ Monthly budget exceeded',
                "صرفت {$this->fmt($spent)} {$currency} من أصل {$this->fmt($allocated)} {$currency}. باقي {$daysLeft} أيام — حاول تخفّف للحفاظ على ادخارك.",
                "Spent {$this->fmt($spent)} {$currency} of {$this->fmt($allocated)} {$currency}. {$daysLeft} days left — slow down to protect your savings.",
            ];
        }

        if ($progress >= 80) {
            return [
                'warning',
                '⏳ اقتربت من حدّ الميزانية',
                '⏳ Close to budget limit',
                "وصلت إلى {$progress}% من ميزانيتك. باقي {$this->fmt($remaining)} {$currency} لـ {$daysLeft} أيام — وزّع بحذر.",
                "You're at {$progress}% of your budget. {$this->fmt($remaining)} {$currency} remain for {$daysLeft} days — pace carefully.",
            ];
        }

        return [
            'success',
            '✅ ميزانيتك في وضع صحي',
            '✅ Budget is on track',
            "صرفت {$progress}% فقط، باقي {$this->fmt($remaining)} {$currency} لـ {$daysLeft} أيام. أداء ممتاز!",
            "Only {$progress}% used, {$this->fmt($remaining)} {$currency} left for {$daysLeft} days. Great pace!",
        ];
    }

    protected function fmt(float $n): string
    {
        return number_format($n, 2);
    }
}
