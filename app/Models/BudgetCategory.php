<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class BudgetCategory extends Model
{
    use HasFactory;

    protected $fillable = [
        'budget_id',
        'category_id',
        'allocated_amount',
        'spent_amount',
        'alert_threshold',
    ];

    protected function casts(): array
    {
        return [
            'allocated_amount' => 'decimal:2',
            'spent_amount' => 'decimal:2',
            'alert_threshold' => 'integer',
        ];
    }

    public function budget(): BelongsTo
    {
        return $this->belongsTo(Budget::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function alerts(): HasMany
    {
        return $this->hasMany(Alert::class);
    }

    public function getRemainingAttribute(): float
    {
        return max(0, (float) $this->allocated_amount - (float) $this->spent_amount);
    }

    public function getUsagePercentageAttribute(): float
    {
        if ((float) $this->allocated_amount <= 0) {
            return 0;
        }

        return round(((float) $this->spent_amount / (float) $this->allocated_amount) * 100, 2);
    }
}
