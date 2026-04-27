<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SendOtpRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'phone' => ['required', 'string', 'regex:/^\+?[0-9]{8,15}$/'],
            'purpose' => ['nullable', 'in:register,login,reset_password'],
            'device_token' => ['nullable', 'string', 'max:512'],
            'platform' => ['nullable', Rule::in(['android', 'ios', 'web'])],
            'locale' => ['nullable', Rule::in(['ar', 'en'])],
        ];
    }

    public function messages(): array
    {
        return [
            'phone.required' => 'رقم الهاتف مطلوب',
            'phone.regex' => 'صيغة رقم الهاتف غير صحيحة',
            'device_token.max' => 'FCM token غير صحيح',
        ];
    }
}
