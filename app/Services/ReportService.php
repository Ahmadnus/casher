<?php

namespace App\Services;

use App\Models\Channel;
use App\Models\Invoice;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Collection;

class ReportService
{
    /**
     * Restrict a report query to one order type (e.g. "delivery"),
     * ignoring null/empty so existing callers are unaffected.
     */
    protected function applyOrderType($query, ?string $orderType)
    {
        if (! empty($orderType)) {
            $query->where('order_type', $orderType);
        }

        return $query;
    }

    /**
     * Per-order-type totals for the same invoice set, keyed by type:
     * ['delivery' => ['total_sales' => …, 'invoice_count' => …], …].
     * Feeds the "delivery sales / pickup orders" cards in the app.
     */
    protected function breakdownByOrderType($query): array
    {
        return (clone $query)
            ->selectRaw('order_type')
            ->selectRaw('COALESCE(SUM(total), 0) as total_sales')
            ->selectRaw('COALESCE(SUM(delivery_fee), 0) as delivery_fee')
            ->selectRaw('COUNT(*) as invoice_count')
            ->groupBy('order_type')
            ->get()
            ->mapWithKeys(fn ($row) => [$row->order_type => [
                'total_sales' => (float) $row->total_sales,
                'delivery_fee' => (float) $row->delivery_fee,
                'invoice_count' => (int) $row->invoice_count,
            ]])
            ->all();
    }

    /**
     * Per-channel totals for an invoice set, one row per channel, including
     * commission and net revenue. Unlike breakdownByOrderType this always
     * emits a row for every configured channel (zeros included) so the
     * dashboard's column layout is stable from day to day.
     */
    protected function breakdownByChannel($query): array
    {
        $rows = (clone $query)
            ->selectRaw('order_type')
            ->selectRaw('COALESCE(SUM(total), 0) as total_sales')
            ->selectRaw('COALESCE(SUM(subtotal), 0) as subtotal')
            ->selectRaw('COALESCE(SUM(discount), 0) as discount')
            ->selectRaw('COALESCE(SUM(delivery_fee), 0) as delivery_fee')
            ->selectRaw('COALESCE(SUM(commission_amount), 0) as commission')
            ->selectRaw('COALESCE(SUM(net_total), 0) as net_sales')
            ->selectRaw('COALESCE(AVG(total), 0) as average_invoice')
            ->selectRaw('COUNT(*) as invoice_count')
            ->groupBy('order_type')
            ->get()
            ->keyBy('order_type');

        $grandTotal = (float) $rows->sum('total_sales');

        return Channel::ordered()->get()->map(function (Channel $channel) use ($rows, $grandTotal) {
            $row = $rows->get($channel->code);
            $totalSales = (float) ($row->total_sales ?? 0);

            return [
                'channel_code' => $channel->code,
                'channel_name' => $channel->name,
                'channel_name_ar' => $channel->name_ar,
                'is_third_party' => $channel->is_third_party,
                'is_active' => $channel->is_active,
                'total_sales' => $totalSales,
                'subtotal' => (float) ($row->subtotal ?? 0),
                'discount' => (float) ($row->discount ?? 0),
                'delivery_fee' => (float) ($row->delivery_fee ?? 0),
                'commission' => (float) ($row->commission ?? 0),
                'net_sales' => (float) ($row->net_sales ?? 0),
                'average_invoice' => round((float) ($row->average_invoice ?? 0), 2),
                'invoice_count' => (int) ($row->invoice_count ?? 0),
                // Share of gross sales, so the dashboard can render the split
                // without recomputing it client-side.
                'share_percent' => $grandTotal > 0
                    ? round($totalSales / $grandTotal * 100, 2)
                    : 0.0,
            ];
        })->all();
    }

    /**
     * Total quantity of items sold across the given invoice set.
     */
    protected function itemsSold($query): int
    {
        // whereIn subquery instead of a join: the base query filters on
        // created_at/status, which also exist on invoice_items and would
        // make a joined query fail with an ambiguous-column SQL error.
        return (int) DB::table('invoice_items')
            ->whereIn('invoice_id', (clone $query)->select('invoices.id'))
            ->sum('quantity');
    }

