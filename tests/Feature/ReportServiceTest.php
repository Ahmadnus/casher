<?php

namespace Tests\Feature;

use App\Models\Invoice;
use App\Models\InvoiceItem;
use App\Services\ReportService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReportServiceTest extends TestCase
{
    use RefreshDatabase;

    protected function seedInvoices(): void
    {
        // Two paid delivery invoices today: 50 + 30 totals, 5 + 5 fees.
        $d1 = Invoice::factory()->create([
            'order_type' => 'delivery', 'subtotal' => 45, 'tax' => 0,
            'delivery_fee' => 5, 'total' => 50,
        ]);
        $d2 = Invoice::factory()->create([
            'order_type' => 'delivery', 'subtotal' => 25, 'tax' => 0,
            'delivery_fee' => 5, 'total' => 30,
        ]);

        // One paid takeaway invoice today: total 20.
        $t1 = Invoice::factory()->create([
            'order_type' => 'takeaway', 'subtotal' => 20, 'tax' => 0,
            'delivery_fee' => 0, 'total' => 20,
        ]);

        // One unpaid invoice — must be excluded from every report.
        Invoice::factory()->unpaid()->create([
            'order_type' => 'delivery', 'subtotal' => 999, 'tax' => 0,
            'delivery_fee' => 9, 'total' => 999,
        ]);

        InvoiceItem::factory()->create(['invoice_id' => $d1->id, 'quantity' => 2]);
        InvoiceItem::factory()->create(['invoice_id' => $d2->id, 'quantity' => 1]);
        InvoiceItem::factory()->create(['invoice_id' => $t1->id, 'quantity' => 3]);
    }

    public function test_daily_sales_totals_and_delivery_breakdown(): void
    {
        $this->seedInvoices();

        $report = app(ReportService::class)->dailySales();

        $this->assertSame(100.0, $report['total_sales']);
        $this->assertSame(3, $report['invoice_count']);
        $this->assertSame(10.0, $report['delivery_fee']);
        $this->assertSame(6, $report['total_items']);

        $delivery = $report['by_order_type']['delivery'];
        $this->assertSame(80.0, $delivery['total_sales']);
        $this->assertSame(2, $delivery['invoice_count']);
        $this->assertSame(10.0, $delivery['delivery_fee']);

        $takeaway = $report['by_order_type']['takeaway'];
        $this->assertSame(20.0, $takeaway['total_sales']);
        $this->assertSame(1, $takeaway['invoice_count']);
    }

    public function test_weekly_sales_matches_daily_seed(): void
    {
        $this->seedInvoices();

        $report = app(ReportService::class)->weeklySales();

        $this->assertSame(100.0, $report['total_sales']);
        $this->assertSame(3, $report['invoice_count']);
        $this->assertSame(80.0, $report['by_order_type']['delivery']['total_sales']);
        $this->assertSame(6, $report['total_items']);
    }

    public function test_daily_sales_with_order_type_filter(): void
    {
        $this->seedInvoices();

        $report = app(ReportService::class)->dailySales(null, 'delivery');

        $this->assertSame(80.0, $report['total_sales']);
        $this->assertSame(2, $report['invoice_count']);
    }

    public function test_range_sales_covers_period(): void
    {
        $this->seedInvoices();

        $report = app(ReportService::class)->rangeSales(
            today()->toDateString(),
            today()->toDateString(),
        );

        $this->assertSame(100.0, $report['total_sales']);
        $this->assertSame(80.0, $report['by_order_type']['delivery']['total_sales']);
    }
}
