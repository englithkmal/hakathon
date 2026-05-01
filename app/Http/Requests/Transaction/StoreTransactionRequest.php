<?php

namespace App\Http\Requests\Transaction;

use Illuminate\Foundation\Http\FormRequest;

class StoreTransactionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'amount' => ['required', 'numeric', 'min:0.01'],
            'currency' => ['nullable', 'string', 'in:SAR,JOD,USD,AED,EUR'],
            'type' => ['required', 'in:expense,income,saving'],
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'saving_goal_id' => [
                'nullable',
                'integer',
                'exists:saving_goals,id',
                // Only meaningful on saving transactions; silently ignored otherwise by the controller.
            ],
            'description' => ['nullable', 'string', 'max:500'],
            'merchant' => ['nullable', 'string', 'max:255'],
            'source' => ['nullable', 'in:manual,mock_bank,imported'],
            'reference' => ['nullable', 'string', 'max:64'],
            'transaction_date' => ['nullable', 'date'],
        ];
    }

    protected function prepareForValidation(): void
    {
        // saving_goal_id only meaningful on a saving transaction — strip noise.
        if ($this->input('type') !== 'saving' && $this->filled('saving_goal_id')) {
            $this->merge(['saving_goal_id' => null]);
        }

        // The user's saving_goal_id must belong to them. We validate ownership
        // here instead of in `rules` so the failure message stays specific.
        $goalId = $this->input('saving_goal_id');
        if ($goalId !== null && $this->user() !== null) {
            $owned = \App\Models\SavingGoal::query()
                ->whereKey($goalId)
                ->where('user_id', $this->user()->id)
                ->exists();
            if (! $owned) {
                $this->merge(['saving_goal_id' => null]);
            }
        }
    }
}
