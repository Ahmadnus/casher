<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Channel;
use App\Models\ChannelMenuItemPrice;
use App\Models\Invoice;
use App\Models\InvoiceItem;
use App\Models\MenuItem;
use App\Models\User;
use App\Services\ChannelService;
use App\Services\InvoiceService;
use App\Services\ReportService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

/**
 * Multi-channel sales: per-channel pricing, commission snapshotting and the
 * segregated / unified reporting that sits on top of them.
 */
class ChannelSalesTest extends TestCase
{
    use RefreshDatabase;

    protected function channel(string $code): Channel
    {
        return Channel::where('code', $code)->firstOrFail();
    }

    public function test_migration_seeds_all_channels(): void
    {
        $this->assertSame(8, Channel::count());

        foreach (Channel::CODES as $code) {
            $this->assertDatabaseHas('channels', ['code' => $code]);
        }

        $this->assertTrue($this->channel('talabaty')->is_third_party);
        $this->assertTrue($this->channel('eshyai')->is_third_party);
        $this->assertFalse($this->channel('dine_in')->is_third_party);
    }

    public function test_invoice_snapshots_commission_for_third_party_channel(): void
    {
        $this->channel('talabaty')->update(['commission_rate' => 20]);
        app(ChannelService::class)->flushCache();

        $invoice = $this->createInvoice('talabaty', 100.0);

        $this->assertSame('20.00', $invoice->commission_rate);
        $this->assertSame('20.00', $invoice->commission_amount);
        $this->assertSame('80.00', $invoice->net_total);
        $this->assertSame($this->channel('talabaty')->id, $invoice->channel_id);
    }

    public function test_in_house_channel_has_no_commission(): void
    {
        $invoice = $this->createInvoice('dine_in', 100.0, ['table_number' => '3']);

        $this->assertSame('0.00', $invoice->commission_amount);
        $this->assertSame('100.00', $invoice->net_total);
    }

    /**
     * Changing a rate must never rewrite revenue that was already booked.
     */
    public function test_commission_snapshot_survives_a_later_rate_change(): void
    {
        $this->channel('eshyai')->update(['commission_rate' => 10]);
        app(ChannelService::class)->flushCache();

        $invoice = $this->createInvoice('eshyai', 200.0);
        $this->assertSame('20.00', $invoice->commission_amount);

        $this->channel('eshyai')->update(['commission_rate' => 50]);
        app(ChannelService::class)->flushCache();

        $this->assertSame('20.00', $invoice->fresh()->commission_amount);
        $this->assertSame('180.00', $invoice->fresh()->net_total);
    }

    public function test_channel_price_override_is_applied_to_invoice_lines(): void
    {
        [$item] = $this->menu();

        ChannelMenuItemPrice::create([
            'channel_id' => $this->channel('talabaty')->id,
            'menu_item_id' => $item->id,
            'price' => 15.00,
        ]);

        $talabaty = app(InvoiceService::class)->create([
            'order_type' => 'talabaty', 'external_reference' => 'T-1',
            'payment_method' => 'online', 'paid' => true,
            'items' => [['menu_item_id' => $item->id, 'quantity' => 2]],
        ], $this->employee());

        $dineIn = app(InvoiceService::class)->create([
            'order_type' => 'dine_in', 'table_number' => '1',
            'payment_method' => 'cash', 'paid' => true,
            'items' => [['menu_item_id' => $item->id, 'quantity' => 2]],
        ], $this->employee());

        // Same item, same quantity, different channel → different revenue.
        $this->assertSame('30.00', $talabaty->total);
        $this->assertSame('20.00', $dineIn->total);
    }

    public function test_item_hidden_from_a_channel_cannot_be_sold_on_it(): void
    {
        [$item] = $this->menu();

        ChannelMenuItemPrice::create([
            'channel_id' => $this->channel('talabaty')->id,
            'menu_item_id' => $item->id,
            'is_available' => false,
        ]);

        $menu = app(ChannelService::class)->menuFor($this->channel('talabaty'));
        $this->assertCount(0, $menu);

        // Still sellable in-store.
        $this->assertCount(1, app(ChannelService::class)->menuFor($this->channel('dine_in')));
    }

