<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\TracksNotificationSetting;
use App\Models\Alert;
use App\Models\Transaction;
use App\Models\User;
use App\Services\FcmService;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

class SendMonthlyReport extends Command
{
    use TracksNotificationSetting;

    protected $signature = 'waffer:monthly-report 
                            {--month= : Override target month (YYYY-MM)} 
                            {--dry-run : Print summary without sending} 
                            {--force : Run even when disabled in settings}';

    protected $description = 'Send a monthly financial summary push notification to every active user.';

    protected string $settingKey = 'monthly_report';

    public function __construct(protected FcmService $fcm)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        if (! $this->ensureEnabled()) {
            return self::SUCCESS;
        }

        // Default: previous month (the one that just ended).
        $target = $this->option('month')
            ? Carbon::createFromFormat('Y-m', $this->option('month'))->startOfMonth()
            : now()->subMonthNoOverflow()->startOfMonth();

        $monthStart = $target->copy()->startOfMonth();
        $monthEnd = $target->copy()->endOfMonth();
        $monthLabelAr = $monthStart->locale('ar')->translatedFormat('F Y');
        $monthLabelEn = $monthStart->locale('en')->translatedFormat('F Y');

        $this->info("Generating monthly reports for {$monthLabelEn} ({$monthStart->toDateString()} → {$monthEnd->toDateString()})");

        $users = User::query()
            ->where('is_active', true)
            ->where('is_admin', false)
            ->get(['id', 'name', 'language', 'currency']);

        if ($users->isEmpty()) {
            $this->warn('No active users.');

            return self::SUCCESS;
        }

        $sent = 0;
        $skipped = 0;

        foreach ($users as $user) {
            $stats = $this->buildUserStats($user, $monthStart, $monthEnd);

            if ($stats['transaction_count'] === 0) {
                $skipped++;
                continue;
            }

            $titleAr = "📊 تقريرك المالي لـ {$monthLabelAr}";
            $titleEn = "📊 Your financial report for {$monthLabelEn}";

            $messageAr = $this->formatMessageAr($stats, $user->currency);
            $messageEn = $this->formatMessageEn($stats, $user->currency);

            if ($this->option('dry-run')) {
                $this->line("• {$user->name} (#{$user->id}): {$stats['transaction_count']} txn, income {$stats['income']}, expenses {$stats['expenses']}");
                continue;
            }

            try {
                $alert = Alert::create([
                    'user_id' => $user->id,
                    'type' => 'system',
                    'severity' => $stats['savings'] >= 0 ? 'success' : 'warning',
                    'title_ar' => $titleAr,
                    'title_en' => $titleEn,
                    'message_ar' => $messageAr,
                    'message_en' => $messageEn,
                    'payload' => [
                        'kind' => 'monthly_report',
                        'month' => $monthStart->format('Y-m'),
                        'income' => $stats['income'],
                        'expenses' => $stats['expenses'],
                        'savings' => $stats['savings'],
                        'transaction_count' => $stats['transaction_count'],
                        'top_category' => $stats['top_category'],
                    ],
                ]);

                // AlertObserver pushes via FCM automatically — but we want a richer payload
                // for monthly report deep-linking, so we push explicitly with extra data.
                $this->fcm->sendToUser($user, [
                    'title_ar' => $titleAr,
                    'title_en' => $titleEn,
                    'body_ar' => $messageAr,
                    'body_en' => $messageEn,
                    'data' => [
                        'type' => 'monthly_report',
                        'alert_id' => (string) $alert->id,
                        'month' => $monthStart->format('Y-m'),
                        'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                    ],
                    'severity' => $stats['savings'] >= 0 ? 'success' : 'warning',
                ]);

                $sent++;
            } catch (Throwable $e) {
                Log::warning('Monthly report dispatch failed.', [
                    'user_id' => $user->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        $this->info("✓ Sent: {$sent} | Skipped (no activity): {$skipped}");
        Log::info('Monthly reports completed.', [
            'month' => $monthStart->format('Y-m'),
            'sent' => $sent,
            'skipped' => $skipped,
        ]);

        $this->recordRun('success', [
            'month' => $monthStart->format('Y-m'),
            'sent' => $sent,
            'skipped' => $skipped,
        ]);

        return self::SUCCESS;
    }

    /**
     * @return array{income:float,expenses:float,savings:float,transaction_count:int,top_category:?string}
     */
    protected function buildUserStats(User $user, Carbon $start, Carbon $end): array
    {
        $rows = Transaction::query()
            ->where('user_id', $user->id)
            ->whereBetween('transaction_date', [$start, $end])
            ->selectRaw("type, SUM(amount) as total, COUNT(*) as cnt")
            ->groupBy('type')
            ->pluck('total', 'type');

        $income = (float) ($rows['income'] ?? 0);
        $expenses = (float) ($rows['expense'] ?? 0);

        $count = (int) Transaction::query()
            ->where('user_id', $user->id)
            ->whereBetween('transaction_date', [$start, $end])
            ->count();

        $topCategory = Transaction::query()
            ->where('user_id', $user->id)
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->whereNotNull('category_id')
            ->selectRaw('category_id, SUM(amount) as total')
            ->groupBy('category_id')
            ->orderByDesc('total')
            ->with('category:id,name_ar,name_en')
            ->first();

        return [
            'income' => $income,
            'expenses' => $expenses,
            'savings' => $income - $expenses,
            'transaction_count' => $count,
            'top_category' => $topCategory?->category?->name_ar,
        ];
    }

    protected function formatMessageAr(array $stats, string $currency): string
    {
        $savings = $stats['savings'];
        $emoji = $savings >= 0 ? '✅' : '⚠️';
        $verdict = $savings >= 0 ? "وفّرت {$this->fmt($savings)} {$currency}" : "تجاوزت دخلك بـ {$this->fmt(abs($savings))} {$currency}";

        $line = "{$emoji} الدخل: {$this->fmt($stats['income'])} {$currency} | المصروف: {$this->fmt($stats['expenses'])} {$currency} — {$verdict}.";

        if ($stats['top_category']) {
            $line .= " الفئة الأعلى: {$stats['top_category']}.";
        }

        return $line;
    }

    protected function formatMessageEn(array $stats, string $currency): string
    {
        $savings = $stats['savings'];
        $emoji = $savings >= 0 ? '✅' : '⚠️';
        $verdict = $savings >= 0 ? "saved {$this->fmt($savings)} {$currency}" : "overspent by {$this->fmt(abs($savings))} {$currency}";

        $line = "{$emoji} Income: {$this->fmt($stats['income'])} {$currency} | Expenses: {$this->fmt($stats['expenses'])} {$currency} — {$verdict}.";

        if ($stats['top_category']) {
            $line .= " Top category: {$stats['top_category']}.";
        }

        return $line;
    }

    protected function fmt(float $n): string
    {
        return number_format($n, 2);
    }
}
