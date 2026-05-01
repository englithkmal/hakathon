<?php

namespace App\Observers;

use App\Models\MonthlySummary;
use App\Models\Transaction;
use App\Services\BudgetLinker;
use App\Services\SavingGoalLinker;
use Carbon\Carbon;

/**
 * Keeps `transactions.budget_id` in sync as a derived helper. The observer
 * never tries to *decide* what is true — that lives in BudgetLinker, which
 * reads from (user, type, transaction_date) every time.
 *
 * Same pattern for saving deposits: SavingGoalLinker recomputes
 * `saving_goals.current_amount` from the underlying transactions.
 */
class TransactionObserver
{
    public function __construct(
        protected BudgetLinker $linker,
        protected SavingGoalLinker $goalLinker,
    ) {}

    public function creating(Transaction $transaction): void
    {
        $this->linker->attachBudgetIdInPlace($transaction);
    }

    public function created(Transaction $transaction): void
    {
        $this->linker->resyncForChange($transaction, $this->blankKey());

        if ($transaction->type === 'saving') {
            $this->goalLinker->resyncForChange(null, $transaction->saving_goal_id);
        }

        $this->resyncMonthlySummary(null, $transaction->monthly_summary_id);
    }

    public function updating(Transaction $transaction): void
    {
        if ($this->isCriticalChange($transaction)) {
            $this->linker->attachBudgetIdInPlace($transaction);
        }
    }

    public function updated(Transaction $transaction): void
    {
        if (! $this->isCriticalChange($transaction)) {
            // Description/merchant/amount-only edits still affect aggregates.
            $this->linker->resyncForChange($transaction, $this->blankKey());
            $this->maybeResyncGoals($transaction);
            $this->maybeResyncMonthlySummary($transaction);

            return;
        }

        $this->linker->resyncForChange($transaction, $this->oldKey($transaction));
        $this->maybeResyncGoals($transaction);
        $this->maybeResyncMonthlySummary($transaction);
    }

    public function deleted(Transaction $transaction): void
    {
        // After delete, the new budget is irrelevant — only the previous one needs a recount.
        $oldKey = $this->oldKey($transaction, useOriginalDate: false);

        if ($oldKey['user_id'] && $oldKey['month'] && $oldKey['year']) {
            $oldBudget = $this->linker->findActiveBudget(
                (int) $oldKey['user_id'],
                (int) $oldKey['month'],
                (int) $oldKey['year']
            );
            $this->linker->recalculateBudget($oldBudget);
        }

        $oldGoalId = $transaction->getOriginal('saving_goal_id') ?? $transaction->saving_goal_id;
        $oldType = $transaction->getOriginal('type') ?? $transaction->type;
        if ($oldType === 'saving' && $oldGoalId) {
            $this->goalLinker->resyncForChange((int) $oldGoalId, null);
        }

        $oldSummary = $transaction->getOriginal('monthly_summary_id') ?? $transaction->monthly_summary_id;
        $this->resyncMonthlySummary($oldSummary !== null ? (int) $oldSummary : null, null);
    }

    protected function maybeResyncMonthlySummary(Transaction $transaction): void
    {
        $newId = $transaction->monthly_summary_id;
        $oldId = $transaction->getOriginal('monthly_summary_id') ?? $newId;

        if ($oldId === null && $newId === null) {
            return;
        }

        $this->resyncMonthlySummary(
            $oldId !== null ? (int) $oldId : null,
            $newId !== null ? (int) $newId : null,
        );
    }

    protected function resyncMonthlySummary(?int $oldId, ?int $newId): void
    {
        if ($oldId !== null && $oldId !== $newId) {
            MonthlySummary::find($oldId)?->recomputeAllocations();
        }

        if ($newId !== null) {
            MonthlySummary::find($newId)?->recomputeAllocations();
        }
    }

    protected function maybeResyncGoals(Transaction $transaction): void
    {
        $newType = $transaction->type;
        $oldType = $transaction->getOriginal('type') ?? $newType;
        $newGoal = $transaction->saving_goal_id;
        $oldGoal = $transaction->getOriginal('saving_goal_id') ?? $newGoal;

        $oldRelevant = $oldType === 'saving' ? $oldGoal : null;
        $newRelevant = $newType === 'saving' ? $newGoal : null;

        if ($oldRelevant === null && $newRelevant === null) {
            return;
        }

        $this->goalLinker->resyncForChange(
            $oldRelevant !== null ? (int) $oldRelevant : null,
            $newRelevant !== null ? (int) $newRelevant : null,
        );
    }

    protected function isCriticalChange(Transaction $transaction): bool
    {
        return $transaction->isDirty(['user_id', 'type', 'category_id', 'transaction_date', 'amount', 'saving_goal_id', 'monthly_summary_id']);
    }

    /**
     * @return array{user_id:?int, month:?int, year:?int}
     */
    protected function oldKey(Transaction $transaction, bool $useOriginalDate = true): array
    {
        $userId = (int) ($transaction->getOriginal('user_id') ?? $transaction->user_id);
        $rawDate = $useOriginalDate
            ? ($transaction->getOriginal('transaction_date') ?? $transaction->transaction_date)
            : $transaction->transaction_date;

        $date = $this->parseDate($rawDate);
        if ($date === null) {
            return $this->blankKey();
        }

        return [
            'user_id' => $userId,
            'month' => (int) $date->month,
            'year' => (int) $date->year,
        ];
    }

    /**
     * @return array{user_id:null, month:null, year:null}
     */
    protected function blankKey(): array
    {
        return ['user_id' => null, 'month' => null, 'year' => null];
    }

    protected function parseDate(mixed $value): ?Carbon
    {
        if ($value instanceof Carbon) {
            return $value;
        }
        if (is_string($value) && $value !== '') {
            try {
                return Carbon::parse($value);
            } catch (\Throwable) {
                return null;
            }
        }

        return null;
    }
}
