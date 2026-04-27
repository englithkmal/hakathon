<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Budget extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'month',
        'year',
        'total_income',
        'total_amount',
        'total_spent',
        'currency',
        'status',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'month' => 'integer',
            'year' => 'integer',
            'total_income' => 'decimal:2',
            'total_amount' => 'decimal:2',
            'total_spent' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function categories(): HasMany
    {
        return $this->hasMany(BudgetCategory::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    public function getRemainingAttribute(): float
    {
        return max(0, (float) $this->total_amount - (float) $this->total_spent);
    }

    public function getProgressPercentageAttribute(): float
    {
        if ((float) $this->total_amount <= 0) {
            return 0;
        }

        return round(((float) $this->total_spent / (float) $this->total_amount) * 100, 2);
    }
}
