<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\RestaurantSetting
 */
class RestaurantSettingResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'name' => $this->name,
            'logo_url' => $this->logo_url,
            'currency' => $this->currency,
            'currency_symbol' => $this->currency_symbol,
            'address' => $this->address,
            'phone' => $this->phone,
            'tax_rate' => (float) $this->tax_rate,
            'theme' => $this->theme,
            'receipt_header' => $this->receipt_header,
            'receipt_footer' => $this->receipt_footer,
        ];
    }
}
