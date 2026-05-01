<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Read-only projection of a closed month. The shape mirrors what the mobile
 * "Past Months" / "End-of-month Report" screen needs in a single hop.
 */
class MonthlySummaryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $unallocatedRemaining = max(0, (float) $this->unallocated_savings - (float) $this->allocated_amount);

        return [
            'id' => $this->id,
            'year' => (int) $this->year,
            'month' => (int) $this->month,
            'period_start' => $this->period_start?->toDateString() ?? '',
            'period_end' => $this->period_end?->toDateString() ?? '',

            'cash_flow' => [
                'income' => (float) $this->total_income,
                'expenses' => (float) $this->total_expenses,
                'goal_deposits' => (float) $this->total_goal_deposits,
                'unallocated_savings' => (float) $this->unallocated_savings,
            ],

            'allocation' => [
                'status' => $this->allocation_status,
                'allocated_amount' => (float) $this->allocated_amount,
                'unallocated_remaining' => $unallocatedRemaining,
            ],

            'budget' => $this->budget_id !== null ? [
                'budget_id' => (int) $this->budget_id,
                'total_amount' => $this->budget_total_amount !== null ? (float) $this->budget_total_amount : null,
                'total_spent' => $this->budget_total_spent !== null ? (float) $this->budget_total_spent : null,
                'adherence_pct' => $this->budget_adherence_pct !== null ? (float) $this->budget_adherence_pct : null,
            ] : null,

            'top_categories' => $this->top_categories ?? [],
            'transaction_count' => (int) $this->transaction_count,

            'closed_at' => $this->closed_at?->toIso8601String() ?? '',
            'closed_by' => $this->closed_by,
            'notes' => $this->notes ?? '',

            'currency' => $request->user()?->currency ?? 'SAR',
        ];
    }
}
