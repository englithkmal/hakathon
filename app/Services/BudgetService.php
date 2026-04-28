<?php

namespace App\Services;

use App\Models\Budget;
use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class BudgetService
{
    public function createOrUpdateBudget(User $user, array $data): Budget
    {
        return DB::transaction(function () use ($user, $data) {
            $budget = Budget::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'month' => $data['month'] ?? now()->month,
                    'year' => $data['year'] ?? now()->year,
                ],
                [
                    'total_income' => $data['total_income'] ?? $user->monthly_income ?? 0,
                    'total_amount' => $data['total_amount'] ?? 0,
                    'currency' => $data['currency'] ?? $user->currency,
                    'status' => $data['status'] ?? 'active',
                    'notes' => $data['notes'] ?? null,
                ]
            );

            if (! empty($data['categories'])) {
                $this->syncCategories($budget, $data['categories']);
            }

            $this->recalculateSpent($budget);

            return $budget->fresh(['categories.category']);
        });
    }

    public function syncCategories(Budget $budget, array $categories): void
    {
        $totalAllocated = 0;

        foreach ($categories as $item) {
            $categoryId = $item['category_id'] ?? null;
            $allocated = (float) ($item['allocated_amount'] ?? 0);
            $threshold = (int) ($item['alert_threshold'] ?? 80);

            if (! $categoryId || ! Category::where('id', $categoryId)->exists()) {
                continue;
            }

            $budget->categories()->updateOrCreate(
                ['category_id' => $categoryId],
                [
                    'allocated_amount' => $allocated,
                    'alert_threshold' => $threshold,
                ]
            );

            $totalAllocated += $allocated;
        }

        $providedIds = collect($categories)->pluck('category_id')->filter()->all();
        if (! empty($providedIds)) {
            $budget->categories()
                ->whereNotIn('category_id', $providedIds)
                ->delete();
        }

        if ((float) $budget->total_amount === 0.0 && $totalAllocated > 0) {
            $budget->update(['total_amount' => $totalAllocated]);
        }
    }

    public function recalculateSpent(Budget $budget): void
    {
        $totalSpent = (float) Transaction::query()
            ->where('user_id', $budget->user_id)
            ->where('type', 'expense')
            ->whereMonth('transaction_date', $budget->month)
            ->whereYear('transaction_date', $budget->year)
            ->sum('amount');

        $budget->update(['total_spent' => $totalSpent]);

        foreach ($budget->categories as $budgetCategory) {
            $categorySpent = (float) Transaction::query()
                ->where('user_id', $budget->user_id)
                ->where('category_id', $budgetCategory->category_id)
                ->where('type', 'expense')
                ->whereMonth('transaction_date', $budget->month)
                ->whereYear('transaction_date', $budget->year)
                ->sum('amount');

            $budgetCategory->update(['spent_amount' => $categorySpent]);
        }
    }

    /**
     * ميزانية المستخدم لشهر/سنة محددين (افتراضي: الشهر الحالي في توقيت التطبيق).
     * يُستخدم في الـ API وفي /budgets/current — حالة **active** فقط (مثل منطق العرض الموحّد).
     */
    public function getCurrentBudget(User $user, ?int $month = null, ?int $year = null): ?Budget
    {
        $month ??= (int) now()->month;
        $year ??= (int) now()->year;

        return Budget::query()
            ->with(['categories.category'])
            ->where('user_id', $user->id)
            ->where('month', $month)
            ->where('year', $year)
            ->where('status', 'active')
            ->first();
    }
}
