<?php

namespace App\Http\Requests\Invoice;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class MarkInvoicePaidRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('invoices.update');
    }

    public function rules(): array
    {
        return [
            'payment_method' => ['sometimes', Rule::in(['cash', 'card', 'online'])],
        ];
    }
}
