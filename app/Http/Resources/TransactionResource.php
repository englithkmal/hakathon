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
            'currency' => $this->currency,
            'type' => $this->type,
            'description' => $this->description,
            'merchant' => $this->merchant,
            'source' => $this->source,
            'reference' => $this->reference,
            'transaction_date' => $this->transaction_date?->toIso8601String(),
            'category' => new CategoryResource($this->whenLoaded('category')),
            'budget_id' => $this->budget_id,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
