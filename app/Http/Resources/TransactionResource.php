<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'amount' => (float) $this->amount,
            'currency' => $this->currency ?? $request->user()?->currency ?? 'SAR',
            'type' => $this->type,
            'description' => $this->description ?? '',
            'merchant' => $this->merchant ?? '',
            'source' => $this->source ?? 'manual',
            'reference' => $this->reference ?? '',
            'transaction_date' => $this->transaction_date?->toIso8601String() ?? '',
            'category' => $this->relationLoaded('category') && $this->category
                ? new CategoryResource($this->category)
                : CategoryResource::emptyShape(),
            'budget_id' => $this->budget_id ?? 0,
            'saving_goal_id' => $this->saving_goal_id ?? 0,
            'monthly_summary_id' => $this->monthly_summary_id ?? 0,
            'created_at' => $this->created_at?->toIso8601String() ?? '',
        ];
    }
}
