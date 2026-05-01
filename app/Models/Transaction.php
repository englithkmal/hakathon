<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'category_id',
        'budget_id',
        'saving_goal_id',
        'monthly_summary_id',
        'amount',
        'currency',
        'type',
        'description',
        'merchant',
        'source',
        'reference',
        'transaction_date',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'transaction_date' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function budget(): BelongsTo
    {
        return $this->belongsTo(Budget::class);
    }

    public function savingGoal(): BelongsTo
    {
        return $this->belongsTo(SavingGoal::class);
    }

    /**
     * If this transaction was created as an allocation from a closed month's
     * unallocated savings, this points at the source monthly_summary.
     */
    public function monthlySummary(): BelongsTo
    {
        return $this->belongsTo(MonthlySummary::class);
    }
}
