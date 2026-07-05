<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Customer
 */
class CustomerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'email' => $this->email,
            'address' => $this->address,
            'delivery_address' => $this->delivery_address,
            'delivery_area' => new DeliveryAreaResource($this->whenLoaded('deliveryArea')),
            'notes' => $this->notes,
            'is_active' => $this->is_active,
            'orders_count' => $this->whenCounted('orders'),
            'total_spent' => $this->when($request->boolean('with_stats'), fn () => $this->total_spent),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
