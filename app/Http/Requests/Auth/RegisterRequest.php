<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'min:2', 'max:255'],
            'phone' => ['required', 'string', 'regex:/^\+?[0-9]{8,15}$/', Rule::unique('users', 'phone')],
            'code' => ['required', 'string', 'size:6'],
            'email' => ['nullable', 'email', Rule::unique('users', 'email')],
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
            'name.required' => 'الاسم مطلوب',
            'phone.required' => 'رقم الهاتف مطلوب',
            'phone.unique' => 'هذا الرقم مسجل مسبقاً',
            'code.required' => 'رمز التحقق مطلوب',
            'code.size' => 'رمز التحقق يجب أن يكون 6 أرقام',
            'email.unique' => 'هذا البريد مسجل مسبقاً',
        ];
    }
}
