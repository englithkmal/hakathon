<?php

namespace App\Observers;

use App\Models\Budget;
use App\Services\BudgetLinker;

/**
 * Whenever a budget appears, disappears, or moves to another month, the
 * dependent transactions' `budget_id` cache must be re-synced. We keep it
 * here so the rule can't be skipped by a controller path.
 */
class BudgetObserver
{
    public function __construct(protected BudgetLinker $linker) {}

    public function created(Budget $budget): void
    {
        // Catch transactions logged before the budget existed for this month.
        $this->linker->linkTransactionsForBudget($budget);
        $this->linker->recalculateBudget($budget);
    }

    public function updated(Budget $budget): void
    {
        // Only re-link when the period or the activation status actually changed.
        // total_spent changes (caused by recalculate itself) must NOT trigger another pass.
        $movedPeriod = $budget->wasChanged(['month', 'year']);
        $statusChanged = $budget->wasChanged('status');

        if (! $movedPeriod && ! $statusChanged) {
            return;
        }

        if ($movedPeriod) {
            $oldUserId = (int) $budget->getOriginal('user_id', $budget->user_id);
            $oldMonth = (int) $budget->getOriginal('month', $budget->month);
            $oldYear = (int) $budget->getOriginal('year', $budget->year);

            $this->linker->unlinkTransactionsForBudget($budget);
            $this->linker->linkTransactionsForBudget($budget);

            // Recompute the previous month's other active budget too (if any).
            $oldBudget = $this->linker->findActiveBudget($oldUserId, $oldMonth, $oldYear);
            $this->linker->recalculateBudget($oldBudget);
        }

        if ($statusChanged) {
            $newStatus = $budget->status;
            if ($newStatus !== 'active') {
                // Closed/draft budgets stop owning new transactions, but existing links
                // are kept so historical reports still show the relationship.
                // No-op here intentionally — kept for documentation.
            } else {
                $this->linker->linkTransactionsForBudget($budget);
            }
        }

        $this->linker->recalculateBudget($budget);
    }

    public function deleting(Budget $budget): void
    {
        // Sever the helper link explicitly before the FK cascade runs, so any
        // application code reading the transaction during the same request
        // won't see a dangling FK value.
        $this->linker->unlinkTransactionsForBudget($budget);
    }
}
