<?php

namespace Database\Factories;

use App\Models\Invoice;
use App\Models\MenuItem;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\InvoiceItem>
 */
class InvoiceItemFactory extends Factory
{
    public function definition(): array
    {
        $price = fake()->randomFloat(2, 1, 30);
        $qty = fake()->numberBetween(1, 4);

        return [
            'invoice_id' => Invoice::factory(),
            'menu_item_id' => MenuItem::factory(),
            'name' => fake()->words(2, true),
            'price' => $price,
            'quantity' => $qty,
            'total' => $price * $qty,
        ];
    }
}
