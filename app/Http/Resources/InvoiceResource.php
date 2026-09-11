<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Invoice
 */
class InvoiceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'invoice_number' => $this->invoice_number,
            'order_id' => $this->order_id,
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'customer_name' => $this->customer_name,
            'customer_phone' => $this->customer_phone,
            'employee' => new UserResource($this->whenLoaded('employee')),
            'delivery_area' => new DeliveryAreaResource($this->whenLoaded('deliveryArea')),
            'delivery_address' => $this->delivery_address,
            'table_number' => $this->table_number,
            'notes' => $this->notes,
            // Order source / sales channel. `order_type` is the channel code
            // (coffee_shop, talabaty, otlob, other, …); `channel` carries the
            // display names so clients never hard-code them.
            'order_type' => $this->order_type,
            'external_reference' => $this->external_reference,
            'channel' => $this->whenLoaded('channel', fn () => [
                'code' => $this->channel->code,
                'name' => $this->channel->name,
                'name_ar' => $this->channel->name_ar,
                'is_third_party' => (bool) $this->channel->is_third_party,
            ]),

            'items' => InvoiceItemResource::collection($this->whenLoaded('items')),
            'item_count' => $this->whenLoaded('items', fn () => $this->item_count),

            'subtotal' => (float) $this->subtotal,
            'tax' => (float) $this->tax,
            'discount' => (float) $this->discount,
            'delivery_fee' => (float) $this->delivery_fee,
            'total' => (float) $this->total,
            'commission_rate' => (float) $this->commission_rate,
            'commission_amount' => (float) $this->commission_amount,
            'net_total' => (float) $this->net_total,

            'payment_method' => $this->payment_method,
            'status' => $this->status,
            'paid_at' => $this->paid_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