    public function test_paused_channel_is_rejected(): void
    {
        $this->channel('eshyai')->update(['is_active' => false]);
        app(ChannelService::class)->flushCache();

        $this->expectException(ValidationException::class);
        $this->createInvoice('eshyai', 10.0);
    }

    public function test_sales_by_channel_segregates_each_channel(): void
    {
        $this->channel('talabaty')->update(['commission_rate' => 25]);
        app(ChannelService::class)->flushCache();

        $this->createInvoice('dine_in', 40.0, ['table_number' => '2']);
        $this->createInvoice('talabaty', 100.0);
        $this->createInvoice('talabaty', 60.0);

        $report = app(ReportService::class)->salesByChannel();
        $rows = collect($report['channels'])->keyBy('channel_code');

        // Every channel gets a row so the dashboard layout is stable.
        $this->assertCount(8, $report['channels']);

        $this->assertSame(40.0, $rows['dine_in']['total_sales']);
        $this->assertSame(1, $rows['dine_in']['invoice_count']);
        $this->assertSame(0.0, $rows['dine_in']['commission']);

        $this->assertSame(160.0, $rows['talabaty']['total_sales']);
        $this->assertSame(2, $rows['talabaty']['invoice_count']);
        $this->assertSame(40.0, $rows['talabaty']['commission']);
        $this->assertSame(120.0, $rows['talabaty']['net_sales']);

        // Channel with no sales still reports zeros, not a missing key.
        $this->assertSame(0.0, $rows['eshyai']['total_sales']);
        $this->assertSame(0, $rows['eshyai']['invoice_count']);

        // Roll-ups.
        $this->assertSame(200.0, $report['totals']['total_sales']);
        $this->assertSame(40.0, $report['totals']['commission']);
        $this->assertSame(160.0, $report['totals']['net_sales']);
        $this->assertSame(40.0, $report['in_house']['total_sales']);
        $this->assertSame(160.0, $report['third_party']['total_sales']);
    }

    public function test_unpaid_invoices_are_excluded_from_channel_reports(): void
    {
        Invoice::factory()->unpaid()->create([
            'order_type' => 'talabaty', 'total' => 999, 'net_total' => 999,
        ]);

        $report = app(ReportService::class)->salesByChannel();
        $rows = collect($report['channels'])->keyBy('channel_code');

        $this->assertSame(0.0, $rows['talabaty']['total_sales']);
        $this->assertSame(0.0, $report['totals']['total_sales']);
    }

    public function test_itemized_report_is_bucketed_per_channel(): void
    {
        $talabaty = Invoice::factory()->create([
            'order_type' => 'talabaty', 'total' => 30, 'net_total' => 30,
        ]);
        $dineIn = Invoice::factory()->create([
            'order_type' => 'dine_in', 'total' => 20, 'net_total' => 20,
        ]);

        InvoiceItem::factory()->create([
            'invoice_id' => $talabaty->id, 'name' => 'Latte', 'quantity' => 3, 'total' => 30,
        ]);
        InvoiceItem::factory()->create([
            'invoice_id' => $dineIn->id, 'name' => 'Latte', 'quantity' => 2, 'total' => 20,
        ]);

        $report = app(ReportService::class)->itemizedByChannel();
        $rows = collect($report['channels'])->keyBy('channel_code');

        // The same product, tracked independently per channel.
        $this->assertSame(3, $rows['talabaty']['total_items']);
        $this->assertSame(30.0, $rows['talabaty']['total_revenue']);
        $this->assertSame(2, $rows['dine_in']['total_items']);
        $this->assertSame(0, $rows['eshyai']['total_items']);
    }

    public function test_channel_trend_reports_a_single_channel_only(): void
    {
        $this->channel('talabaty')->update(['commission_rate' => 10]);
        app(ChannelService::class)->flushCache();

        $this->createInvoice('talabaty', 50.0);
        $this->createInvoice('dine_in', 999.0, ['table_number' => '9']);

        $trend = app(ReportService::class)->channelTrend('talabaty');

        $this->assertSame(50.0, $trend['total_sales']);
        $this->assertSame(1, $trend['invoice_count']);
        $this->assertSame(10.0, $trend['commission_rate']);
        $this->assertCount(1, $trend['by_day']);
    }

