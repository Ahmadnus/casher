<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * @property int $id
 * @property int $invoice_id
 * @property int|null $menu_item_id
 * @property string $name
 * @property float $price
 * @property int $quantity
 * @property float $total
 */
class InvoiceItem extends Model
{
    /** @use HasFactory<\Database\Factories\InvoiceItemFactory> */
    use HasFactory;

    protected $fillable = ['invoice_id', 'menu_item_id', 'name', 'price', 'quantity', 'total'];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'total' => 'decimal:2',
        ];
    }

    public function invoice()
    {
        return $this->belongsTo(Invoice::class);
    }

    public function menuItem()
    {
        return $this->belongsTo(MenuItem::class);
    }
}
