<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Order
 */
class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'order_number' => $this->order_number,
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'employee' => new UserResource($this->whenLoaded('employee')),
            'delivery_area' => new DeliveryAreaResource($this->whenLoaded('deliveryArea')),
            'type' => $this->type,
            'external_reference' => $this->external_reference,
            'channel' => $this->whenLoaded('channel', fn () => [
                'code' => $this->channel->code,
                'name' => $this->channel->name,
                'name_ar' => $this->channel->name_ar,
                'is_third_party' => (bool) $this->channel->is_third_party,
            ]),
            'status' => $this->status,
            'table_number' => $this->table_number,
            'notes' => $this->notes,
            'items' => OrderItemResource::collection($this->whenLoaded('items')),
            'items_count' => $this->whenLoaded('items', fn () => $this->items->sum('quantity')),
            'subtotal' => $this->whenLoaded('items', fn () => $this->subtotal),
            'has_invoice' => $this->whenLoaded('invoice', fn () => $this->invoice !== null),
            'preparing_at' => $this->preparing_at?->toIso8601String(),
            'ready_at' => $this->ready_at?->toIso8601String(),
            'delivered_at' => $this->delivered_at?->toIso8601String(),
            'cancelled_at' => $this->cancelled_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