    /**
     * Single-pass aggregate: one SQL query instead of seven clones,
     * plus the per-order-type breakdown and total items sold.
     */
    protected function summarize($query): array
    {
        $byOrderType = $this->breakdownByOrderType($query);
        $totalItems = $this->itemsSold($query);

        $row = (clone $query)
            ->selectRaw('COALESCE(SUM(total), 0) as total_sales')
            ->selectRaw('COUNT(*) as invoice_count')
            ->selectRaw('COALESCE(SUM(subtotal), 0) as subtotal')
            ->selectRaw('COALESCE(SUM(tax), 0) as tax')
            ->selectRaw('COALESCE(SUM(discount), 0) as discount')
            ->selectRaw('COALESCE(SUM(delivery_fee), 0) as delivery_fee')
            ->selectRaw('COALESCE(SUM(commission_amount), 0) as commission')
            ->selectRaw('COALESCE(SUM(net_total), 0) as net_sales')
            ->selectRaw('COALESCE(AVG(total), 0) as average_invoice')
            ->first();

        return [
            'total_sales' => (float) $row->total_sales,
            'invoice_count' => (int) $row->invoice_count,
            'subtotal' => (float) $row->subtotal,
            'tax' => (float) $row->tax,
            'discount' => (float) $row->discount,
            'delivery_fee' => (float) $row->delivery_fee,
            // Gross minus platform commission — the money actually banked.
            'commission' => (float) $row->commission,
            'net_sales' => (float) $row->net_sales,
            'average_invoice' => (float) $row->average_invoice,
            'total_items' => $totalItems,
            'by_order_type' => $byOrderType,
            'by_channel' => $this->breakdownByChannel($query),
        ];
    }

    public function dailySales(?string $date = null, ?string $orderType = null): array
    {
        $date = $date ? Carbon::parse($date) : today();

        $query = $this->applyOrderType(
            Invoice::query()->where('status', 'paid')->whereDate('created_at', $date),
            $orderType,
        );

        return ['date' => $date->toDateString()] + $this->summarize($query);
    }

    /**
     * Summary for an arbitrary inclusive date range (custom report filter).
     */
    public function rangeSales(?string $from = null, ?string $to = null, ?string $orderType = null): array
    {
        $from = $from ? Carbon::parse($from) : today();
        $to = $to ? Carbon::parse($to) : today();

        $query = $this->applyOrderType(
            Invoice::query()
                ->where('status', 'paid')
                ->whereDate('created_at', '>=', $from)
                ->whereDate('created_at', '<=', $to),
            $orderType,
        );

        return [
            'date_from' => $from->toDateString(),
            'date_to' => $to->toDateString(),
        ] + $this->summarize($query);
    }

    public function weeklySales(?string $startDate = null, ?string $orderType = null): array
    {
        $start = $startDate ? Carbon::parse($startDate)->startOfWeek() : now()->startOfWeek();
        $end = (clone $start)->endOfWeek();

        $base = $this->applyOrderType(Invoice::query(), $orderType)
            ->where('status', 'paid')
            ->whereBetween('created_at', [$start, $end]);

        $byDay = (clone $base)
            ->selectRaw('DATE(created_at) as date')
            ->selectRaw('SUM(total) as total_sales')
            ->selectRaw('COUNT(*) as invoice_count')
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        return [
            'start_date' => $start->toDateString(),
            'end_date' => $end->toDateString(),
            'by_day' => $byDay,
        ] + $this->summarize($base);
    }

    public function monthlySales(?int $year = null, ?int $month = null, ?string $orderType = null): array
    {
        $year ??= now()->year;
        $month ??= now()->month;

        $base = $this->applyOrderType(Invoice::query(), $orderType)
            ->where('status', 'paid')
            ->whereYear('created_at', $year)
            ->whereMonth('created_at', $month);

        $byDay = (clone $base)
            ->selectRaw('DATE(created_at) as date')
            ->selectRaw('SUM(total) as total_sales')
            ->selectRaw('COUNT(*) as invoice_count')
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        return [
            'year' => $year,
            'month' => $month,
            'by_day' => $byDay,
        ] + $this->summarize($base);
    }

