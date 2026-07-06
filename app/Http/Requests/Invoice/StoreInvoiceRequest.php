<?php

namespace App\Http\Requests\Invoice;

use App\Models\Invoice;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreInvoiceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('invoices.create');
    }

    public function rules(): array
    {
        return [
            // Either link to an existing kitchen order, or create a
            // standalone invoice directly from the cart (matches the
            // original Flutter checkout flow).
            'order_id' => ['nullable', 'exists:orders,id'],

            'customer_id' => ['nullable', 'exists:customers,id'],
            'customer_name' => ['nullable', 'string', 'max:255'],
            'customer_phone' => ['nullable', 'string', 'max:30'],
            'delivery_area_id' => ['nullable', 'required_if:order_type,delivery', 'exists:delivery_areas,id'],
            'delivery_address' => ['nullable', 'required_if:order_type,delivery', 'string'],
            'table_number' => ['nullable', 'required_if:order_type,dine_in', 'string', 'max:20'],
            'notes' => ['nullable', 'string'],

            'order_type' => ['required', Rule::in(Invoice::ORDER_TYPES)],
            'payment_method' => ['required', Rule::in(['cash', 'card', 'online'])],
            'paid' => ['sometimes', 'boolean'],

            'discount' => ['sometimes', 'numeric', 'min:0'],
            'tax' => ['sometimes', 'numeric', 'min:0'],

            // Required only when not building the invoice from an order_id.
            'items' => ['required_without:order_id', 'array', 'min:1'],
            'items.*.menu_item_id' => ['required_with:items', 'exists:menu_items,id'],
            'items.*.quantity' => ['required_with:items', 'integer', 'min:1'],
        ];
    }

    public function messages(): array
    {
        return [
            'items.required_without' => 'يجب إضافة أصناف للفاتورة أو ربطها بطلب موجود',
            'delivery_area_id.required_if' => 'منطقة التوصيل مطلوبة',
            'delivery_address.required_if' => 'عنوان التوصيل مطلوب',
            'table_number.required_if' => 'رقم الطاولة مطلوب',
        ];
    }
}
