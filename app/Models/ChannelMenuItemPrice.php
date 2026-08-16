<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * A single item's price/availability override on one channel.
 *
 * @property int $id
 * @property int $channel_id
 * @property int $menu_item_id
 * @property float|null $price
 * @property bool $is_available
 */
class ChannelMenuItemPrice extends Model
{
    /** @use HasFactory<\Database\Factories\ChannelMenuItemPriceFactory> */
    use HasFactory;

    protected $fillable = ['channel_id', 'menu_item_id', 'price', 'is_available'];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'is_available' => 'boolean',
        ];
    }

    public function channel()
    {
        return $this->belongsTo(Channel::class);
    }

    public function menuItem()
    {
        return $this->belongsTo(MenuItem::class);
    }
}
