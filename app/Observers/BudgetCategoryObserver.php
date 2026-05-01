<?php

namespace App\Observers;

use App\Models\BudgetCategory;
use App\Services\BudgetLinker;

/**
 * Adding/removing a category line on a budget changes which slice of the
 * spending shows up under that category, but it never moves the underlying
 * transactions — they stay linked to the budget by date.
 */
class BudgetCategoryObserver
{
    public function __construct(protected BudgetLinker $linker) {}

    public function created(BudgetCategory $bc): void
    {
        $this->linker->recalculateBudgetCategory($bc, runAlerts: true);
    }

    public function updated(BudgetCategory $bc): void
    {
        if ($bc->wasChanged('category_id')) {
            // Old category line no longer exists on this BC, but the previous
            // category's spent_amount on this budget needs reset → easiest is
            // a full budget recalculation.
            $bc->loadMissing('budget');
            $this->linker->recalculateBudget($bc->budget);

            return;
        }

        if ($bc->wasChanged(['allocated_amount', 'alert_threshold'])) {
            $this->linker->recalculateBudgetCategory($bc, runAlerts: true);
        }
    }

    public function deleted(BudgetCategory $bc): void
    {
        // Transactions remain tied to the budget by month; only the category
        // breakdown for this budget changes (the line is gone, not the spend).
        $bc->loadMissing('budget');
        $this->linker->recalculateBudget($bc->budget);
    }
}
