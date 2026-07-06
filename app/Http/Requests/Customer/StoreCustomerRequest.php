<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('customers.create');
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            // Ignore soft-deleted customers so a deleted customer's phone
            // can be reused — matches findByPhone, which respects the
            // soft-delete scope and would otherwise never find the old row.
            'phone' => ['required', 'string', 'max:30', Rule::unique('customers', 'phone')->whereNull('deleted_at')],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string'],
            'delivery_address' => ['nullable', 'string'],
            'delivery_area_id' => ['nullable', 'exists:delivery_areas,id'],
            'notes' => ['nullable', 'string'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'phone.unique' => 'رقم الهاتف مستخدم مسبقاً لعميل آخر',
            'phone.required' => 'رقم الهاتف مطلوب',
        ];
    }
}
