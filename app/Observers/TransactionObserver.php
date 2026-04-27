<?php

namespace App\Observers;

use App\Models\Budget;
use App\Models\BudgetCategory;
use App\Models\Transaction;
use App\Services\AlertService;

class TransactionObserver
{
    public function __construct(protected AlertService $alertService) {}

    public function created(Transaction $transaction): void
    {
        $this->syncBudget($transaction);
    }

    public function updated(Transaction $transaction): void
    {
        $this->syncBudget($transaction);
    }

    public function deleted(Transaction $transaction): void
    {
        $this->syncBudget($transaction);
    }

    protected function syncBudget(Transaction $transaction): void
    {
        if ($transaction->type !== 'expense') {
            return;
        }

        $budget = $this->resolveBudget($transaction);

        if (! $budget) {
            return;
        }

        $totalSpent = (float) Transaction::query()
            ->where('user_id', $transaction->user_id)
            ->where('type', 'expense')
            ->whereMonth('transaction_date', $budget->month)
            ->whereYear('transaction_date', $budget->year)
            ->sum('amount');

        $budget->update(['total_spent' => $totalSpent]);

        if ($transaction->category_id) {
            $budgetCategory = BudgetCategory::query()
                ->where('budget_id', $budget->id)
                ->where('category_id', $transaction->category_id)
                ->first();

            if ($budgetCategory) {
                $categorySpent = (float) Transaction::query()
                    ->where('user_id', $transaction->user_id)
                    ->where('category_id', $transaction->category_id)
                    ->where('type', 'expense')
                    ->whereMonth('transaction_date', $budget->month)
                    ->whereYear('transaction_date', $budget->year)
                    ->sum('amount');

                $budgetCategory->update(['spent_amount' => $categorySpent]);

                $this->alertService->checkBudgetThresholds($budgetCategory->fresh());
            }
        }
    }

    protected function resolveBudget(Transaction $transaction): ?Budget
    {
        if ($transaction->budget_id) {
            return Budget::find($transaction->budget_id);
        }

        $date = $transaction->transaction_date ?? now();

        return Budget::query()
            ->where('user_id', $transaction->user_id)
            ->where('month', $date->month)
            ->where('year', $date->year)
            ->where('status', 'active')
            ->first();
    }
}
