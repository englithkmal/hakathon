<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SavingGoalResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title ?? '',
            'description' => $this->description ?? '',
            'icon' => $this->icon ?? '',
            'color' => $this->color ?? '#94A3B8',
            'target_amount' => (float) $this->target_amount,
            'current_amount' => (float) $this->current_amount,
            'remaining' => $this->remaining,
            'progress_percentage' => $this->progress_percentage,
            'currency' => $this->currency ?? $request->user()?->currency ?? 'SAR',
            'start_date' => $this->start_date?->toDateString() ?? '',
            'deadline' => $this->deadline?->toDateString() ?? '',
            'status' => $this->status ?? 'active',
            'created_at' => $this->created_at?->toIso8601String() ?? '',
        ];
    }
}
