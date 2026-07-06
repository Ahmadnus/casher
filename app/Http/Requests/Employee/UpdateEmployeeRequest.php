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

        // SECURITY: this request authorizes on EITHER the employees.update
        // permission OR self-ownership (EmployeePolicy::update). A user
        // editing their own profile must NOT be able to change their role
        // or activation status — otherwise any employee could escalate
        // themselves to admin by PUT-ing their own record. Only an actor
        // with the manage-employees permission may touch those fields.
        $canManageEmployees = $this->user()->can('employees.update');

        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'username' => ['sometimes', 'required', 'string', 'max:255', 'alpha_dash', Rule::unique('users', 'username')->ignore($employeeId)],
            'email' => ['sometimes', 'required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($employeeId)],
            'password' => ['sometimes', 'nullable', 'string', 'confirmed'],
            'phone' => ['nullable', 'string', 'max:30'],
            'pin' => ['nullable', 'string', 'max:10', Rule::unique('users', 'pin')->ignore($employeeId)],
            'role' => $canManageEmployees
                ? ['sometimes', 'required', 'string', 'exists:roles,name']
                : ['prohibited'],
            'is_active' => $canManageEmployees
                ? ['sometimes', 'boolean']
                : ['prohibited'],
            'avatar' => ['nullable', 'image', 'max:4096'],
        ];
    }

    public function messages(): array
    {
        return [
            'username.unique' => 'اسم المستخدم موجود مسبقاً',
            'email.unique' => 'البريد الإلكتروني مستخدم مسبقاً',
            'pin.unique' => 'رمز PIN مستخدم مسبقاً',
            'role.prohibited' => 'لا تملك صلاحية تغيير الدور',
            'is_active.prohibited' => 'لا تملك صلاحية تغيير حالة التفعيل',
        ];
    }
}
