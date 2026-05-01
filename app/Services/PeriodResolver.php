<?php

namespace App\Services;

use App\Models\Budget;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\Request;

/**
 * Single source of truth for the "active period" used across the app
 * (Dashboard, Budgets, Insights). Centralizes resolution so screens
 * never disagree about which month/year to show.
 *
 * Resolution order (first match wins):
 *  1. Explicit `month` + `year` in input  → source: explicit
 *  2. Explicit `period_start` (ISO date)  → source: explicit
 *  3. User's latest `active` budget       → source: latest_budget
 *  4. Server calendar (now)               → source: calendar
 */
class PeriodResolver
{
    /**
     * @param  Request|array<string, mixed>  $input
     */
    public function resolve(User $user, Request|array $input = []): ResolvedPeriod
    {
        $payload = $input instanceof Request ? $input->all() : $input;

        $explicitMonth = $this->intOrNull($payload['month'] ?? null);
        $explicitYear = $this->intOrNull($payload['year'] ?? null);

        if ($explicitMonth !== null && $explicitYear !== null) {
            return $this->makePeriod(
                month: $this->clampMonth($explicitMonth),
                year: $this->clampYear($explicitYear),
                source: ResolvedPeriod::SOURCE_EXPLICIT,
            );
        }

        $periodStart = $payload['period_start'] ?? null;
        if (is_string($periodStart) && $periodStart !== '') {
            try {
                $parsed = Carbon::parse($periodStart, config('app.timezone'));

                return $this->makePeriod(
                    month: (int) $parsed->month,
                    year: (int) $parsed->year,
                    source: ResolvedPeriod::SOURCE_EXPLICIT,
                );
            } catch (\Throwable) {
                // ignore — fall through
            }
        }

        $latest = $this->latestActiveBudget($user);
        if ($latest !== null) {
            return $this->makePeriod(
                month: (int) $latest->month,
                year: (int) $latest->year,
                source: ResolvedPeriod::SOURCE_LATEST_BUDGET,
                budgetId: (int) $latest->id,
            );
        }

        $now = Carbon::now(config('app.timezone'));

        return $this->makePeriod(
            month: (int) $now->month,
            year: (int) $now->year,
            source: ResolvedPeriod::SOURCE_CALENDAR,
        );
    }

    protected function latestActiveBudget(User $user): ?Budget
    {
        return Budget::query()
            ->where('user_id', $user->id)
            ->where('status', 'active')
            ->orderByDesc('year')
            ->orderByDesc('month')
            ->first();
    }

    protected function intOrNull(mixed $value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (is_numeric($value)) {
            return (int) $value;
        }

        return null;
    }

    protected function clampMonth(int $month): int
    {
        return max(1, min(12, $month));
    }

    protected function clampYear(int $year): int
    {
        return max(2000, min(2100, $year));
    }

    protected function makePeriod(int $month, int $year, string $source, ?int $budgetId = null): ResolvedPeriod
    {
        $start = Carbon::createFromDate($year, $month, 1)->startOfDay();
        $end = (clone $start)->endOfMonth();

        return new ResolvedPeriod(
            month: $month,
            year: $year,
            periodStart: $start->toDateString(),
            periodEnd: $end->toDateString(),
            source: $source,
            budgetId: $budgetId,
        );
    }
}
