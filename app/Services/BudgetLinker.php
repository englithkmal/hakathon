<?php

namespace App\Services;

use App\Models\Budget;
use App\Models\BudgetCategory;
use App\Models\Transaction;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Centralizes the contract that `transactions.budget_id` is a **derived helper**
 * (denormalization), never the source of truth. Source of truth is the triple
 * (user_id, type=expense, transaction_date month/year) ↔ budgets.month/year of an
 * `active` budget. This service is the single place that mutates the link and
 * recalculates aggregates so observers stay thin and behavior stays consistent.
 *
 * Used by:
 *  - TransactionObserver (creating/updating/updated/deleted)
 *  - BudgetObserver       (created/updated/deleting)
 *  - BudgetCategoryObserver (created/updated/deleted)
 *  - `transactions:relink` artisan command (one-shot data backfill)
 */
class BudgetLinker
{
    /**
     * Sets `budget_id` on a transaction based on its date+user, **without saving**.
     * Called from `creating` and `updating` so the value is written in the same SQL
     * statement as the user's own change (no double write).
     */
    public function attachBudgetIdInPlace(Transaction $transaction): void
    {
        if ($transaction->type !== 'expense') {
            $transaction->budget_id = null;

            return;
        }

        $date = $this->date($transaction);
        if ($date === null) {
            $transaction->budget_id = null;

            return;
        }

        $budget = $this->findActiveBudget((int) $transaction->user_id, (int) $date->month, (int) $date->year);
        $transaction->budget_id = $budget?->id;
    }

    /**
     * Recomputes `total_spent` on the budget AND `spent_amount` on each of its
     * `budget_categories` from the source of truth (transactions in that month).
     * Also runs alert thresholds for affected categories.
     */
    public function recalculateBudget(?Budget $budget): void
    {
        if ($budget === null) {
            return;
        }

        $totalSpent = (float) Transaction::query()
            ->where('user_id', $budget->user_id)
            ->where('type', 'expense')
            ->whereMonth('transaction_date', $budget->month)
            ->whereYear('transaction_date', $budget->year)
            ->sum('amount');

        $budget->forceFill(['total_spent' => $totalSpent])->saveQuietly();

        $categories = $budget->categories()->get();
        foreach ($categories as $bc) {
            $this->recalculateBudgetCategory($bc, runAlerts: true);
        }
    }

    /**
     * Recomputes `spent_amount` for one budget_category and (optionally) runs
     * alert thresholds. Kept separate so single-category mutations don't pay
     * for a full budget rescan.
     */
    public function recalculateBudgetCategory(BudgetCategory $bc, bool $runAlerts = false): void
    {
        $bc->loadMissing('budget');
        $budget = $bc->budget;
        if ($budget === null) {
            return;
        }

        $spent = (float) Transaction::query()
            ->where('user_id', $budget->user_id)
            ->where('category_id', $bc->category_id)
            ->where('type', 'expense')
            ->whereMonth('transaction_date', $budget->month)
            ->whereYear('transaction_date', $budget->year)
            ->sum('amount');

        $bc->forceFill(['spent_amount' => $spent])->saveQuietly();

        if ($runAlerts) {
            // Resolved lazily to avoid a hard ctor dep that would break command-line tools.
            app(AlertService::class)->checkBudgetThresholds($bc->fresh());
        }
    }

    /**
     * Finds the budget for a (user, month, year) tuple — used at every link point.
     * Honors `status = active` so closed budgets don't capture new transactions.
     */
    public function findActiveBudget(int $userId, int $month, int $year): ?Budget
    {
        return Budget::query()
            ->where('user_id', $userId)
            ->where('month', $month)
            ->where('year', $year)
            ->where('status', 'active')
            ->first();
    }

    /**
     * Bulk-links every existing expense transaction in a budget's calendar month
     * to that budget. Returns the number of rows touched. Called when a budget is
     * created (so transactions logged before the budget existed are picked up).
     */
    public function linkTransactionsForBudget(Budget $budget): int
    {
        $start = Carbon::createFromDate($budget->year, $budget->month, 1)->startOfDay();
        $end = (clone $start)->endOfMonth()->endOfDay();

        return Transaction::query()
            ->where('user_id', $budget->user_id)
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->update(['budget_id' => $budget->id]);
    }

    /**
     * Sets `budget_id = NULL` for every transaction currently pointing at this
     * budget. Used on budget delete — keeps transactions intact (only the
     * helper link is severed); the FK ON DELETE SET NULL guarantees the same on
     * the DB side, this just keeps row-level consistency before the delete.
     */
    public function unlinkTransactionsForBudget(Budget $budget): int
    {
        return Transaction::query()
            ->where('budget_id', $budget->id)
            ->update(['budget_id' => null]);
    }

    /**
     * Re-syncs a transaction across an old period and a new period when a
     * critical field (date / category / user / type) was changed. Wraps the two
     * recalculations in a single DB transaction to avoid partial state visible
     * to other readers.
     *
     * @param  array{user_id:?int, month:?int, year:?int}  $oldKey
     */
    public function resyncForChange(Transaction $transaction, array $oldKey): void
    {
        DB::transaction(function () use ($transaction, $oldKey) {
            // Old period
            if ($oldKey['user_id'] && $oldKey['month'] && $oldKey['year']) {
                $oldBudget = $this->findActiveBudget(
                    (int) $oldKey['user_id'],
                    (int) $oldKey['month'],
                    (int) $oldKey['year']
                );
                $this->recalculateBudget($oldBudget);
            }

            // New period (uses the just-saved transaction)
            $newBudget = $transaction->budget_id
                ? Budget::find($transaction->budget_id)
                : null;
            $this->recalculateBudget($newBudget);
        });
    }

    protected function date(Transaction $transaction): ?Carbon
    {
        $date = $transaction->transaction_date;
        if ($date instanceof Carbon) {
            return $date;
        }
        if (is_string($date) && $date !== '') {
            try {
                return Carbon::parse($date);
            } catch (\Throwable) {
                return null;
            }
        }

        return null;
    }
}
