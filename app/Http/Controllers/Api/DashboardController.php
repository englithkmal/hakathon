<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\AlertResource;
use App\Http\Resources\BudgetResource;
use App\Http\Resources\SavingGoalResource;
use App\Http\Resources\TipResource;
use App\Http\Resources\TransactionResource;
use App\Models\Alert;
use App\Models\SavingGoal;
use App\Models\Tip;
use App\Models\Transaction;
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
        $month = now()->month;
        $year = now()->year;

        $budget = $this->budgetService->getCurrentBudget($user);

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
            ->inRandomOrder()
            ->first();

        return $this->successResponse([
            'currency' => $user->currency,
            'period' => [
                'month' => $month,
                'year' => $year,
            ],
            'summary' => [
                'income' => $thisMonthIncome,
                'expenses' => $thisMonthExpenses,
                'savings' => $thisMonthSavings,
                'balance' => $balance,
                'monthly_income' => (float) ($user->monthly_income ?? 0),
            ],
            'budget' => $budget ? new BudgetResource($budget) : null,
            'recent_transactions' => TransactionResource::collection($recentTransactions),
            'active_goals' => SavingGoalResource::collection($activeGoals),
            'unread_alerts_count' => $unreadAlertsCount,
            'recent_alerts' => AlertResource::collection($recentAlerts),
            'tip_of_the_day' => $tipOfTheDay ? new TipResource($tipOfTheDay) : null,
        ]);
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
