<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Two supported login modes, matching the existing Flutter
     * AuthController.login() and AuthController.loginWithPin():
     *
     *   mode=credentials -> username + password
     *   mode=pin         -> pin only (fast POS terminal login)
     */
    public function rules(): array
    {
        return [
            'mode' => ['required', Rule::in(['credentials', 'pin'])],

            'username' => ['required_if:mode,credentials', 'string'],
            'password' => ['required_if:mode,credentials', 'string'],

            'pin' => ['required_if:mode,pin', 'string', 'max:10'],

            'device_name' => ['nullable', 'string', 'max:255'],
            'remember' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'username.required_if' => 'اسم المستخدم مطلوب',
            'password.required_if' => 'كلمة المرور مطلوبة',
            'pin.required_if' => 'رمز PIN مطلوب',
        ];
    }
}