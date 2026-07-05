<?php

namespace App\Http\Requests\PrinterSetting;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePrinterSettingRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('printer-settings.create');
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'type' => ['required', Rule::in(['cash', 'invoice'])],
            // Android: "vendorId:productId" USB descriptor. Windows: the printer's registered queue name.
            'device_identifier' => ['required', 'string', 'max:191'],
            'is_active' => ['sometimes', 'boolean'],
            'is_default' => ['sometimes', 'boolean'],
        ];
    }
}