    /**
     * Regression: channels used to be held in the cache store, which meant
     * serializing Eloquent models. A blob unserialized while the class was
     * unresolvable came back as __PHP_Incomplete_Class and broke every
     * request after the first. Resolving repeatedly must stay type-safe.
     */
    public function test_repeated_channel_lookups_return_real_models(): void
    {
        $service = app(ChannelService::class);

        for ($i = 0; $i < 3; $i++) {
            $this->assertInstanceOf(\Illuminate\Support\Collection::class, $service->all());
            $this->assertInstanceOf(Channel::class, $service->resolveForWrite('talabaty'));
        }

        // A rate change is visible immediately after the memo is flushed.
        $this->channel('talabaty')->update(['commission_rate' => 33]);
        $service->flushCache();
        $this->assertSame('33.00', $service->resolveForWrite('talabaty')->commission_rate);
    }

    public function test_third_party_channels_number_invoices_independently(): void
    {
        $day = now()->format('Ymd');

        $t1 = $this->createInvoice('talabaty', 10.0);
        $t2 = $this->createInvoice('talabaty', 10.0);
        $e1 = $this->createInvoice('eshyai', 10.0);
        $d1 = $this->createInvoice('dine_in', 10.0, ['table_number' => '1']);
        $d2 = $this->createInvoice('takeaway', 10.0);

        // Each platform runs its own sequence from 0001.
        $this->assertSame("TLB-{$day}-0001", $t1->invoice_number);
        $this->assertSame("TLB-{$day}-0002", $t2->invoice_number);
        $this->assertSame("ESH-{$day}-0001", $e1->invoice_number);

        // In-house channels keep sharing the original INV counter.
        $this->assertSame("INV-{$day}-0001", $d1->invoice_number);
        $this->assertSame("INV-{$day}-0002", $d2->invoice_number);
    }

    /**
     * Backs the POS's per-channel invoice list: filtering must query the
     * whole set server-side, not just narrow the current page.
     */
    public function test_invoice_list_can_be_filtered_to_one_channel(): void
    {
        $this->createInvoice('talabaty', 10.0);
        $this->createInvoice('talabaty', 10.0);
        $this->createInvoice('eshyai', 10.0);
        $this->createInvoice('dine_in', 10.0, ['table_number' => '4']);

        $service = app(InvoiceService::class);

        $talabaty = $service->paginate(['order_type' => 'talabaty']);
        $this->assertSame(2, $talabaty->total());
        foreach ($talabaty->items() as $invoice) {
            $this->assertSame('talabaty', $invoice->order_type);
        }

        $eshyai = $service->paginate(['order_type' => 'eshyai']);
        $this->assertSame(1, $eshyai->total());

        // The "channel" alias filters the same column.
        $this->assertSame(2, $service->paginate(['channel' => 'talabaty'])->total());

        // No filter still returns everything.
        $this->assertSame(4, $service->paginate([])->total());
    }

    // ── helpers ────────────────────────────────────────────────────

    protected function employee(): User
    {
        return User::factory()->create();
    }

    /** @return array{0: MenuItem} */
    protected function menu(): array
    {
        $category = Category::factory()->create();

        return [MenuItem::factory()->create([
            'category_id' => $category->id,
            'price' => 10.00,
            'is_available' => true,
        ])];
    }

    /**
     * Creates a paid invoice on [$code] whose total is exactly [$amount],
     * by selling $amount worth of a 1.00 item.
     */
    protected function createInvoice(string $code, float $amount, array $extra = []): Invoice
    {
        $category = Category::factory()->create();
        $item = MenuItem::factory()->create([
            'category_id' => $category->id,
            'price' => 1.00,
            'is_available' => true,
        ]);

        return app(InvoiceService::class)->create(array_merge([
            'order_type' => $code,
            'payment_method' => 'cash',
            'paid' => true,
            'external_reference' => 'REF-'.uniqid(),
            'items' => [['menu_item_id' => $item->id, 'quantity' => (int) $amount]],
        ], $extra), $this->employee());
    }
}
