<?php

namespace App\Services;

/**
 * Immutable DTO describing the period the API operates on for a request.
 *
 * @see PeriodResolver
 */
class ResolvedPeriod
{
    public const SOURCE_EXPLICIT = 'explicit';

    public const SOURCE_LATEST_BUDGET = 'latest_budget';

    public const SOURCE_CALENDAR = 'calendar';

    public function __construct(
        public readonly int $month,
        public readonly int $year,
        public readonly string $periodStart,
        public readonly string $periodEnd,
        public readonly string $source,
        public readonly ?int $budgetId = null,
    ) {}

    /**
     * Shape returned to clients under `meta.period` (and inside `data.period`
     * for backwards compat in the Dashboard response).
     *
     * @return array{month:int, year:int, period_start:string, period_end:string, source:string, budget_id:int|null}
     */
    public function toArray(): array
    {
        return [
            'month' => $this->month,
            'year' => $this->year,
            'period_start' => $this->periodStart,
            'period_end' => $this->periodEnd,
            'source' => $this->source,
            'budget_id' => $this->budgetId,
        ];
    }
}
