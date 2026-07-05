<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * @property int $id
 * @property string $order_number
 * @property int|null $customer_id
 * @property int $employee_id
 * @property int|null $delivery_area_id
 * @property string $type
 * @property string $status
 * @property string|null $table_number
 */
class Order extends Model
{
    /** @use HasFactory<\Database\Factories\OrderFactory> */
    use HasFactory, SoftDeletes;

    public const TYPES = ['dine_in', 'takeaway', 'delivery', 'coffee_shop'];

    public const STATUSES = ['pending', 'preparing', 'ready', 'delivered', 'cancelled'];

    /**
     * Allowed forward status transitions. Keeps the kitchen workflow
     * linear and prevents e.g. jumping straight from pending to delivered.
     */
    public const TRANSITIONS = [
        'pending' => ['preparing', 'cancelled'],
        'preparing' => ['ready', 'cancelled'],
        'ready' => ['delivered', 'cancelled'],
        'delivered' => [],
        'cancelled' => [],
    ];

    protected $fillable = [
        'order_number', 'customer_id', 'employee_id', 'delivery_area_id',
        'type', 'status', 'table_number', 'notes',
        'preparing_at', 'ready_at', 'delivered_at', 'cancelled_at',
    ];

    protected function casts(): array
    {
        return [
            'preparing_at' => 'datetime',
            'ready_at' => 'datetime',
            'delivered_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
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
        return $this->hasMany(OrderItem::class);
    }

    public function invoice()
    {
        return $this->hasOne(Invoice::class);
    }

    public function canTransitionTo(string $status): bool
    {
        return in_array($status, self::TRANSITIONS[$this->status] ?? [], true);
    }

    public function getSubtotalAttribute(): float
    {
        return (float) $this->items->sum('total');
    }

    public function scopeStatus($query, ?string $status)
    {
        return $status ? $query->where('status', $status) : $query;
    }

    public function scopeType($query, ?string $type)
    {
        return $type ? $query->where('type', $type) : $query;
    }

    public function scopeActive($query)
    {
        return $query->whereNotIn('status', ['delivered', 'cancelled']);
    }

    public function scopeToday($query)
    {
        return $query->whereDate('created_at', today());
    }
}
