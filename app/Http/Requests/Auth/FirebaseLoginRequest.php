<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class FirebaseLoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'id_token' => ['required', 'string', 'min:50'],
            'name' => ['nullable', 'string', 'max:255'],
            'monthly_income' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'in:SAR,JOD,USD,AED,EUR'],
            'language' => ['nullable', 'string', 'in:ar,en'],
            'device_token' => ['nullable', 'string', 'max:512'],
            'token' => ['nullable', 'string', 'max:512'],
            'platform' => ['nullable', Rule::in(['android', 'ios', 'web'])],
            'locale' => ['nullable', Rule::in(['ar', 'en'])],
            'device_name' => ['nullable', 'string', 'max:255'],
            'device_model' => ['nullable', 'string', 'max:255'],
            'app_version' => ['nullable', 'string', 'max:50'],
        ];
    }

    public function messages(): array
    {
        return [
            'id_token.required' => 'Firebase ID token مطلوب',
            'id_token.min' => 'الرمز المرسل غير صالح',
        ];
    }
}
