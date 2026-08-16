<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * @property int $id
 * @property string $code
 * @property string $name
 * @property string|null $name_ar
 * @property float $commission_rate
 * @property bool $is_third_party
 * @property bool $is_active
 * @property int $sort_order
 */
class Channel extends Model
{
    /** @use HasFactory<\Database\Factories\ChannelFactory> */
    use HasFactory;

    public const DINE_IN = 'dine_in';

    public const TAKEAWAY = 'takeaway';

    public const DELIVERY = 'delivery';

    public const COFFEE_SHOP = 'coffee_shop';

    public const TALABATY = 'talabaty';

    public const ESHYAI = 'eshyai';

    /**
     * Every valid channel code. Mirrors the orders.type / invoices.order_type
     * enum — the DB enum and this list must be changed together.
     */
    public const CODES = [
        self::DINE_IN,
        self::TAKEAWAY,
        self::DELIVERY,
        self::COFFEE_SHOP,
        self::TALABATY,
        self::ESHYAI,
    ];

    /** Third-party aggregators: no table, external reference, commission. */
    public const THIRD_PARTY_CODES = [self::TALABATY, self::ESHYAI];

    protected $fillable = [
        'code', 'name', 'name_ar', 'commission_rate',
        'is_third_party', 'is_active', 'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'commission_rate' => 'decimal:2',
            'is_third_party' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    /**
     * Bind routes by code, so the API reads /channels/talabaty/menu and the
     * POS never has to know a channel's numeric id.
     */
    public function getRouteKeyName(): string
    {
        return 'code';
    }

    public function orders()
    {
        return $this->hasMany(Order::class);
    }

    public function invoices()
    {
        return $this->hasMany(Invoice::class);
    }

    public function menuItemPrices()
    {
        return $this->hasMany(ChannelMenuItemPrice::class);
    }

    /**
     * Commission this channel would take on the given gross amount.
     */
    public function commissionOn(float $amount): float
    {
        return round($amount * ((float) $this->commission_rate / 100), 2);
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeOrdered($query)
    {
        return $query->orderBy('sort_order')->orderBy('name');
    }
}