    /**
     * Full itemized breakdown of every product sold in a date range
     * (defaults to today) — for end-of-day inventory reconciliation.
     * Unlike bestSellingItems there is no limit, and it can be
     * restricted to one order type. Returns both a detailed list and
     * a simple {"Burger": 20} map keyed by item name.
     */
    public function itemizedSales(
        ?string $from = null,
        ?string $to = null,
        ?string $orderType = null,
        ?int $productId = null,
        ?int $categoryId = null,
    ): array {
        $from = $from ? Carbon::parse($from) : today();
        $to = $to ? Carbon::parse($to) : $from;

        $rows = $this->paidItemsQuery($from, $to, $orderType, $productId, $categoryId)
            // Group by the item snapshot name: invoice_items stores the name
            // at sale time, so renamed/deleted menu items still report
            // correctly for the day they were sold.
            ->select('invoice_items.name')
            ->selectRaw('SUM(invoice_items.quantity) as total_quantity')
            ->selectRaw('SUM(invoice_items.total) as total_revenue')
            ->groupBy('invoice_items.name')
            ->orderByDesc('total_quantity')
            ->get();

        return [
            'date_from' => $from->toDateString(),
            'date_to' => $to->toDateString(),
            'total_items' => (int) $rows->sum('total_quantity'),
            'items' => $rows->map(fn ($r) => [
                'name' => $r->name,
                'total_quantity' => (int) $r->total_quantity,
                'total_revenue' => (float) $r->total_revenue,
            ])->values()->all(),
            'items_map' => $rows->mapWithKeys(
                fn ($r) => [$r->name => (int) $r->total_quantity]
            )->all(),
        ];
    }

    /**
     * Base query for every "items sold" report: paid, non-deleted invoices in
     * an inclusive date range, joined to their line items. Optional filters
     * narrow to one sales channel, one product, or one category.
     *
     * Category is resolved through menu_items (left join) so lines whose
     * menu item was since deleted still count when no category filter is set.
     */
    protected function paidItemsQuery(
        Carbon $from,
        Carbon $to,
        ?string $orderType = null,
        ?int $productId = null,
        ?int $categoryId = null,
    ) {
        return DB::table('invoice_items')
            ->join('invoices', 'invoices.id', '=', 'invoice_items.invoice_id')
            ->leftJoin('menu_items', 'menu_items.id', '=', 'invoice_items.menu_item_id')
            ->where('invoices.status', 'paid')
            ->whereNull('invoices.deleted_at')
            ->whereDate('invoices.created_at', '>=', $from)
            ->whereDate('invoices.created_at', '<=', $to)
            ->when(! empty($orderType), fn ($q) => $q->where('invoices.order_type', $orderType))
            ->when($productId, fn ($q) => $q->where('invoice_items.menu_item_id', $productId))
            ->when($categoryId, fn ($q) => $q->where('menu_items.category_id', $categoryId));
    }

