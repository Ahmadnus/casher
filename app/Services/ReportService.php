<?php

namespace App\Services;

use App\Models\Invoice;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Collection;

class ReportService
{
    public function dailySales(?string $date = null): array
    {
        $date = $date ? Carbon::parse($date) : today();

        $query = Invoice::query()->where('status', 'paid')->whereDate('created_at', $date);

        return [
            'date' => $date->toDateString(),
            'total_sales' => (float) (clone $query)->sum('total'),
            'invoice_count' => (clone $query)->count(),
            'subtotal' => (float) (clone $query)->sum('subtotal'),
            'tax' => (float) (clone $query)->sum('tax'),
            'discount' => (float) (clone $query)->sum('discount'),
            'delivery_fee' => (float) (clone $query)->sum('delivery_fee'),
            'average_invoice' => (float) (clone $query)->avg('total'),
        ];
    }

    public function weeklySales(?string $startDate = null): array
    {
        $start = $startDate ? Carbon::parse($startDate)->startOfWeek() : now()->startOfWeek();
        $end = (clone $start)->endOfWeek();

        $byDay = Invoice::query()
            ->where('status', 'paid')
            ->whereBetween('created_at', [$start, $end])
            ->selectRaw('DATE(created_at) as date')
            ->selectRaw('SUM(total) as total_sales')
            ->selectRaw('COUNT(*) as invoice_count')
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        return [
            'start_date' => $start->toDateString(),
            'end_date' => $end->toDateString(),
            'total_sales' => (float) $byDay->sum('total_sales'),
            'invoice_count' => (int) $byDay->sum('invoice_count'),
            'by_day' => $byDay,
        ];
    }

    public function monthlySales(?int $year = null, ?int $month = null): array
    {
        $year ??= now()->year;
        $month ??= now()->month;

        $byDay = Invoice::query()
            ->where('status', 'paid')
            ->whereYear('created_at', $year)
            ->whereMonth('created_at', $month)
            ->selectRaw('DATE(created_at) as date')
            ->selectRaw('SUM(total) as total_sales')
            ->selectRaw('COUNT(*) as invoice_count')
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        return [
            'year' => $year,
            'month' => $month,
            'total_sales' => (float) $byDay->sum('total_sales'),
            'invoice_count' => (int) $byDay->sum('invoice_count'),
            'by_day' => $byDay,
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
