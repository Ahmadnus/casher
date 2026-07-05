<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Order\StoreOrderRequest;
use App\Http\Requests\Order\UpdateOrderStatusRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\OrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function __construct(protected OrderService $orderService) {}

    public function index(Request $request): JsonResponse
    {
        $this->authorize('viewAny', Order::class);

        $orders = $this->orderService->paginate($request->only([
            'status', 'type', 'employee_id', 'date_from', 'date_to',
            'active_only', 'sort_by', 'sort_dir', 'per_page',
        ]));

        return $this->success([
            'items' => OrderResource::collection($orders->items()),
            'pagination' => [
                'current_page' => $orders->currentPage(),
                'last_page' => $orders->lastPage(),
                'per_page' => $orders->perPage(),
                'total' => $orders->total(),
            ],
        ]);
    }

    public function store(StoreOrderRequest $request): JsonResponse
    {
        $order = $this->orderService->create($request->validated(), $request->user());

        return $this->success(new OrderResource($order), 'تم إنشاء الطلب بنجاح', 201);
    }

    public function show(Order $order): JsonResponse
    {
        $this->authorize('view', $order);

        return $this->success(new OrderResource(
            $order->load(['items', 'customer', 'employee', 'deliveryArea', 'invoice'])
        ));
    }

    public function updateStatus(UpdateOrderStatusRequest $request, Order $order): JsonResponse
    {
        $this->authorize('updateStatus', $order);

        $order = $this->orderService->updateStatus($order, $request->validated('status'));

        return $this->success(new OrderResource($order), 'تم تحديث حالة الطلب بنجاح');
    }

    public function destroy(Order $order): JsonResponse
    {
        $this->authorize('delete', $order);

        $this->orderService->delete($order);

        return $this->success(message: 'تم حذف الطلب بنجاح');
    }

    /**
     * GET /api/orders/kitchen-board
     * Active (non-final-state) orders grouped by status, for a kitchen
     * display screen that polls this endpoint.
     */
    public function kitchenBoard(): JsonResponse
    {
        $orders = Order::with(['items'])
            ->active()
            ->orderBy('created_at')
            ->get()
            ->groupBy('status');

        return $this->success([
            'pending' => OrderResource::collection($orders->get('pending', collect())),
            'preparing' => OrderResource::collection($orders->get('preparing', collect())),
            'ready' => OrderResource::collection($orders->get('ready', collect())),
        ]);
    }
}
