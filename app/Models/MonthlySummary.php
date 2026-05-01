<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Immutable per-user end-of-month snapshot. Reads source: transactions at the
 * moment `waffer:close-month` runs. After creation the row is treated as a
 * historical fact — admins can `recompute` (overwrites) but normal API/UI never
 * mutates it. See BR-06.
 *
 * @property int $id
 * @property int $user_id
 * @property int $month
 * @property int $year
 * @property \Carbon\Carbon $period_start
 * @property \Carbon\Carbon $period_end
 * @property float $total_income
 * @property float $total_expenses
 * @property float $total_goal_deposits
 * @property float $unallocated_savings
 * @property int $transaction_count
 * @property int|null $budget_id
 * @property float|null $budget_total_amount
 * @property float|null $budget_total_spent
 * @property float|null $budget_adherence_pct
 * @property array|null $top_categories
 * @property string $allocation_status
 * @property float $allocated_amount
 * @property \Carbon\Carbon $closed_at
 * @property string $closed_by
 * @property string|null $notes
 */
class MonthlySummary extends Model
{
    use HasFactory;

    public const ALLOCATION_UNALLOCATED = 'unallocated';

    public const ALLOCATION_PARTIAL = 'partially_allocated';

    public const ALLOCATION_FULL = 'fully_allocated';

    public const CLOSED_BY_CRON = 'cron';

    public const CLOSED_BY_MANUAL = 'manual';

    protected $fillable = [
        'user_id',
        'month',
        'year',
        'period_start',
        'period_end',
        'total_income',
        'total_expenses',
        'total_goal_deposits',
        'unallocated_savings',
        'transaction_count',
        'budget_id',
        'budget_total_amount',
        'budget_total_spent',
        'budget_adherence_pct',
        'top_categories',
        'allocation_status',
        'allocated_amount',
        'closed_at',
        'closed_by',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'month' => 'integer',
            'year' => 'integer',
            'period_start' => 'date',
            'period_end' => 'date',
            'total_income' => 'decimal:2',
            'total_expenses' => 'decimal:2',
            'total_goal_deposits' => 'decimal:2',
            'unallocated_savings' => 'decimal:2',
            'transaction_count' => 'integer',
            'budget_total_amount' => 'decimal:2',
            'budget_total_spent' => 'decimal:2',
            'budget_adherence_pct' => 'decimal:2',
            'top_categories' => 'array',
            'allocated_amount' => 'decimal:2',
            'closed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function budget(): BelongsTo
    {
        return $this->belongsTo(Budget::class);
    }

    /**
     * All allocation transactions tied to this summary (i.e. money moved from
     * "وفر الشهر" into a saving goal). Set once `transactions.monthly_summary_id`
     * is added in the next step.
     */
    public function allocationTransactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    /**
     * Convenience: how much of the unallocated saving is still untouched.
     */
    public function getUnallocatedRemainingAttribute(): float
    {
        return max(0, (float) $this->unallocated_savings - (float) $this->allocated_amount);
    }

    /**
     * Recomputes `allocated_amount` and `allocation_status` from the underlying
     * allocation transactions. Cheap (single SUM) — called by TransactionObserver
     * whenever an allocation transaction is created/updated/deleted.
     *
     * Uses saveQuietly so it can run inside other observer chains without
     * triggering its own recursion.
     */
    public function recomputeAllocations(): void
    {
        $allocated = (float) Transaction::query()
            ->where('monthly_summary_id', $this->id)
            ->where('type', 'saving')
            ->sum('amount');

        $unallocated = (float) $this->unallocated_savings;
        $status = match (true) {
            $allocated <= 0 => self::ALLOCATION_UNALLOCATED,
            $allocated + 0.001 < $unallocated => self::ALLOCATION_PARTIAL,
            default => self::ALLOCATION_FULL,
        };

        $this->forceFill([
            'allocated_amount' => round($allocated, 2),
            'allocation_status' => $status,
        ])->saveQuietly();
    }
}
