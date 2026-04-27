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
            'description' => ['nullable', 'string', 'max:500'],
            'merchant' => ['nullable', 'string', 'max:255'],
            'source' => ['nullable', 'in:manual,mock_bank,imported'],
            'reference' => ['nullable', 'string', 'max:64'],
            'transaction_date' => ['nullable', 'date'],
        ];
    }
}
