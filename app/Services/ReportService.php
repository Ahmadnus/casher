<?php

namespace App\Services;

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
            ->selectRaw('COALESCE(AVG(total), 0) as average_invoice')
            ->first();

        return [
            'total_sales' => (float) $row->total_sales,
            'invoice_count' => (int) $row->invoice_count,
            'subtotal' => (float) $row->subtotal,
            'tax' => (float) $row->tax,
            'discount' => (float) $row->discount,
            'delivery_fee' => (float) $row->delivery_fee,
            'average_invoice' => (float) $row->average_invoice,
            'total_items' => $totalItems,
            'by_order_type' => $byOrderType,
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
    public function itemizedSales(?string $from = null, ?string $to = null, ?string $orderType = null): array
    {
        $from = $from ? Carbon::parse($from) : today();
        $to = $to ? Carbon::parse($to) : $from;

        $rows = DB::table('invoice_items')
            ->join('invoices', 'invoices.id', '=', 'invoice_items.invoice_id')
            ->where('invoices.status', 'paid')
            ->whereNull('invoices.deleted_at')
            ->whereDate('invoices.created_at', '>=', $from)
            ->whereDate('invoices.created_at', '<=', $to)
            ->when(! empty($orderType), fn ($q) => $q->where('invoices.order_type', $orderType))
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
