<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function __construct(protected ReportService $reportService) {}

    public function daily(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->dailySales(
            $request->string('date')->value() ?: null,
            $request->string('order_type')->value() ?: null,
        ));
    }

    public function range(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->rangeSales(
            $request->string('date_from')->value() ?: null,
            $request->string('date_to')->value() ?: null,
            $request->string('order_type')->value() ?: null,
        ));
    }

    public function weekly(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->weeklySales(
            $request->string('start_date')->value() ?: null,
            $request->string('order_type')->value() ?: null,
        ));
    }

    public function monthly(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->monthlySales(
            $request->integer('year') ?: null,
            $request->integer('month') ?: null,
            $request->string('order_type')->value() ?: null,
        ));
    }

    public function itemized(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->itemizedSales(
            $request->string('date_from')->value() ?: null,
            $request->string('date_to')->value() ?: null,
            $request->string('order_type')->value() ?: null,
            $request->integer('product_id') ?: null,
            $request->integer('category_id') ?: null,
        ));
    }

    /**
     * Product × order-source pivot for weekly stock-taking: units and revenue
     * of every product, split per channel, aggregated in SQL.
     * Params: date_from, date_to, order_type, product_id, category_id.
     */
    public function productSalesByChannel(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        $orderType = $request->string('order_type')->value() ?: null;
        if ($orderType !== null) {
            abort_unless(in_array($orderType, \App\Models\Channel::CODES, true), 422, 'قناة البيع غير معروفة');
        }

        return $this->success($this->reportService->productSalesByChannel(
            $request->string('date_from')->value() ?: null,
            $request->string('date_to')->value() ?: null,
            $orderType,
            $request->integer('product_id') ?: null,
            $request->integer('category_id') ?: null,
        ));
    }

    /**
     * Unified multi-channel summary — sales per channel plus overall totals.
     */
    public function salesByChannel(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->salesByChannel(
            $request->string('date_from')->value() ?: null,
            $request->string('date_to')->value() ?: null,
        ));
    }

    /**
     * Standalone report for one channel (e.g. /reports/channel/talabaty).
     */
    public function channelTrend(Request $request, string $channel): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        abort_unless(in_array($channel, \App\Models\Channel::CODES, true), 404);

        return $this->success($this->reportService->channelTrend(
            $channel,
            $request->string('date_from')->value() ?: null,
            $request->string('date_to')->value() ?: null,
        ));
    }

    /**
     * Items sold broken down per channel.
     */
    public function itemizedByChannel(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->itemizedByChannel(
            $request->string('date_from')->value() ?: null,
            $request->string('date_to')->value() ?: null,
        ));
    }

    public function bestSellingItems(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->bestSellingItems(
            $request->string('date_from')->value() ?: null,
            $request->string('date_to')->value() ?: null,
            $request->integer('limit') ?: 20,
        ));
    }

    public function salesByEmployee(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->salesByEmployee(
            $request->string('date_from')->value() ?: null,
            $request->string('date_to')->value() ?: null,
        ));
    }

    public function salesByDeliveryArea(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->salesByDeliveryArea(
            $request->string('date_from')->value() ?: null,
            $request->string('date_to')->value() ?: null,
        ));
    }

    public function salesByCategory(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->salesByCategory(
            $request->string('date_from')->value() ?: null,
            $request->string('date_to')->value() ?: null,
        ));
    }
}
