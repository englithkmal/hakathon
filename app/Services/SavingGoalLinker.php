<?php

namespace App\Services;

use App\Models\SavingGoal;
use App\Models\Transaction;

/**
 * Single source of authority for `saving_goals.current_amount`. The column is
 * a denormalized SUM of (transactions WHERE type=saving AND saving_goal_id=X);
 * this service is the only place that recomputes it. Same pattern as
 * BudgetLinker for `total_spent`.
 *
 * Used by:
 *  - TransactionObserver (when type=saving and a goal is involved)
 *  - SavingGoalController::deposit (which now creates a transaction)
 *  - `saving-goals:resync` artisan command
 */
class SavingGoalLinker
{
    /**
     * Recomputes `current_amount` for one goal from its deposit transactions.
     * Uses saveQuietly to avoid kicking off an unrelated observer cycle.
     */
    public function recompute(?SavingGoal $goal): void
    {
        if ($goal === null) {
            return;
        }

        $sum = (float) Transaction::query()
            ->where('saving_goal_id', $goal->id)
            ->where('type', 'saving')
            ->sum('amount');

        $goal->forceFill(['current_amount' => $sum])->saveQuietly();

        $this->autoMarkAchieved($goal);
    }

    /**
     * Recomputes both the previous goal (if the deposit moved between goals)
     * and the new one. Mirrors BudgetLinker::resyncForChange's two-period idea.
     */
    public function resyncForChange(?int $oldGoalId, ?int $newGoalId): void
    {
        if ($oldGoalId !== null && $oldGoalId !== $newGoalId) {
            $this->recompute(SavingGoal::find($oldGoalId));
        }

        if ($newGoalId !== null) {
            $this->recompute(SavingGoal::find($newGoalId));
        }
    }

    /**
     * Bumps an `active` goal to `achieved` once it crosses its target. We never
     * downgrade automatically — a manual edit (e.g. raising the target) is a
     * deliberate action by the user and the API surface handles status there.
     */
    protected function autoMarkAchieved(SavingGoal $goal): void
    {
        $goal->refresh();

        if ($goal->status !== 'active') {
            return;
        }

        if ((float) $goal->target_amount <= 0) {
            return;
        }

        if ((float) $goal->current_amount >= (float) $goal->target_amount) {
            $goal->forceFill(['status' => 'achieved'])->saveQuietly();
        }
    }
}
