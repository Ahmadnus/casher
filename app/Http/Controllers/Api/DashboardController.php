<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Services\DashboardService;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    public function __construct(protected DashboardService $dashboardService) {}

    public function index(): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Order::class);

        $summary = $this->dashboardService->summary();

        return $this->success([
            'today_sales' => $summary['today_sales'],
            'today_orders' => $summary['today_orders'],
            'today_invoice_count' => $summary['today_invoice_count'],
            'revenue_this_month' => $summary['revenue_this_month'],
            'employees_count' => $summary['employees_count'],
            'customers_count' => $summary['customers_count'],
            'pending_orders_count' => $summary['pending_orders_count'],
            'top_selling_items' => $summary['top_selling_items'],
            'latest_orders' => OrderResource::collection($summary['latest_orders']),
            'pending_orders' => OrderResource::collection($summary['pending_orders']),
        ]);
    }
}
