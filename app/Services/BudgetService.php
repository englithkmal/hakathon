<?php

namespace App\Services;

use App\Models\Budget;
use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class BudgetService
{
    public function createOrUpdateBudget(User $user, array $data): Budget
    {
        return DB::transaction(function () use ($user, $data) {
            $month = (int) ($data['month'] ?? now()->month);
            $year = (int) ($data['year'] ?? now()->year);

            if (! empty($data['period_start'])) {
                $parsed = Carbon::parse($data['period_start'], config('app.timezone'));
                $month = (int) $parsed->month;
                $year = (int) $parsed->year;
            }

            unset($data['period_start']);

            // BR-09: budget total cannot exceed MAX(actual month income, baseline monthly_income).
            // Categories sum is folded in so a user that posts only categories (no total_amount)
            // is still validated against the real allocation.
            $categories = $data['categories'] ?? [];
            $derivedTotal = $this->deriveTotalAmount($data['total_amount'] ?? null, $categories);

            $this->assertBudgetWithinIncome($user, $month, $year, $derivedTotal);

            $budget = Budget::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'month' => $month,
                    'year' => $year,
                ],
                [
                    'total_income' => $data['total_income'] ?? $user->monthly_income ?? 0,
                    'total_amount' => $derivedTotal,
                    'currency' => $data['currency'] ?? $user->currency,
                    'status' => $data['status'] ?? 'active',
                    'notes' => $data['notes'] ?? null,
                ]
            );

            if (! empty($categories)) {
                $this->syncCategories($budget, $categories);
            }

            $this->recalculateSpent($budget);

            return $budget->fresh(['categories.category']);
        });
    }

    /**
     * Picks the effective `total_amount` for a budget. Rules:
     *  - If categories are provided, their sum is the floor (so allocations never exceed total).
     *  - Explicit total_amount wins when present and ≥ categories sum.
     *  - Falls back to categories sum (or 0) when total_amount is missing/zero.
     */
    protected function deriveTotalAmount(mixed $explicit, array $categories): float
    {
        $explicitTotal = $explicit !== null ? (float) $explicit : 0.0;

        $catsTotal = 0.0;
        foreach ($categories as $c) {
            $catsTotal += (float) ($c['allocated_amount'] ?? 0);
        }

        if ($explicitTotal <= 0) {
            return round($catsTotal, 2);
        }

        return round(max($explicitTotal, $catsTotal), 2);
    }

    /**
     * BR-09: a monthly budget cannot plan to spend more than the user can actually
     * count on. We compare against MAX(month_income, baseline monthly_income) so
     * brand-new months (no income recorded yet) still respect the user's stated salary,
     * while users who under-stated their salary aren't blocked from a higher actual month.
     *
     * If both signals are 0 (a fresh account that has not logged any income at all),
     * we let the budget through — there's nothing to compare against and blocking
     * would create a chicken-and-egg lock.
     *
     * @throws ValidationException
     */
    protected function assertBudgetWithinIncome(User $user, int $month, int $year, float $totalAmount): void
    {
        if ($totalAmount <= 0) {
            return;
        }

        $monthIncome = (float) Transaction::query()
            ->where('user_id', $user->id)
            ->where('type', 'income')
            ->whereMonth('transaction_date', $month)
            ->whereYear('transaction_date', $year)
            ->sum('amount');

        $baseline = (float) ($user->monthly_income ?? 0);
        $effective = max($monthIncome, $baseline);

        if ($effective <= 0) {
            return;
        }

        if ($totalAmount > $effective + 0.001) {
            $overage = round($totalAmount - $effective, 2);
            throw ValidationException::withMessages([
                'total_amount' => sprintf(
                    'مجموع الميزانية (%s) يتجاوز الدخل المتاح لهذا الشهر (%s). الفائض %s. خفّض الفئات أو زِد الدخل المسجّل.',
                    number_format($totalAmount, 2),
                    number_format($effective, 2),
                    number_format($overage, 2),
                ),
            ]);
        }
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

    /**
     * أحدث ميزانية نشطة (أي شهر) — للعرض عندما لا توجد ميزانية لشهر التقويم الحالي.
     */
    public function getLatestActiveBudget(User $user): ?Budget
    {
        return Budget::query()
            ->with(['categories.category'])
            ->where('user_id', $user->id)
            ->where('status', 'active')
            ->orderByDesc('year')
            ->orderByDesc('month')
            ->first();
    }
}
