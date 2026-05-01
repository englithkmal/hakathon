<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\TracksNotificationSetting;
use App\Models\MonthlySummary;
use App\Models\User;
use App\Services\FcmService;
use App\Services\MonthlyCloser;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Reads the monthly_summaries snapshot built by `waffer:close-month` and pushes
 * a recap notification. If no snapshot exists for a user, the closer is invoked
 * on-the-fly so the report is never silently dropped (e.g. when close-month
 * cron failed or this command runs before it on a manually triggered backfill).
 *
 * Note on the `monthly_summary_ready` alert that close-month already emits:
 * that one is the "report is ready, tap to view" cue. This command is the
 * opt-in summary push managed by `notification_settings.monthly_report` —
 * lets the admin disable the recap message without disabling the snapshot.
 */
class SendMonthlyReport extends Command
{
    use TracksNotificationSetting;

    protected $signature = 'waffer:monthly-report
                            {--month= : Override target month (YYYY-MM)}
                            {--user= : Limit to a single user_id}
                            {--dry-run : Print summary without sending}
                            {--force : Run even when disabled in settings}';

    protected $description = 'Push a recap notification for the previous month, sourced from monthly_summaries.';

    protected string $settingKey = 'monthly_report';

    public function __construct(
        protected FcmService $fcm,
        protected MonthlyCloser $closer,
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        if (! $this->ensureEnabled()) {
            return self::SUCCESS;
        }

        $target = $this->option('month')
            ? Carbon::createFromFormat('Y-m', $this->option('month'))->startOfMonth()
            : now()->subMonthNoOverflow()->startOfMonth();

        $year = (int) $target->year;
        $month = (int) $target->month;
        $monthLabelAr = $target->copy()->locale('ar')->translatedFormat('F Y');
        $monthLabelEn = $target->copy()->locale('en')->translatedFormat('F Y');

        $this->info("Building reports for {$monthLabelEn} ({$year}-".str_pad((string) $month, 2, '0', STR_PAD_LEFT).')');

        $users = User::query()
            ->where('is_active', true)
            ->where('is_admin', false)
            ->when($this->option('user'), fn ($q, $id) => $q->whereKey((int) $id))
            ->get(['id', 'name', 'language', 'currency']);

        if ($users->isEmpty()) {
            $this->warn('No active users.');

            return self::SUCCESS;
        }

        $sent = 0;
        $skipped = 0;
        $closedOnDemand = 0;

        foreach ($users as $user) {
            try {
                $summary = MonthlySummary::query()
                    ->where('user_id', $user->id)
                    ->where('year', $year)
                    ->where('month', $month)
                    ->first();

                if (! $summary) {
                    // Closer is idempotent — safe to call. Returns null for empty months.
                    $summary = $this->closer->closeUserMonth($user, $year, $month, MonthlySummary::CLOSED_BY_CRON);
                    if ($summary !== null) {
                        $closedOnDemand++;
                    }
                }

                if (! $summary || $summary->transaction_count === 0) {
                    $skipped++;
                    continue;
                }

                $titleAr = "📊 تقريرك المالي لـ {$monthLabelAr}";
                $titleEn = "📊 Your financial report for {$monthLabelEn}";
                $messageAr = $this->formatMessageAr($summary, $user->currency ?? 'SAR');
                $messageEn = $this->formatMessageEn($summary, $user->currency ?? 'SAR');

                if ($this->option('dry-run')) {
                    $this->line("• {$user->name} (#{$user->id}): {$summary->transaction_count} txn, income {$summary->total_income}, expenses {$summary->total_expenses}, unallocated {$summary->unallocated_savings}");
                    continue;
                }

                $this->fcm->sendToUser($user, [
                    'title_ar' => $titleAr,
                    'title_en' => $titleEn,
                    'body_ar' => $messageAr,
                    'body_en' => $messageEn,
                    'data' => [
                        'type' => 'monthly_report',
                        'monthly_summary_id' => (string) $summary->id,
                        'year' => (string) $summary->year,
                        'month' => (string) $summary->month,
                        'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                    ],
                    'severity' => $summary->total_expenses > $summary->total_income ? 'warning' : 'success',
                ]);

                $sent++;
            } catch (Throwable $e) {
                Log::warning('Monthly report dispatch failed.', [
                    'user_id' => $user->id,
                    'year' => $year,
                    'month' => $month,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        $this->info("✓ Sent: {$sent} | Skipped: {$skipped} | Closed on demand: {$closedOnDemand}");

        $this->recordRun('success', [
            'year' => $year,
            'month' => $month,
            'sent' => $sent,
            'skipped' => $skipped,
            'closed_on_demand' => $closedOnDemand,
        ]);

        return self::SUCCESS;
    }

    protected function formatMessageAr(MonthlySummary $s, string $currency): string
    {
        $unalloc = (float) $s->unallocated_savings;
        $emoji = $unalloc >= 0 ? '✅' : '⚠️';
        $verdict = $unalloc >= 0
            ? "وفّرت {$this->fmt($unalloc)} {$currency}"
            : 'تجاوزت دخلك';

        $line = "{$emoji} الدخل: {$this->fmt($s->total_income)} {$currency} | المصروف: {$this->fmt($s->total_expenses)} {$currency} — {$verdict}.";

        $top = $s->top_categories[0] ?? null;
        if ($top) {
            $line .= " الفئة الأعلى: {$top['name_ar']}.";
        }

        if ((float) $s->total_goal_deposits > 0) {
            $line .= " إيداعات للأهداف: {$this->fmt($s->total_goal_deposits)} {$currency}.";
        }

        return $line;
    }

    protected function formatMessageEn(MonthlySummary $s, string $currency): string
    {
        $unalloc = (float) $s->unallocated_savings;
        $emoji = $unalloc >= 0 ? '✅' : '⚠️';
        $verdict = $unalloc >= 0
            ? "saved {$this->fmt($unalloc)} {$currency}"
            : 'overspent';

        $line = "{$emoji} Income: {$this->fmt($s->total_income)} {$currency} | Expenses: {$this->fmt($s->total_expenses)} {$currency} — {$verdict}.";

        $top = $s->top_categories[0] ?? null;
        if ($top) {
            $line .= " Top category: {$top['name_en']}.";
        }

        if ((float) $s->total_goal_deposits > 0) {
            $line .= " Goal deposits: {$this->fmt($s->total_goal_deposits)} {$currency}.";
        }

        return $line;
    }

    protected function fmt(float $n): string
    {
        return number_format($n, 2);
    }
}
