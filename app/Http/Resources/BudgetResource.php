<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BudgetResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'month' => $this->month,
            'year' => $this->year,
            'total_income' => (float) $this->total_income,
            'total_amount' => (float) $this->total_amount,
            'total_spent' => (float) $this->total_spent,
            'remaining' => $this->remaining,
            'progress_percentage' => $this->progress_percentage,
            'currency' => $this->currency,
            'status' => $this->status,
            'notes' => $this->notes,
            'categories' => BudgetCategoryResource::collection($this->whenLoaded('categories')),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
