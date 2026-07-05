<?php

namespace App\Http\Requests\Order;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('orders.create');
    }

    public function rules(): array
    {
        return [
            'customer_id' => ['nullable', 'exists:customers,id'],
            'delivery_area_id' => ['nullable', 'required_if:type,delivery', 'exists:delivery_areas,id'],
            'type' => ['required', Rule::in(\App\Models\Order::TYPES)],
            'table_number' => ['nullable', 'required_if:type,dine_in', 'string', 'max:20'],
            'notes' => ['nullable', 'string'],

            'items' => ['required', 'array', 'min:1'],
            'items.*.menu_item_id' => ['required', 'exists:menu_items,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.notes' => ['nullable', 'string'],
        ];
    }

    public function messages(): array
    {
        return [
            'items.required' => 'يجب إضافة صنف واحد على الأقل للطلب',
            'delivery_area_id.required_if' => 'منطقة التوصيل مطلوبة لطلبات التوصيل',
            'table_number.required_if' => 'رقم الطاولة مطلوب لطلبات الصالة',
        ];
    }
}
