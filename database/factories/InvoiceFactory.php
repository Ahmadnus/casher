<?php

namespace Database\Factories;

use App\Models\Invoice;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Invoice>
 */
class InvoiceFactory extends Factory
{
    public function definition(): array
    {
        $subtotal = fake()->randomFloat(2, 10, 200);
        $tax = round($subtotal * 0.1, 2);
        $total = $subtotal + $tax;

        return [
            'invoice_number' => 'INV-'.now()->format('Ymd').'-'.strtoupper(Str::random(5)),
            'employee_id' => User::factory(),
            'order_type' => fake()->randomElement(Invoice::ORDER_TYPES),
            'subtotal' => $subtotal,
            'tax' => $tax,
            'discount' => 0,
            'delivery_fee' => 0,
            'total' => $total,
            'payment_method' => fake()->randomElement(Invoice::PAYMENT_METHODS),
            'status' => 'paid',
            'paid_at' => now(),
        ];
    }

    public function unpaid(): static
    {
        return $this->state(fn () => ['status' => 'unpaid', 'paid_at' => null]);
    }
}
