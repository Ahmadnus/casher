<?php

namespace App\Http\Requests\Order;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateOrderStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('orders.update-status');
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in(['pending', 'preparing', 'ready', 'delivered', 'cancelled'])],
        ];
    }
}