    /**
     * Weekly stock-taking pivot: one row per product, one column per sales
     * channel (order source), quantities and revenue aggregated in SQL from
     * invoice_items of PAID invoices — the same rule every other revenue
     * report uses, so the per-channel columns always sum to the same totals
     * the sales reports show.
     *
     *   Product | coffee_shop | talabaty | otlob | other | … | total
     *
     * Filters: date range (inclusive), order_type (one channel), product_id,
     * category_id. With order_type set only that channel's column is
     * returned, and total equals that column.
     */
    public function productSalesByChannel(
        ?string $from = null,
        ?string $to = null,
        ?string $orderType = null,
        ?int $productId = null,
        ?int $categoryId = null,
    ): array {
        $from = $from ? Carbon::parse($from) : today();
        $to = $to ? Carbon::parse($to) : $from;

        $rows = $this->paidItemsQuery($from, $to, $orderType, $productId, $categoryId)
            ->select('invoices.order_type', 'invoice_items.menu_item_id', 'invoice_items.name')
            ->selectRaw('MAX(menu_items.category_id) as category_id')
            ->selectRaw('SUM(invoice_items.quantity) as quantity')
            ->selectRaw('SUM(invoice_items.total) as revenue')
            ->groupBy('invoices.order_type', 'invoice_items.menu_item_id', 'invoice_items.name')
            ->get();

        $channels = Channel::ordered()->get()
            ->when(! empty($orderType), fn ($c) => $c->where('code', $orderType))
            ->values();
        $codes = $channels->pluck('code')->all();
        $zeroQty = array_fill_keys($codes, 0);
        $zeroRev = array_fill_keys($codes, 0.0);

        // Pivot in PHP: the SQL result is at most (products × channels) rows,
        // never one row per invoice item. Lines are keyed by menu_item_id so a
        // renamed product stays one row (latest snapshot name wins); lines
        // whose menu item was deleted fall back to their snapshot name.
        $products = [];
        foreach ($rows as $r) {
            $key = $r->menu_item_id !== null ? 'id:'.$r->menu_item_id : 'name:'.$r->name;

            if (! isset($products[$key])) {
                $products[$key] = [
                    'menu_item_id' => $r->menu_item_id !== null ? (int) $r->menu_item_id : null,
                    'name' => $r->name,
                    'category_id' => $r->category_id !== null ? (int) $r->category_id : null,
                    'quantities' => $zeroQty,
                    'revenue' => $zeroRev,
                    'total_quantity' => 0,
                    'total_revenue' => 0.0,
                ];
            }

            $p = &$products[$key];
            $p['name'] = $r->name;
            if (array_key_exists($r->order_type, $p['quantities'])) {
                $p['quantities'][$r->order_type] += (int) $r->quantity;
                $p['revenue'][$r->order_type] = round($p['revenue'][$r->order_type] + (float) $r->revenue, 2);
            }
            $p['total_quantity'] += (int) $r->quantity;
            $p['total_revenue'] = round($p['total_revenue'] + (float) $r->revenue, 2);
            unset($p);
        }

        $products = collect($products)->sortByDesc('total_quantity')->values()->all();

        $channelTotals = $channels->map(function (Channel $channel) use ($products) {
            $qty = array_sum(array_column(array_column($products, 'quantities'), $channel->code));
            $rev = array_sum(array_column(array_column($products, 'revenue'), $channel->code));

            return [
                'channel_code' => $channel->code,
                'channel_name' => $channel->name,
                'channel_name_ar' => $channel->name_ar,
                'is_third_party' => $channel->is_third_party,
                'total_quantity' => (int) $qty,
                'total_revenue' => round((float) $rev, 2),
            ];
        })->values()->all();

        return [
            'date_from' => $from->toDateString(),
            'date_to' => $to->toDateString(),
            'filters' => [
                'order_type' => $orderType ?: null,
                'product_id' => $productId,
                'category_id' => $categoryId,
            ],
            'channels' => $channelTotals,
            'products' => $products,
            'total_quantity' => (int) array_sum(array_column($products, 'total_quantity')),
            'total_revenue' => round((float) array_sum(array_column($products, 'total_revenue')), 2),
        ];
    }

