<?php

namespace App\Services;

use App\Models\Alert;
use App\Models\Budget;
use App\Models\Category;
use App\Models\MonthlySummary;
use App\Models\Transaction;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Builds the immutable snapshot for a (user, year, month) and locks the
 * matching budget. This is the only place that writes to monthly_summaries
 * during normal operation (BR-06). The artisan command `waffer:close-month`
 * is just a thin wrapper around `closeUserMonth`.
 *
 * Idempotency:
 *  - If a summary already exists for the (user, year, month), `closeUserMonth`
 *    returns the existing row unchanged unless `force = true`, in which case
 *    fields are recomputed and overwritten while keeping the same id and
 *    `closed_at` (the row's "first closed" timestamp).
 */
class MonthlyCloser
{
    public function __construct(protected FcmService $fcm) {}

    /**
     * @return MonthlySummary|null The created/updated summary, or null when nothing to close
     *                              (no budget AND no transactions — empty months are skipped to
     *                              avoid noise). Re-runs with force return the existing row.
     */
    public function closeUserMonth(
        User $user,
        int $year,
        int $month,
        string $closedBy = MonthlySummary::CLOSED_BY_CRON,
        bool $force = false
    ): ?MonthlySummary {
        $month = max(1, min(12, $month));
        $year = max(2000, min(2100, $year));

        $start = Carbon::createFromDate($year, $month, 1)->startOfDay();
        $end = (clone $start)->endOfMonth()->endOfDay();

        return DB::transaction(function () use ($user, $year, $month, $start, $end, $closedBy, $force) {
            $existing = MonthlySummary::query()
                ->where('user_id', $user->id)
                ->where('year', $year)
                ->where('month', $month)
                ->first();

            if ($existing && ! $force) {
                return $existing;
            }

            $stats = $this->aggregateCashFlow($user, $start, $end);
            $budget = $this->loadBudget($user, $year, $month);

            // Skip empty months unless we're force-recomputing an existing row.
            if (! $existing && ! $budget && $stats['transaction_count'] === 0) {
                return null;
            }

            $payload = [
                'user_id' => $user->id,
                'month' => $month,
                'year' => $year,
                'period_start' => $start->toDateString(),
                'period_end' => $end->toDateString(),
                'total_income' => $stats['income'],
                'total_expenses' => $stats['expenses'],
                'total_goal_deposits' => $stats['goal_deposits'],
                'unallocated_savings' => max(0, $stats['income'] - $stats['expenses'] - $stats['goal_deposits']),
                'transaction_count' => $stats['transaction_count'],
                'budget_id' => $budget?->id,
                'budget_total_amount' => $budget ? (float) $budget->total_amount : null,
                'budget_total_spent' => $budget ? (float) $budget->total_spent : null,
                'budget_adherence_pct' => $budget && (float) $budget->total_amount > 0
                    ? round(((float) $budget->total_spent / (float) $budget->total_amount) * 100, 2)
                    : null,
                'top_categories' => $this->topCategories($user, $start, $end),
                // Allocation fields are intentionally NOT recomputed on force-close: they are mutated
                // by POST /monthly-summaries/{id}/allocate, not by the closing process itself.
            ];

            if ($existing) {
                $existing->forceFill($payload)->save();
                $summary = $existing->fresh();
            } else {
                $payload['allocation_status'] = MonthlySummary::ALLOCATION_UNALLOCATED;
                $payload['allocated_amount'] = 0;
                $payload['closed_at'] = now();
                $payload['closed_by'] = $closedBy;

                $summary = MonthlySummary::create($payload);
            }

            // Lock the budget so it stops accepting new transactions (BudgetLinker
            // already ignores non-active budgets when attaching budget_id).
            if ($budget && $budget->status === 'active') {
                $budget->forceFill(['status' => 'closed'])->saveQuietly();
            }

            // Notify only on first close, never on force-recompute (which is an admin op).
            if (! $existing) {
                $this->dispatchReadyAlert($user, $summary);
            }

            return $summary;
        });
    }

    /**
     * @return array{income:float, expenses:float, goal_deposits:float, transaction_count:int}
     */
    protected function aggregateCashFlow(User $user, Carbon $start, Carbon $end): array
    {
        $rows = Transaction::query()
            ->selectRaw('type, COALESCE(saving_goal_id, 0) as has_goal, SUM(amount) as total, COUNT(*) as cnt')
            ->where('user_id', $user->id)
            ->whereBetween('transaction_date', [$start, $end])
            ->groupBy('type', 'has_goal')
            ->get();

        $income = 0.0;
        $expenses = 0.0;
        $goalDeposits = 0.0;
        $count = 0;

        foreach ($rows as $row) {
            $count += (int) $row->cnt;
            $total = (float) $row->total;

            match ($row->type) {
                'income' => $income += $total,
                'expense' => $expenses += $total,
                'saving' => $row->has_goal > 0
                    ? $goalDeposits += $total
                    : null, // saving without a goal_id falls into "unallocated_savings" naturally.
                default => null,
            };
        }

        return [
            'income' => round($income, 2),
            'expenses' => round($expenses, 2),
            'goal_deposits' => round($goalDeposits, 2),
            'transaction_count' => $count,
        ];
    }

    /**
     * Returns the top 3 expense categories with their share of total expenses.
     *
     * @return list<array{category_id:int, name_ar:string, name_en:string, total:float, count:int, percentage:float}>
     */
    protected function topCategories(User $user, Carbon $start, Carbon $end): array
    {
        $totalExpenses = (float) Transaction::query()
            ->where('user_id', $user->id)
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->sum('amount');

        if ($totalExpenses <= 0) {
            return [];
        }

        $rows = Transaction::query()
            ->selectRaw('category_id, SUM(amount) as total, COUNT(*) as cnt')
            ->where('user_id', $user->id)
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->whereNotNull('category_id')
            ->groupBy('category_id')
            ->orderByDesc('total')
            ->limit(3)
            ->get();

        $categories = Category::query()
            ->whereIn('id', $rows->pluck('category_id'))
            ->get(['id', 'name_ar', 'name_en'])
            ->keyBy('id');

        return $rows->map(function ($row) use ($categories, $totalExpenses) {
            $cat = $categories->get($row->category_id);

            return [
                'category_id' => (int) $row->category_id,
                'name_ar' => $cat?->name_ar ?? '',
                'name_en' => $cat?->name_en ?? '',
                'total' => round((float) $row->total, 2),
                'count' => (int) $row->cnt,
                'percentage' => round(((float) $row->total / $totalExpenses) * 100, 2),
            ];
        })->values()->all();
    }

    protected function loadBudget(User $user, int $year, int $month): ?Budget
    {
        return Budget::query()
            ->where('user_id', $user->id)
            ->where('year', $year)
            ->where('month', $month)
            ->whereIn('status', ['active', 'closed'])
            ->first();
    }

    protected function dispatchReadyAlert(User $user, MonthlySummary $summary): void
    {
        $monthLabelAr = Carbon::createFromDate($summary->year, $summary->month, 1)
            ->locale('ar')
            ->translatedFormat('F Y');
        $monthLabelEn = Carbon::createFromDate($summary->year, $summary->month, 1)
            ->locale('en')
            ->translatedFormat('F Y');
        $currency = $user->currency ?? 'SAR';
        $verdict = (float) $summary->unallocated_savings >= 0
            ? "وفّرت {$summary->unallocated_savings} {$currency}"
            : 'تجاوزت الميزانية';
        $verdictEn = (float) $summary->unallocated_savings >= 0
            ? "you saved {$summary->unallocated_savings} {$currency}"
            : 'overspent';

        try {
            $alert = Alert::create([
                'user_id' => $user->id,
                'type' => 'monthly_summary_ready',
                'severity' => $summary->total_expenses > $summary->total_income ? 'warning' : 'success',
                'title_ar' => "📊 جاهز: تقرير {$monthLabelAr}",
                'title_en' => "📊 Ready: {$monthLabelEn} report",
                'message_ar' => "{$verdict} — اطّلع على تفاصيل أكبر فئات الصرف وتقدّم أهدافك.",
                'message_en' => "{$verdictEn} — see your top categories and goal progress.",
                'icon' => 'heroicon-o-document-chart-bar',
                'deeplink' => "/monthly-summaries/{$summary->year}/{$summary->month}",
                'payload' => [
                    'kind' => 'monthly_summary_ready',
                    'monthly_summary_id' => $summary->id,
                    'year' => $summary->year,
                    'month' => $summary->month,
                    'income' => (float) $summary->total_income,
                    'expenses' => (float) $summary->total_expenses,
                    'goal_deposits' => (float) $summary->total_goal_deposits,
                    'unallocated' => (float) $summary->unallocated_savings,
                ],
            ]);

            // AlertObserver will also push via FCM, but we want richer data on the wire
            // for deep-linking — replicate the dispatch here with a typed payload.
            $this->fcm->sendToUser($user, [
                'title_ar' => $alert->title_ar,
                'title_en' => $alert->title_en,
                'body_ar' => $alert->message_ar,
                'body_en' => $alert->message_en,
                'data' => [
                    'type' => 'monthly_summary_ready',
                    'alert_id' => (string) $alert->id,
                    'monthly_summary_id' => (string) $summary->id,
                    'year' => (string) $summary->year,
                    'month' => (string) $summary->month,
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                ],
                'severity' => $alert->severity,
            ]);
        } catch (\Throwable $e) {
            Log::warning('Monthly summary ready alert failed.', [
                'user_id' => $user->id,
                'monthly_summary_id' => $summary->id,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
