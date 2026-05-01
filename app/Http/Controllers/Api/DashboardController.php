<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\AlertResource;
use App\Http\Resources\BudgetResource;
use App\Http\Resources\CategoryResource;
use App\Http\Resources\SavingGoalResource;
use App\Http\Resources\TipResource;
use App\Http\Resources\TransactionResource;
use App\Models\Alert;
use App\Models\Budget;
use App\Models\MonthlySummary;
use App\Models\SavingGoal;
use App\Models\Tip;
use App\Models\Transaction;
use App\Models\User;
use App\Services\BudgetService;
use App\Services\PeriodResolver;
use App\Traits\ApiResponse;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected BudgetService $budgetService,
        protected PeriodResolver $periodResolver,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $period = $this->periodResolver->resolve($user, $request);
        $month = $period->month;
        $year = $period->year;

        $budget = $this->budgetService->getCurrentBudget($user, $month, $year);

        $lastActiveBudget = $budget === null
            ? $this->latestActiveBudgetForUser($user, $month, $year)
            : null;

        $thisMonthIncome = (float) Transaction::query()
            ->where('user_id', $user->id)
            ->where('type', 'income')
            ->whereMonth('transaction_date', $month)
            ->whereYear('transaction_date', $year)
            ->sum('amount');

        $thisMonthExpenses = (float) Transaction::query()
            ->where('user_id', $user->id)
            ->where('type', 'expense')
            ->whereMonth('transaction_date', $month)
            ->whereYear('transaction_date', $year)
            ->sum('amount');

        $thisMonthSavings = (float) Transaction::query()
            ->where('user_id', $user->id)
            ->where('type', 'saving')
            ->whereMonth('transaction_date', $month)
            ->whereYear('transaction_date', $year)
            ->sum('amount');

        // Baseline from profile + recorded income transactions (do not replace one with the other).
        $monthlyIncomeProfile = (float) ($user->monthly_income ?? 0);
        $totalIncomeForBalance = $monthlyIncomeProfile + $thisMonthIncome;
        $balance = $totalIncomeForBalance - $thisMonthExpenses - $thisMonthSavings;

        $recentTransactions = Transaction::query()
            ->with('category')
            ->where('user_id', $user->id)
            ->orderByDesc('transaction_date')
            ->limit(5)
            ->get();

        $activeGoals = SavingGoal::query()
            ->where('user_id', $user->id)
            ->where('status', 'active')
            ->orderByDesc('created_at')
            ->limit(3)
            ->get();

        $savingsOverview = $this->buildSavingsOverview($user->id);

        $monthTransactionsCount = Transaction::query()
            ->where('user_id', $user->id)
            ->whereMonth('transaction_date', $month)
            ->whereYear('transaction_date', $year)
            ->count();

        $quickInsights = $this->buildQuickInsights($user, $month, $year, $totalIncomeForBalance);

        $monthWeeklySeries = $this->buildMonthWeeklySeries($user, $month, $year);

        $recentAlerts = Alert::query()
            ->where('user_id', $user->id)
            ->where('is_read', false)
            ->orderByDesc('created_at')
            ->limit(5)
            ->get();

        $unreadAlertsCount = Alert::query()
            ->where('user_id', $user->id)
            ->where('is_read', false)
            ->count();

        $tipOfTheDay = Tip::query()
            ->where('is_active', true)
            ->with('category')
            ->inRandomOrder()
            ->first();

        $budgetPayload = $budget
            ? array_merge((new BudgetResource($budget))->resolve(), ['exists' => true])
            : $this->emptyBudgetPayload($user, $month, $year);

        $monthlySummary = $this->buildMonthlySummarySection($user);

        return $this->successResponse([
            'currency' => $user->currency ?? 'SAR',
            'period' => $period->toArray(),
            'has_active_budget' => $budget !== null,
            'summary' => [
                'income' => $thisMonthIncome,
                'monthly_income' => $monthlyIncomeProfile,
                'total_income' => $totalIncomeForBalance,
                'expenses' => $thisMonthExpenses,
                'savings' => $thisMonthSavings,
                'balance' => $balance,
            ],
            'budget' => $budgetPayload,
            'last_active_budget' => $this->lastActiveBudgetEnvelope($budget, $lastActiveBudget, $user, $month, $year),
            'quick_insights' => $quickInsights,
            'month_weekly_series' => $monthWeeklySeries,
            'savings_overview' => $savingsOverview,
            'monthly_summary' => $monthlySummary,
            'month_transactions_count' => $monthTransactionsCount,
            'recent_transactions' => TransactionResource::collection($recentTransactions),
            'active_goals' => SavingGoalResource::collection($activeGoals),
            'unread_alerts_count' => $unreadAlertsCount,
            'recent_alerts' => AlertResource::collection($recentAlerts),
            'tip_of_the_day' => $tipOfTheDay
                ? (new TipResource($tipOfTheDay))->resolve()
                : TipResource::emptyTipPayload(),
        ], '');
    }

    /**
     * Surfaces the most recent closed month so the Mobile can render a banner
     * without polling /monthly-summaries. Includes:
     *   - latest snapshot (income/expenses/unallocated/adherence + deeplink)
     *   - whether the matching monthly_summary_ready alert is still unread
     *   - aggregates of "wafer مفكوك" across all closed months (drives the
     *     "خصّص الوفر إلى أهداف" call-to-action).
     *
     * Returns `latest = null` for users who never had a month closed; the
     * Mobile should hide the section in that case.
     *
     * @return array<string, mixed>
     */
    protected function buildMonthlySummarySection(User $user): array
    {
        $latest = MonthlySummary::query()
            ->where('user_id', $user->id)
            ->orderByDesc('year')
            ->orderByDesc('month')
            ->first();

        $unallocatedAggregate = MonthlySummary::query()
            ->where('user_id', $user->id)
            ->whereIn('allocation_status', [
                MonthlySummary::ALLOCATION_UNALLOCATED,
                MonthlySummary::ALLOCATION_PARTIAL,
            ])
            ->selectRaw('COUNT(*) as cnt, COALESCE(SUM(unallocated_savings - allocated_amount), 0) as total')
            ->first();

        $pendingCount = (int) ($unallocatedAggregate->cnt ?? 0);
        $pendingTotal = round((float) ($unallocatedAggregate->total ?? 0), 2);

        if (! $latest) {
            return [
                'has_unread_summary' => false,
                'latest' => null,
                'pending_unallocated_count' => 0,
                'pending_unallocated_total' => 0.0,
            ];
        }

        $alert = Alert::query()
            ->where('user_id', $user->id)
            ->where('type', 'monthly_summary_ready')
            ->whereJsonContains('payload->monthly_summary_id', $latest->id)
            ->orderByDesc('id')
            ->first();

        $isAlertUnread = $alert ? ! (bool) $alert->is_read : false;

        return [
            'has_unread_summary' => $isAlertUnread,
            'latest' => [
                'id' => $latest->id,
                'year' => (int) $latest->year,
                'month' => (int) $latest->month,
                'period_start' => $latest->period_start?->toDateString(),
                'period_end' => $latest->period_end?->toDateString(),
                'total_income' => (float) $latest->total_income,
                'total_expenses' => (float) $latest->total_expenses,
                'total_goal_deposits' => (float) $latest->total_goal_deposits,
                'unallocated_savings' => (float) $latest->unallocated_savings,
                'unallocated_remaining' => (float) $latest->unallocated_remaining,
                'budget_adherence_pct' => $latest->budget_adherence_pct !== null
                    ? (float) $latest->budget_adherence_pct
                    : null,
                'allocation_status' => (string) $latest->allocation_status,
                'closed_at' => $latest->closed_at?->toIso8601String(),
                'closed_by' => (string) $latest->closed_by,
                'is_alert_unread' => $isAlertUnread,
                'alert_id' => $alert?->id,
                'deeplink' => "/monthly-summaries/{$latest->year}/{$latest->month}",
                'allocate_endpoint' => "/api/v1/monthly-summaries/{$latest->id}/allocate",
            ],
            'pending_unallocated_count' => $pendingCount,
            'pending_unallocated_total' => $pendingTotal,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    protected function emptyBudgetPayload(User $user, int $month, int $year): array
    {
        $pStart = Carbon::createFromDate($year, $month, 1)->startOfDay();
        $pEnd = (clone $pStart)->endOfMonth();

        return [
            'exists' => false,
            'id' => 0,
            'month' => $month,
            'year' => $year,
            'period_start' => $pStart->toDateString(),
            'period_end' => $pEnd->toDateString(),
            'total_income' => 0.0,
            'total_amount' => 0.0,
            'total_spent' => 0.0,
            'remaining' => 0.0,
            'progress_percentage' => 0.0,
            'currency' => $user->currency ?? 'SAR',
            'status' => 'none',
            'notes' => '',
            'categories' => [],
            'created_at' => '',
            'updated_at' => '',
        ];
    }

    /**
     * @return array{exists: bool, budget: array<string, mixed>, period: array{month: int, year: int}, is_current_period: bool}
     */
    protected function lastActiveBudgetEnvelope(?Budget $current, ?Budget $last, User $user, int $month, int $year): array
    {
        if ($current !== null) {
            return [
                'exists' => false,
                'budget' => $this->emptyBudgetPayload($user, $month, $year),
                'period' => [
                    'month' => $month,
                    'year' => $year,
                ],
                'is_current_period' => true,
            ];
        }

        if ($last !== null) {
            return [
                'exists' => true,
                'budget' => array_merge((new BudgetResource($last))->resolve(), ['exists' => true]),
                'period' => [
                    'month' => $last->month,
                    'year' => $last->year,
                ],
                'is_current_period' => $last->month === $month && $last->year === $year,
            ];
        }

        return [
            'exists' => false,
            'budget' => $this->emptyBudgetPayload($user, $month, $year),
            'period' => [
                'month' => $month,
                'year' => $year,
            ],
            'is_current_period' => false,
        ];
    }

    /**
     * أحدث ميزانية نشطة حتى نهاية الفترة المطلوبة (لا تشمل أشهراً لاحقة عن month/year في الطلب).
     */
    protected function latestActiveBudgetForUser(User $user, int $upToMonth, int $upToYear): ?Budget
    {
        $periodMax = ($upToYear * 100) + $upToMonth;

        return Budget::query()
            ->with(['categories.category'])
            ->where('user_id', $user->id)
            ->where('status', 'active')
            ->whereRaw('(year * 100 + month) <= ?', [$periodMax])
            ->orderByDesc('year')
            ->orderByDesc('month')
            ->first();
    }

    /**
     * @return array{count:int, total_target:float, total_current:float, progress_percentage:float}
     */
    protected function buildSavingsOverview(int $userId): array
    {
        $base = fn () => SavingGoal::query()->where('user_id', $userId)->where('status', 'active');

        $count = (int) $base()->count();
        $totalTarget = (float) $base()->sum('target_amount');
        $totalCurrent = (float) $base()->sum('current_amount');

        return [
            'count' => $count,
            'total_target' => $totalTarget,
            'total_current' => $totalCurrent,
            'progress_percentage' => $totalTarget > 0
                ? round(min(100, ($totalCurrent / $totalTarget) * 100), 2)
                : 0.0,
        ];
    }

    /**
     * أعلى 3 فئات مصروف هذا الشهر (لشريط «رؤى سريعة» في التصميم).
     *
     * @return list<array{category: ?array<string, mixed>, total: float, count: int, percentage: float}>
     */
    /**
     * تقسيم الشهر إلى 4 شرائح (1–7، 8–14، 15–21، 22–نهاية الشهر) لتغذية رسم أسبوعي مثل Figma.
     *
     * @return array{model: string, weeks: list<array<string, mixed>>}
     */
    protected function buildMonthWeeklySeries(User $user, int $month, int $year): array
    {
        $dim = (int) Carbon::createFromDate($year, $month, 1)->daysInMonth;

        $buckets = [
            1 => ['expenses' => 0.0, 'income' => 0.0, 'savings' => 0.0],
            2 => ['expenses' => 0.0, 'income' => 0.0, 'savings' => 0.0],
            3 => ['expenses' => 0.0, 'income' => 0.0, 'savings' => 0.0],
            4 => ['expenses' => 0.0, 'income' => 0.0, 'savings' => 0.0],
        ];

        $txs = Transaction::query()
            ->where('user_id', $user->id)
            ->whereYear('transaction_date', $year)
            ->whereMonth('transaction_date', $month)
            ->get(['type', 'amount', 'transaction_date']);

        foreach ($txs as $tx) {
            $day = (int) Carbon::parse($tx->transaction_date)->day;
            $w = match (true) {
                $day <= 7 => 1,
                $day <= 14 => 2,
                $day <= 21 => 3,
                default => 4,
            };

            $type = (string) $tx->type;
            $amt = (float) $tx->amount;

            if ($type === 'expense') {
                $buckets[$w]['expenses'] += $amt;
            } elseif ($type === 'income') {
                $buckets[$w]['income'] += $amt;
            } elseif ($type === 'saving') {
                $buckets[$w]['savings'] += $amt;
            }
        }

        $rawSegments = [
            1 => [1, 7],
            2 => [8, 14],
            3 => [15, 21],
            4 => [22, $dim],
        ];

        $weeks = [];
        foreach ($rawSegments as $weekNum => [$startDay, $segmentEnd]) {
            if ($startDay > $dim) {
                $weeks[] = [
                    'week' => $weekNum,
                    'start_day' => null,
                    'end_day' => null,
                    'start_date' => null,
                    'end_date' => null,
                    'label_ar' => 'الأسبوع '.$weekNum,
                    'label_en' => 'Week '.$weekNum,
                    'expenses' => 0.0,
                    'income' => 0.0,
                    'savings' => 0.0,
                    'net_flow' => 0.0,
                ];

                continue;
            }

            $endDay = min($segmentEnd, $dim);
            $startDate = Carbon::createFromDate($year, $month, $startDay)->toDateString();
            $endDate = Carbon::createFromDate($year, $month, $endDay)->toDateString();

            $e = round($buckets[$weekNum]['expenses'], 2);
            $i = round($buckets[$weekNum]['income'], 2);
            $s = round($buckets[$weekNum]['savings'], 2);

            $weeks[] = [
                'week' => $weekNum,
                'start_day' => $startDay,
                'end_day' => $endDay,
                'start_date' => $startDate,
                'end_date' => $endDate,
                'label_ar' => 'الأسبوع '.$weekNum,
                'label_en' => 'Week '.$weekNum,
                'expenses' => $e,
                'income' => $i,
                'savings' => $s,
                'net_flow' => round($i - $e - $s, 2),
            ];
        }

        return [
            'model' => 'month_calendar_quarters',
            'description_ar' => 'الشهر مقسوم إلى أربعة أجزاء: أيام 1–7، 8–14، 15–21، 22–آخر يوم في الشهر.',
            'description_en' => 'Month split into four day ranges: 1–7, 8–14, 15–21, 22–last day of month.',
            'weeks' => $weeks,
        ];
    }

    /**
     * @param  float  $totalIncomeForBalance  Same as summary.total_income (profile monthly_income + income txns).
     */
    protected function buildQuickInsights(User $user, int $month, int $year, float $totalIncomeForBalance): array
    {
        $byCategory = Transaction::query()
            ->select('category_id')
            ->selectRaw('SUM(amount) as total')
            ->selectRaw('COUNT(*) as count')
            ->where('user_id', $user->id)
            ->where('type', 'expense')
            ->whereMonth('transaction_date', $month)
            ->whereYear('transaction_date', $year)
            ->whereNotNull('category_id')
            ->groupBy('category_id')
            ->with('category:id,name_ar,name_en,icon,color')
            ->get();

        $totalExpenses = (float) $byCategory->sum('total');
        // Bar "وين راحت فلوسك": share of money in (not share of expenses only — avoids 100% on sole category).
        $denominator = $totalIncomeForBalance > 0 ? $totalIncomeForBalance : $totalExpenses;

        return $byCategory
            ->map(function ($item) use ($denominator) {
                return [
                    'category' => $item->category
                        ? (new CategoryResource($item->category))->resolve()
                        : CategoryResource::emptyShape(),
                    'total' => (float) $item->total,
                    'count' => (int) $item->count,
                    'percentage' => $denominator > 0 ? round(((float) $item->total / $denominator) * 100, 2) : 0,
                ];
            })
            ->sortByDesc('total')
            ->values()
            ->take(3)
            ->all();
    }

    public function expenseAnalysis(Request $request): JsonResponse
    {
        $user = $request->user();
        $period = $this->periodResolver->resolve($user, $request);

        $byCategory = Transaction::query()
            ->select('category_id')
            ->selectRaw('SUM(amount) as total')
            ->selectRaw('COUNT(*) as count')
            ->where('user_id', $user->id)
            ->where('type', 'expense')
            ->whereMonth('transaction_date', $period->month)
            ->whereYear('transaction_date', $period->year)
            ->whereNotNull('category_id')
            ->groupBy('category_id')
            ->with('category:id,name_ar,name_en,icon,color')
            ->get();

        $totalExpenses = (float) $byCategory->sum('total');

        $analysis = $byCategory->map(function ($item) use ($totalExpenses) {
            return [
                'category' => $item->category ? [
                    'id' => $item->category->id,
                    'name' => app()->getLocale() === 'ar' ? $item->category->name_ar : $item->category->name_en,
                    'icon' => $item->category->icon,
                    'color' => $item->category->color,
                ] : null,
                'total' => (float) $item->total,
                'count' => (int) $item->count,
                'percentage' => $totalExpenses > 0 ? round(($item->total / $totalExpenses) * 100, 2) : 0,
            ];
        })->sortByDesc('total')->values();

        return $this->successResponse([
            'period' => $period->toArray(),
            'total_expenses' => $totalExpenses,
            'by_category' => $analysis,
        ]);
    }

    public function monthlyReport(Request $request): JsonResponse
    {
        $user = $request->user();
        $months = $request->integer('months', 6);

        $report = collect();
        for ($i = $months - 1; $i >= 0; $i--) {
            $date = now()->subMonths($i);

            $income = (float) Transaction::query()
                ->where('user_id', $user->id)
                ->where('type', 'income')
                ->whereMonth('transaction_date', $date->month)
                ->whereYear('transaction_date', $date->year)
                ->sum('amount');

            $expenses = (float) Transaction::query()
                ->where('user_id', $user->id)
                ->where('type', 'expense')
                ->whereMonth('transaction_date', $date->month)
                ->whereYear('transaction_date', $date->year)
                ->sum('amount');

            $savings = (float) Transaction::query()
                ->where('user_id', $user->id)
                ->where('type', 'saving')
                ->whereMonth('transaction_date', $date->month)
                ->whereYear('transaction_date', $date->year)
                ->sum('amount');

            $report->push([
                'month' => $date->month,
                'year' => $date->year,
                'label' => $date->locale(app()->getLocale())->translatedFormat('M Y'),
                'income' => $income,
                'expenses' => $expenses,
                'savings' => $savings,
                'balance' => $income - $expenses - $savings,
            ]);
        }

        return $this->successResponse([
            'months' => $report,
        ]);
    }
}
