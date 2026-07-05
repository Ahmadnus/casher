<?php

namespace App\Http\Requests\Employee;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateEmployeeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('update', $this->route('employee'));
    }

    public function rules(): array
    {
        $employeeId = $this->route('employee')->id;

        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'username' => ['sometimes', 'required', 'string', 'max:255', 'alpha_dash', Rule::unique('users', 'username')->ignore($employeeId)],
            'email' => ['sometimes', 'required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($employeeId)],
            'password' => ['sometimes', 'nullable', 'string', 'confirmed'],
            'phone' => ['nullable', 'string', 'max:30'],
            'pin' => ['nullable', 'string', 'max:10', Rule::unique('users', 'pin')->ignore($employeeId)],
            'role' => ['sometimes', 'required', 'string', 'exists:roles,name'],
            'is_active' => ['sometimes', 'boolean'],
            'avatar' => ['nullable', 'image', 'max:4096'],
        ];
    }

    public function messages(): array
    {
        return [
            'username.unique' => 'اسم المستخدم موجود مسبقاً',
            'email.unique' => 'البريد الإلكتروني مستخدم مسبقاً',
            'pin.unique' => 'رمز PIN مستخدم مسبقاً',
        ];
    }
}
