<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * @property int $id
 * @property string $invoice_number
 * @property int|null $order_id
 * @property int|null $customer_id
 * @property int $employee_id
 * @property int|null $delivery_area_id
 * @property string|null $customer_name
 * @property string|null $customer_phone
 * @property string|null $delivery_address
 * @property string $order_type
 * @property string|null $table_number
 * @property float $subtotal
 * @property float $tax
 * @property float $discount
 * @property float $delivery_fee
 * @property float $total
 * @property string $payment_method
 * @property string $status
 */
class Invoice extends Model
{
    /** @use HasFactory<\Database\Factories\InvoiceFactory> */
    use HasFactory, SoftDeletes;

    public const PAYMENT_METHODS = ['cash', 'card', 'online'];

    public const STATUSES = ['unpaid', 'paid', 'refunded', 'cancelled'];

    public const ORDER_TYPES = ['dine_in', 'takeaway', 'delivery', 'coffee_shop'];

    protected $fillable = [
        'invoice_number', 'order_id', 'customer_id', 'employee_id', 'delivery_area_id',
        'customer_name', 'customer_phone', 'delivery_address', 'notes', 'order_type', 'table_number',
        'subtotal', 'tax', 'discount', 'delivery_fee', 'total',
        'payment_method', 'status', 'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'decimal:2',
            'tax' => 'decimal:2',
            'discount' => 'decimal:2',
            'delivery_fee' => 'decimal:2',
            'total' => 'decimal:2',
            'paid_at' => 'datetime',
        ];
    }

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }

    public function employee()
    {
        return $this->belongsTo(User::class, 'employee_id');
    }

    public function deliveryArea()
    {
        return $this->belongsTo(DeliveryArea::class);
    }

    public function items()
    {
        return $this->hasMany(InvoiceItem::class);
    }

    public function getItemCountAttribute(): int
    {
        return (int) $this->items->sum('quantity');
    }

    public function scopeStatus($query, ?string $status)
    {
        return $status ? $query->where('status', $status) : $query;
    }

    public function scopePaymentMethod($query, ?string $method)
    {
        return $method ? $query->where('payment_method', $method) : $query;
    }

    public function scopeBetweenDates($query, ?string $from, ?string $to)
    {
        if ($from) {
            $query->whereDate('created_at', '>=', $from);
        }
        if ($to) {
            $query->whereDate('created_at', '<=', $to);
        }

        return $query;
    }

    public function scopeToday($query)
    {
        return $query->whereDate('created_at', today());
    }

    public function scopeSearch($query, ?string $term)
    {
        if (blank($term)) {
            return $query;
        }

        return $query->where(function ($q) use ($term) {
            $q->where('invoice_number', 'like', "%{$term}%")
                ->orWhere('customer_name', 'like', "%{$term}%")
                ->orWhere('customer_phone', 'like', "%{$term}%");
        });
    }
}
