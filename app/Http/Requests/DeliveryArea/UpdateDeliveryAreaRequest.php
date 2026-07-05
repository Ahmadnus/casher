<?php

namespace App\Http\Requests\DeliveryArea;

use Illuminate\Foundation\Http\FormRequest;

class UpdateDeliveryAreaRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('delivery-areas.update');
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'delivery_fee' => ['sometimes', 'required', 'numeric', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ];
    }
}
