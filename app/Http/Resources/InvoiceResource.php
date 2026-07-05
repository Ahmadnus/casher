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
            'order_type' => $this->order_type,

            'items' => InvoiceItemResource::collection($this->whenLoaded('items')),
            'item_count' => $this->whenLoaded('items', fn () => $this->item_count),

            'subtotal' => (float) $this->subtotal,
            'tax' => (float) $this->tax,
            'discount' => (float) $this->discount,
            'delivery_fee' => (float) $this->delivery_fee,
            'total' => (float) $this->total,

            'payment_method' => $this->payment_method,
            'status' => $this->status,
            'paid_at' => $this->paid_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
