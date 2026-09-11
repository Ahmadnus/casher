<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Channel;
use App\Models\Invoice;
use App\Models\MenuItem;
use App\Models\User;
use App\Services\InvoiceService;
use App\Services\ReportService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Order source (sales channel) attribution and the weekly stock-taking
 * pivot: coffee_shop / talabaty (Talabat) / otlob / other.
 */
class OrderSourceReportTest extends TestCase
{
    use RefreshDatabase;

    protected Category $category;

    protected MenuItem $latte;

    protected MenuItem $burger;

    protected MenuItem $water;

    protected User $employee;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employee = User::factory()->create();
        $this->category = Category::factory()->create();

        $this->latte = MenuItem::factory()->create(['category_id' => $this->category->id, 'price' => 5.00, 'is_available' => true]);
        $this->burger = MenuItem::factory()->create(['category_id' => $this->category->id, 'price' => 10.00, 'is_available' => true]);

        $drinks = Category::factory()->create();
        $this->water = MenuItem::factory()->create(['category_id' => $drinks->id, 'price' => 1.00, 'is_available' => true]);
    }

    public function test_new_order_sources_exist_and_old_codes_are_untouched(): void
    {
        foreach (['coffee_shop', 'talabaty', 'otlob', 'other', 'dine_in', 'takeaway', 'delivery', 'eshyai'] as $code) {
            $this->assertDatabaseHas('channels', ['code' => $code]);
        }

        $this->assertSame('Talabat', Channel::where('code', 'talabaty')->value('name'));
        $this->assertTrue((bool) Channel::where('code', 'otlob')->value('is_third_party'));
        $this->assertFalse((bool) Channel::where('code', 'other')->value('is_third_party'));
        $this->assertContains('otlob', Channel::THIRD_PARTY_CODES);
        $this->assertNotContains('other', Channel::THIRD_PARTY_CODES);
    }

    public function test_order_source_is_stored_and_returned_for_every_source(): void
    {
        foreach (['coffee_shop', 'talabaty', 'otlob', 'other'] as $code) {
            $invoice = $this->sell($code, [[$this->latte, 1]]);

            $this->assertSame($code, $invoice->order_type);
            $this->assertSame(Channel::where('code', $code)->value('id'), $invoice->channel_id);
            $this->assertDatabaseHas('invoices', ['id' => $invoice->id, 'order_type' => $code]);

            $this->asAdmin()
                ->getJson("/api/invoices/{$invoice->id}")
                ->assertOk()
                ->assertJsonPath('data.order_type', $code)
                ->assertJsonPath('data.channel.code', $code);
        }
    }

    public function test_other_source_needs_no_external_reference_but_otlob_does(): void
    {
        $ok = $this->asAdmin()->postJson('/api/invoices', [
            'order_type' => 'other', 'payment_method' => 'cash', 'paid' => true,
            'items' => [['menu_item_id' => $this->latte->id, 'quantity' => 1]],
        ]);
        $ok->assertCreated()->assertJsonPath('data.order_type', 'other');

        $this->asAdmin()->postJson('/api/invoices', [
            'order_type' => 'otlob', 'payment_method' => 'cash', 'paid' => true,
            'items' => [['menu_item_id' => $this->latte->id, 'quantity' => 1]],
        ])->assertUnprocessable()->assertJsonValidationErrors(['external_reference']);
    }

    public function test_revenue_per_source_sums_to_total_revenue(): void
    {
        $this->sell('coffee_shop', [[$this->latte, 3], [$this->burger, 1]]);   // 25
        $this->sell('talabaty', [[$this->burger, 2]], ['discount' => 5]);        // 15
        $this->sell('otlob', [[$this->latte, 2]], ['tax' => 1]);                 // 11
        $this->sell('other', [[$this->water, 4]]);                               // 4

        $report = app(ReportService::class)->rangeSales(today()->toDateString(), today()->toDateString());

        $byCode = collect($report['by_channel'])->keyBy('channel_code');
        $this->assertSame(25.0, $byCode['coffee_shop']['total_sales']);
        $this->assertSame(15.0, $byCode['talabaty']['total_sales']);
        $this->assertSame(11.0, $byCode['otlob']['total_sales']);
        $this->assertSame(4.0, $byCode['other']['total_sales']);
        $this->assertSame(1, $byCode['otlob']['invoice_count']);

        $this->assertSame(55.0, $report['total_sales']);
        $this->assertEqualsWithDelta(
            $report['total_sales'],
            collect($report['by_channel'])->sum('total_sales'),
            0.001,
        );
        $this->assertSame(4, $report['invoice_count']);
    }

    public function test_product_pivot_splits_quantities_per_source_and_sums_to_total(): void
    {
        $this->sell('coffee_shop', [[$this->latte, 35], [$this->burger, 25], [$this->water, 40]]);
        $this->sell('talabaty', [[$this->latte, 20], [$this->burger, 15], [$this->water, 30]]);
        $this->sell('otlob', [[$this->latte, 10], [$this->burger, 5], [$this->water, 10]]);
        $this->sell('other', [[$this->latte, 5], [$this->burger, 2], [$this->water, 5]]);

        $report = app(ReportService::class)->productSalesByChannel(today()->toDateString(), today()->toDateString());

        $products = collect($report['products'])->keyBy('menu_item_id');

        $latte = $products[$this->latte->id];
        $this->assertSame(35, $latte['quantities']['coffee_shop']);
        $this->assertSame(20, $latte['quantities']['talabaty']);
        $this->assertSame(10, $latte['quantities']['otlob']);
        $this->assertSame(5, $latte['quantities']['other']);
        $this->assertSame(70, $latte['total_quantity']);
        $this->assertSame(350.0, $latte['total_revenue']);

        $this->assertSame(47, $products[$this->burger->id]['total_quantity']);
        $this->assertSame(85, $products[$this->water->id]['total_quantity']);

        // Every channel column (including channels with no sales) is present.
        $this->assertCount(Channel::count(), $latte['quantities']);
        $this->assertSame(0, $latte['quantities']['eshyai']);

        foreach ($report['products'] as $p) {
            $this->assertSame($p['total_quantity'], array_sum($p['quantities']));
            $this->assertEqualsWithDelta($p['total_revenue'], array_sum($p['revenue']), 0.001);
        }

        // Column totals equal the sum of the rows, and grand total matches.
        $channels = collect($report['channels'])->keyBy('channel_code');
        $this->assertSame(100, $channels['coffee_shop']['total_quantity']);
        $this->assertSame(65, $channels['talabaty']['total_quantity']);
        $this->assertSame(202, $report['total_quantity']);

        // Cross-check against the existing revenue report: product revenue
        // (sum of line totals) equals the channels' subtotal.
        $range = app(ReportService::class)->rangeSales(today()->toDateString(), today()->toDateString());
        $this->assertEqualsWithDelta($range['subtotal'], $report['total_revenue'], 0.001);
    }

    public function test_pivot_respects_existing_revenue_rules(): void
    {
        $this->sell('coffee_shop', [[$this->latte, 5]]);

        $unpaid = $this->sell('coffee_shop', [[$this->latte, 7]], ['paid' => false]);
        $refunded = $this->sell('talabaty', [[$this->latte, 11]]);
        app(InvoiceService::class)->refund($refunded);
        $cancelled = $this->sell('otlob', [[$this->latte, 13]], ['paid' => false]);
        app(InvoiceService::class)->cancel($cancelled);
        $deleted = $this->sell('other', [[$this->latte, 17]]);
        $deleted->delete();

        $this->assertSame('unpaid', $unpaid->fresh()->status);

        $report = app(ReportService::class)->productSalesByChannel(today()->toDateString(), today()->toDateString());

        $this->assertCount(1, $report['products']);
        $this->assertSame(5, $report['products'][0]['total_quantity']);
        $this->assertSame(5, $report['products'][0]['quantities']['coffee_shop']);
        $this->assertSame(0, $report['products'][0]['quantities']['talabaty']);
        $this->assertSame(0, $report['products'][0]['quantities']['otlob']);
        $this->assertSame(0, $report['products'][0]['quantities']['other']);

        // Discount affects invoice totals but not per-line quantities.
        $range = app(ReportService::class)->rangeSales(today()->toDateString(), today()->toDateString());
        $this->assertSame(25.0, $range['total_sales']);
        $this->assertSame(5, $range['total_items']);
    }

    public function test_pivot_filters_by_source_product_and_category(): void
    {
        $this->sell('coffee_shop', [[$this->latte, 3], [$this->water, 2]]);
        $this->sell('talabaty', [[$this->latte, 4], [$this->burger, 1]]);

        $svc = app(ReportService::class);
        $d = today()->toDateString();

        $onlyTalabat = $svc->productSalesByChannel($d, $d, 'talabaty');
        $this->assertSame(['talabaty'], array_column($onlyTalabat['channels'], 'channel_code'));
        $this->assertSame(5, $onlyTalabat['total_quantity']);
        foreach ($onlyTalabat['products'] as $p) {
            $this->assertSame($p['total_quantity'], $p['quantities']['talabaty']);
        }

        $onlyLatte = $svc->productSalesByChannel($d, $d, null, $this->latte->id);
        $this->assertCount(1, $onlyLatte['products']);
        $this->assertSame(7, $onlyLatte['products'][0]['total_quantity']);

        $foodOnly = $svc->productSalesByChannel($d, $d, null, null, $this->category->id);
        $names = collect($foodOnly['products'])->pluck('menu_item_id')->all();
        $this->assertContains($this->latte->id, $names);
        $this->assertContains($this->burger->id, $names);
        $this->assertNotContains($this->water->id, $names);

        $itemized = $svc->itemizedSales($d, $d, null, null, $this->category->id);
        $this->assertSame(8, $itemized['total_items']);
    }

    public function test_pivot_endpoint_is_reachable_and_validates_source(): void
    {
        $this->sell('other', [[$this->latte, 2]]);
        $d = today()->toDateString();

        $this->asAdmin()
            ->getJson("/api/reports/product-sales-by-channel?date_from={$d}&date_to={$d}")
            ->assertOk()
            ->assertJsonPath('data.total_quantity', 2)
            ->assertJsonPath('data.products.0.quantities.other', 2);

        $this->asAdmin()
            ->getJson("/api/reports/product-sales-by-channel?order_type=bogus")
            ->assertStatus(422);
    }

    // ── helpers ───────────────────────────────────────────────────

    /** @param array<int, array{0: MenuItem, 1: int}> $lines */
    protected function sell(string $code, array $lines, array $extra = []): Invoice
    {
        return app(InvoiceService::class)->create(array_merge([
            'order_type' => $code,
            'payment_method' => 'cash',
            'paid' => true,
            'external_reference' => 'REF-'.uniqid(),
            'items' => array_map(fn ($l) => ['menu_item_id' => $l[0]->id, 'quantity' => $l[1]], $lines),
        ], $extra), $this->employee);
    }

    /** Request builder authenticated as a super_admin via the token middleware. */
    protected function asAdmin(): static
    {
        if (! \Spatie\Permission\Models\Role::where('name', 'super_admin')->exists()) {
            $this->seed(\Database\Seeders\RolePermissionSeeder::class);
        }
        $user = User::factory()->create();
        $user->assignRole('super_admin');

        return $this->withHeader('X-Auth-Token', $user->createToken('test')->plainTextToken);
    }
}
