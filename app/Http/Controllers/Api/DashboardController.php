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
use App\Models\SavingGoal;
use App\Models\Tip;
use App\Models\Transaction;
use App\Models\User;
use App\Services\BudgetService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    use ApiResponse;

    public function __construct(protected BudgetService $budgetService) {}

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $month = max(1, min(12, $request->integer('month', (int) now()->month)));
        $year = max(2000, min(2100, $request->integer('year', (int) now()->year)));

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

        $totalIncomeForBalance = $thisMonthIncome > 0 ? $thisMonthIncome : (float) ($user->monthly_income ?? 0);
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

        $quickInsights = $this->buildQuickInsights($user, $month, $year);

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

        return $this->successResponse([
            'currency' => $user->currency ?? 'SAR',
            'period' => [
                'month' => $month,
                'year' => $year,
            ],
            'has_active_budget' => $budget !== null,
            'summary' => [
                'income' => $thisMonthIncome,
                'expenses' => $thisMonthExpenses,
                'savings' => $thisMonthSavings,
                'balance' => $balance,
                'monthly_income' => (float) ($user->monthly_income ?? 0),
            ],
            'budget' => $budgetPayload,
            'last_active_budget' => $this->lastActiveBudgetEnvelope($budget, $lastActiveBudget, $user, $month, $year),
            'quick_insights' => $quickInsights,
            'savings_overview' => $savingsOverview,
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
     * @return array<string, mixed>
     */
    protected function emptyBudgetPayload(User $user, int $month, int $year): array
    {
        return [
            'exists' => false,
            'id' => 0,
            'month' => $month,
            'year' => $year,
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
    protected function buildQuickInsights(User $user, int $month, int $year): array
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

        return $byCategory
            ->map(function ($item) use ($totalExpenses) {
                return [
                    'category' => $item->category
                        ? (new CategoryResource($item->category))->resolve()
                        : CategoryResource::emptyShape(),
                    'total' => (float) $item->total,
                    'count' => (int) $item->count,
                    'percentage' => $totalExpenses > 0 ? round(($item->total / $totalExpenses) * 100, 2) : 0,
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
        $month = $request->integer('month', now()->month);
        $year = $request->integer('year', now()->year);

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
            'period' => ['month' => $month, 'year' => $year],
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
