<?php

namespace App\Http\Requests\Budget;

use Illuminate\Foundation\Http\FormRequest;

class StoreBudgetRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'month' => ['nullable', 'integer', 'min:1', 'max:12'],
            'year' => ['nullable', 'integer', 'min:2020', 'max:2100'],
            'total_income' => ['nullable', 'numeric', 'min:0'],
            'total_amount' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'in:SAR,JOD,USD,AED,EUR'],
            'status' => ['nullable', 'in:draft,active,closed'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'categories' => ['nullable', 'array'],
            'categories.*.category_id' => ['required_with:categories', 'integer', 'exists:categories,id'],
            'categories.*.allocated_amount' => ['required_with:categories', 'numeric', 'min:0'],
            'categories.*.alert_threshold' => ['nullable', 'integer', 'min:50', 'max:100'],
        ];
    }
}
