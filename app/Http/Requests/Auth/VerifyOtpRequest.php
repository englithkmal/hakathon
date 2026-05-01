<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class VerifyOtpRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'phone' => ['required', 'string', 'regex:/^\+?[0-9]{8,15}$/'],
            'code' => ['required', 'string', 'size:6'],
            'purpose' => ['nullable', 'in:register,login,reset_password'],
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
            'phone.required' => 'رقم الهاتف مطلوب',
            'code.required' => 'رمز التحقق مطلوب',
            'code.size' => 'رمز التحقق يجب أن يكون 6 أرقام',
        ];
    }
}
