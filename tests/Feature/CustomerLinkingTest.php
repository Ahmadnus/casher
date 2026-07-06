<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\MenuItem;
use App\Models\User;
use App\Services\InvoiceService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CustomerLinkingTest extends TestCase
{
    use RefreshDatabase;

    protected function makeInvoice(array $overrides = []): \App\Models\Invoice
    {
        $employee = User::factory()->create();
        $item = MenuItem::factory()->create(['price' => 10]);

        return app(InvoiceService::class)->create(array_merge([
            'order_type' => 'delivery',
            'payment_method' => 'cash',
            'customer_name' => 'Sami',
            'customer_phone' => '0790000001',
            'delivery_address' => 'Street 1',
            'items' => [['menu_item_id' => $item->id, 'quantity' => 2]],
        ], $overrides), $employee);
    }

    public function test_invoice_with_phone_creates_and_links_customer(): void
    {
        $invoice = $this->makeInvoice();

        $this->assertNotNull($invoice->customer_id);
        $this->assertDatabaseHas('customers', [
            'phone' => '0790000001',
            'name' => 'Sami',
        ]);
    }

    public function test_second_invoice_same_phone_reuses_customer(): void
    {
        $first = $this->makeInvoice();
        $second = $this->makeInvoice(['customer_name' => 'Sami Updated']);

        $this->assertSame($first->customer_id, $second->customer_id);
        $this->assertSame(1, Customer::where('phone', '0790000001')->count());
        // Latest details win for repeat-lookup autofill.
        $this->assertSame('Sami Updated', Customer::find($first->customer_id)->name);
    }

    public function test_invoice_without_phone_links_no_customer(): void
    {
        $invoice = $this->makeInvoice([
            'order_type' => 'takeaway',
            'customer_phone' => null,
            'customer_name' => null,
            'delivery_address' => null,
        ]);

        $this->assertNull($invoice->customer_id);
    }

    public function test_soft_deleted_customer_is_restored_not_duplicated(): void
    {
        $first = $this->makeInvoice();
        Customer::find($first->customer_id)->delete();

        $second = $this->makeInvoice();

        $this->assertSame($first->customer_id, $second->customer_id);
        $this->assertSame(1, Customer::withTrashed()->where('phone', '0790000001')->count());
        $this->assertNull(Customer::find($second->customer_id)->deleted_at);
    }

    public function test_same_idempotency_key_does_not_create_duplicate_invoice(): void
    {
        $employee = \App\Models\User::factory()->create();
        $item = MenuItem::factory()->create(['price' => 10]);
        $payload = [
            'order_type' => 'takeaway',
            'payment_method' => 'cash',
            'idempotency_key' => 'checkout-abc-123',
            'items' => [['menu_item_id' => $item->id, 'quantity' => 1]],
        ];

        $first = app(\App\Services\InvoiceService::class)->create($payload, $employee);
        $second = app(\App\Services\InvoiceService::class)->create($payload, $employee);

        $this->assertSame($first->id, $second->id);
        $this->assertSame(1, \App\Models\Invoice::count());
    }

    public function test_different_idempotency_keys_create_separate_invoices(): void
    {
        $employee = \App\Models\User::factory()->create();
        $item = MenuItem::factory()->create(['price' => 10]);
        $base = [
            'order_type' => 'takeaway',
            'payment_method' => 'cash',
            'items' => [['menu_item_id' => $item->id, 'quantity' => 1]],
        ];

        $first = app(\App\Services\InvoiceService::class)
            ->create($base + ['idempotency_key' => 'key-1'], $employee);
        $second = app(\App\Services\InvoiceService::class)
            ->create($base + ['idempotency_key' => 'key-2'], $employee);

        $this->assertNotSame($first->id, $second->id);
        $this->assertSame(2, \App\Models\Invoice::count());
    }
}