    /**
     * THE unified multi-channel dashboard: one row per channel (dine-in,
     * takeaway, delivery, coffee shop, Talabaty, Eshyai) plus the combined
     * total, over any date range. This is the single call the summary screen
     * needs — it does not have to fan out one request per channel.
     */
    public function salesByChannel(?string $from = null, ?string $to = null): array
    {
        $from = $from ? Carbon::parse($from) : today();
        $to = $to ? Carbon::parse($to) : $from;

        $query = Invoice::query()
            ->where('status', 'paid')
            ->whereDate('created_at', '>=', $from)
            ->whereDate('created_at', '<=', $to);

        $channels = $this->breakdownByChannel($query);

        $inHouse = array_filter($channels, fn ($c) => ! $c['is_third_party']);
        $thirdParty = array_filter($channels, fn ($c) => $c['is_third_party']);

        $sum = fn (array $rows, string $key) => round(array_sum(array_column($rows, $key)), 2);

        return [
            'date_from' => $from->toDateString(),
            'date_to' => $to->toDateString(),
            'channels' => $channels,

            // Pre-rolled subtotals: "how much of today came from the shop
            // itself vs. from the delivery platforms".
            'in_house' => [
                'total_sales' => $sum($inHouse, 'total_sales'),
                'net_sales' => $sum($inHouse, 'net_sales'),
                'invoice_count' => (int) array_sum(array_column($inHouse, 'invoice_count')),
            ],
            'third_party' => [
                'total_sales' => $sum($thirdParty, 'total_sales'),
                'commission' => $sum($thirdParty, 'commission'),
                'net_sales' => $sum($thirdParty, 'net_sales'),
                'invoice_count' => (int) array_sum(array_column($thirdParty, 'invoice_count')),
            ],
            'totals' => [
                'total_sales' => $sum($channels, 'total_sales'),
                'commission' => $sum($channels, 'commission'),
                'net_sales' => $sum($channels, 'net_sales'),
                'delivery_fee' => $sum($channels, 'delivery_fee'),
                'discount' => $sum($channels, 'discount'),
                'invoice_count' => (int) array_sum(array_column($channels, 'invoice_count')),
            ],
        ];
    }

    /**
     * Day-by-day sales for one channel — powers the per-channel trend chart
     * and the standalone "Talabaty report" / "Eshyai report" screens.
     */
    public function channelTrend(string $channelCode, ?string $from = null, ?string $to = null): array
    {
        $from = $from ? Carbon::parse($from) : today()->subDays(29);
        $to = $to ? Carbon::parse($to) : today();

        $base = Invoice::query()
            ->where('status', 'paid')
            ->where('order_type', $channelCode)
            ->whereDate('created_at', '>=', $from)
            ->whereDate('created_at', '<=', $to);

        $byDay = (clone $base)
            ->selectRaw('DATE(created_at) as day')
            ->selectRaw('COALESCE(SUM(total), 0) as total_sales')
            ->selectRaw('COALESCE(SUM(commission_amount), 0) as commission')
            ->selectRaw('COALESCE(SUM(net_total), 0) as net_sales')
            ->selectRaw('COUNT(*) as invoice_count')
            ->groupBy('day')
            ->orderBy('day')
            ->get()
            ->map(fn ($r) => [
                'date' => (string) $r->day,
                'total_sales' => (float) $r->total_sales,
                'commission' => (float) $r->commission,
                'net_sales' => (float) $r->net_sales,
                'invoice_count' => (int) $r->invoice_count,
            ])->all();

        $channel = Channel::where('code', $channelCode)->first();

        return [
            'channel_code' => $channelCode,
            'channel_name' => $channel?->name,
            'channel_name_ar' => $channel?->name_ar,
            'commission_rate' => (float) ($channel->commission_rate ?? 0),
            'date_from' => $from->toDateString(),
            'date_to' => $to->toDateString(),
            'by_day' => $byDay,
        ] + $this->summarize($base);
    }

    /**
     * Items sold, split per channel — "what does Talabaty actually sell?"
     * Returns one bucket per channel, each with its own item list, so you
     * can stock and price each platform on its real demand.
     */
    public function itemizedByChannel(?string $from = null, ?string $to = null): array
    {
        $from = $from ? Carbon::parse($from) : today();
        $to = $to ? Carbon::parse($to) : $from;

        $rows = DB::table('invoice_items')
            ->join('invoices', 'invoices.id', '=', 'invoice_items.invoice_id')
            ->where('invoices.status', 'paid')
            ->whereNull('invoices.deleted_at')
            ->whereDate('invoices.created_at', '>=', $from)
            ->whereDate('invoices.created_at', '<=', $to)
            ->select('invoices.order_type', 'invoice_items.name')
            ->selectRaw('SUM(invoice_items.quantity) as total_quantity')
            ->selectRaw('SUM(invoice_items.total) as total_revenue')
            ->groupBy('invoices.order_type', 'invoice_items.name')
            ->orderByDesc('total_quantity')
            ->get()
            ->groupBy('order_type');

        $channels = Channel::ordered()->get()->map(function (Channel $channel) use ($rows) {
            $items = $rows->get($channel->code, collect());

            return [
                'channel_code' => $channel->code,
                'channel_name' => $channel->name,
                'channel_name_ar' => $channel->name_ar,
                'total_items' => (int) $items->sum('total_quantity'),
                'total_revenue' => (float) $items->sum('total_revenue'),
                'items' => $items->map(fn ($r) => [
                    'name' => $r->name,
                    'total_quantity' => (int) $r->total_quantity,
                    'total_revenue' => (float) $r->total_revenue,
                ])->values()->all(),
            ];
        })->all();

        return [
            'date_from' => $from->toDateString(),
            'date_to' => $to->toDateString(),
            'channels' => $channels,
        ];
    }

