<?php

namespace App\Http\Resources;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BudgetResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $periodStart = Carbon::createFromDate((int) $this->year, (int) $this->month, 1)->startOfDay();
        $periodEnd = (clone $periodStart)->endOfMonth();

        return [
            'id' => $this->id,
            'month' => $this->month,
            'year' => $this->year,
            'period_start' => $periodStart->toDateString(),
            'period_end' => $periodEnd->toDateString(),
            'total_income' => (float) $this->total_income,
            'total_amount' => (float) $this->total_amount,
            'total_spent' => (float) $this->total_spent,
            'remaining' => $this->remaining,
            'progress_percentage' => $this->progress_percentage,
            'currency' => $this->currency ?? $request->user()?->currency ?? 'SAR',
            'status' => $this->status ?? 'draft',
            'notes' => $this->notes ?? '',
            'categories' => BudgetCategoryResource::collection($this->whenLoaded('categories')),
            'created_at' => $this->created_at?->toIso8601String() ?? '',
            'updated_at' => $this->updated_at?->toIso8601String() ?? '',
        ];
    }
}
