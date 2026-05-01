<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SavingGoal extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'title',
        'description',
        'icon',
        'color',
        'target_amount',
        'current_amount',
        'currency',
        'start_date',
        'deadline',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'target_amount' => 'decimal:2',
            'current_amount' => 'decimal:2',
            'start_date' => 'date',
            'deadline' => 'date',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function alerts(): HasMany
    {
        return $this->hasMany(Alert::class);
    }

    /**
     * All transactions that count as deposits toward this goal.
     * Source of truth — `current_amount` is just a denormalized SUM of these.
     */
    public function deposits(): HasMany
    {
        return $this->hasMany(Transaction::class)->where('type', 'saving');
    }

    public function getProgressPercentageAttribute(): float
    {
        if ((float) $this->target_amount <= 0) {
            return 0;
        }

        return min(100, round(((float) $this->current_amount / (float) $this->target_amount) * 100, 2));
    }

    public function getRemainingAttribute(): float
    {
        return max(0, (float) $this->target_amount - (float) $this->current_amount);
    }

    /**
     * The amount the user "should" have saved by today, under the
     * "each month is its own slice" model (BR-02). The plan is split into
     * `monthly_target × N months`; today's expectation is:
     *
     *     monthly_target × (full_elapsed_months + day_of_month / days_in_month)
     *
     * That keeps the per-day pace inside one month feeling right (e.g. 250 SAR
     * a month → ~8 SAR by day 1) instead of the old "spread linearly over all
     * 60 days" formula which understated early-month progress.
     */
    public function getExpectedAtTodayAttribute(): ?float
    {
        $start = $this->resolveDate($this->start_date);
        $end = $this->resolveDate($this->deadline);
        if ($start === null || $end === null) {
            return null;
        }

        if ((float) $this->target_amount <= 0) {
            return 0.0;
        }

        $today = Carbon::now($start->getTimezone());
        if ($today->lessThanOrEqualTo($start)) {
            return 0.0;
        }
        if ($today->greaterThanOrEqualTo($end)) {
            return (float) $this->target_amount;
        }

        $monthsTotal = max(1, $start->copy()->startOfMonth()->diffInMonths($end->copy()->startOfMonth()) + 1);
        $monthlyTarget = (float) $this->target_amount / $monthsTotal;

        $elapsedFullMonths = max(0, $start->copy()->startOfMonth()->diffInMonths($today->copy()->startOfMonth()));
        $elapsedFullMonths = min($elapsedFullMonths, $monthsTotal - 1);

        $daysInMonth = max(1, $today->daysInMonth);
        $partial = min(1.0, $today->day / $daysInMonth);

        return round($monthlyTarget * ($elapsedFullMonths + $partial), 2);
    }

    /**
     * Linear monthly contribution required to hit `target_amount` by `deadline`.
     * Used as the "expected per month" baseline in monthly-progress UIs.
     */
    public function getMonthlyTargetAttribute(): ?float
    {
        $start = $this->resolveDate($this->start_date);
        $end = $this->resolveDate($this->deadline);
        if ($start === null || $end === null) {
            return null;
        }

        $months = max(1, $start->copy()->startOfMonth()->diffInMonths($end->copy()->startOfMonth()) + 1);

        return round((float) $this->target_amount / $months, 2);
    }

    /**
     * Signed difference between actual saved and the linear plan up to today.
     * Positive = ahead, negative = behind. Null when plan is incomplete.
     */
    public function getPaceDeltaAttribute(): ?float
    {
        $expected = $this->expected_at_today;
        if ($expected === null) {
            return null;
        }

        return round((float) $this->current_amount - $expected, 2);
    }

    /**
     * Coarse classification of the goal's pace. The 10% band exists so a goal
     * that's "barely behind" doesn't show as off_track and spam alerts.
     *
     *   ahead         : current ≥ expected
     *   on_track      : within −10% of expected
     *   off_track     : more than 10% behind expected
     *   inactive      : status not "active" (paused / cancelled / achieved)
     *   unscheduled   : plan dates missing
     */
    public function getPaceStatusAttribute(): string
    {
        if ($this->status !== 'active') {
            return 'inactive';
        }

        $expected = $this->expected_at_today;
        if ($expected === null) {
            return 'unscheduled';
        }

        if ($expected <= 0) {
            return 'on_track';
        }

        $current = (float) $this->current_amount;
        if ($current >= $expected) {
            return 'ahead';
        }

        $tolerance = $expected * 0.10;
        if ($current >= $expected - $tolerance) {
            return 'on_track';
        }

        return 'off_track';
    }

    protected function resolveDate(mixed $value): ?Carbon
    {
        if ($value === null) {
            return null;
        }
        if ($value instanceof Carbon) {
            return $value->copy()->startOfDay();
        }
        try {
            return Carbon::parse((string) $value)->startOfDay();
        } catch (\Throwable) {
            return null;
        }
    }
}
