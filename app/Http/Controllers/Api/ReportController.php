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

        return $this->success($this->reportService->dailySales($request->string('date')->value() ?: null));
    }

    public function weekly(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->weeklySales($request->string('start_date')->value() ?: null));
    }

    public function monthly(Request $request): JsonResponse
    {
        $this->authorize('viewAny', \App\Models\Invoice::class);

        return $this->success($this->reportService->monthlySales(
            $request->integer('year') ?: null,
            $request->integer('month') ?: null,
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