    public function bestSellingItems(?string $from = null, ?string $to = null, int $limit = 20): Collection
    {
        $query = DB::table('invoice_items')
            ->join('invoices', 'invoices.id', '=', 'invoice_items.invoice_id')
            ->where('invoices.status', 'paid');

        if ($from) {
            $query->whereDate('invoices.created_at', '>=', $from);
        }
        if ($to) {
            $query->whereDate('invoices.created_at', '<=', $to);
        }

        return $query->select('invoice_items.name')
            ->selectRaw('SUM(invoice_items.quantity) as total_quantity')
            ->selectRaw('SUM(invoice_items.total) as total_revenue')
            ->groupBy('invoice_items.name')
            ->orderByDesc('total_quantity')
            ->limit($limit)
            ->get();
    }

    public function salesByEmployee(?string $from = null, ?string $to = null): Collection
    {
        $query = Invoice::query()
            ->join('users', 'users.id', '=', 'invoices.employee_id')
            ->where('invoices.status', 'paid');

        if ($from) {
            $query->whereDate('invoices.created_at', '>=', $from);
        }
        if ($to) {
            $query->whereDate('invoices.created_at', '<=', $to);
        }

        return $query->select('users.id as employee_id', 'users.name as employee_name')
            ->selectRaw('SUM(invoices.total) as total_sales')
            ->selectRaw('COUNT(invoices.id) as invoice_count')
            ->groupBy('users.id', 'users.name')
            ->orderByDesc('total_sales')
            ->get();
    }

    public function salesByDeliveryArea(?string $from = null, ?string $to = null): Collection
    {
        $query = Invoice::query()
            ->join('delivery_areas', 'delivery_areas.id', '=', 'invoices.delivery_area_id')
            ->where('invoices.status', 'paid');

        if ($from) {
            $query->whereDate('invoices.created_at', '>=', $from);
        }
        if ($to) {
            $query->whereDate('invoices.created_at', '<=', $to);
        }

        return $query->select('delivery_areas.id as delivery_area_id', 'delivery_areas.name as delivery_area_name')
            ->selectRaw('SUM(invoices.total) as total_sales')
            ->selectRaw('SUM(invoices.delivery_fee) as total_delivery_fees')
            ->selectRaw('COUNT(invoices.id) as invoice_count')
            ->groupBy('delivery_areas.id', 'delivery_areas.name')
            ->orderByDesc('total_sales')
            ->get();
    }

    public function salesByCategory(?string $from = null, ?string $to = null): Collection
    {
        $query = DB::table('invoice_items')
            ->join('invoices', 'invoices.id', '=', 'invoice_items.invoice_id')
            ->join('menu_items', 'menu_items.id', '=', 'invoice_items.menu_item_id')
            ->join('categories', 'categories.id', '=', 'menu_items.category_id')
            ->where('invoices.status', 'paid');

        if ($from) {
            $query->whereDate('invoices.created_at', '>=', $from);
        }
        if ($to) {
            $query->whereDate('invoices.created_at', '<=', $to);
        }

        return $query->select('categories.id as category_id', 'categories.name as category_name')
            ->selectRaw('SUM(invoice_items.quantity) as total_quantity')
            ->selectRaw('SUM(invoice_items.total) as total_revenue')
            ->groupBy('categories.id', 'categories.name')
            ->orderByDesc('total_revenue')
            ->get();
    }
}
