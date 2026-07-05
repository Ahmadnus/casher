<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Invoice;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class DashboardService
{
    public function summary(): array
    {
        $todayInvoices = Invoice::query()->today()->where('status', 'paid');

        return [
            'today_sales' => (float) (clone $todayInvoices)->sum('total'),
            'today_orders' => Order::query()->today()->count(),
            'today_invoice_count' => (clone $todayInvoices)->count(),
            'revenue_this_month' => (float) Invoice::query()
                ->where('status', 'paid')
                ->whereYear('created_at', now()->year)
                ->whereMonth('created_at', now()->month)
                ->sum('total'),
            'employees_count' => User::query()->active()->count(),
            'customers_count' => Customer::query()->active()->count(),
            'pending_orders_count' => Order::query()->whereIn('status', ['pending', 'preparing'])->count(),
            'top_selling_items' => $this->topSellingItems(5),
            'latest_orders' => Order::with(['customer', 'employee'])
                ->latest()
                ->limit(10)
                ->get(),
            'pending_orders' => Order::with(['customer', 'employee'])
                ->whereIn('status', ['pending', 'preparing'])
                ->oldest()
                ->limit(10)
                ->get(),
        ];
    }

    protected function topSellingItems(int $limit): \Illuminate\Support\Collection
    {
        return DB::table('invoice_items')
            ->join('invoices', 'invoices.id', '=', 'invoice_items.invoice_id')
            ->where('invoices.status', 'paid')
            ->select('invoice_items.name')
            ->selectRaw('SUM(invoice_items.quantity) as total_quantity')
            ->selectRaw('SUM(invoice_items.total) as total_revenue')
            ->groupBy('invoice_items.name')
            ->orderByDesc('total_quantity')
            ->limit($limit)
            ->get();
    }
}
