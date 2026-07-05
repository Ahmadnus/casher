<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\DeliveryArea\StoreDeliveryAreaRequest;
use App\Http\Requests\DeliveryArea\UpdateDeliveryAreaRequest;
use App\Http\Resources\DeliveryAreaResource;
use App\Models\DeliveryArea;
use App\Services\DeliveryAreaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeliveryAreaController extends Controller
{
    public function __construct(protected DeliveryAreaService $deliveryAreaService) {}

    public function index(Request $request): JsonResponse
    {
        $this->authorize('viewAny', DeliveryArea::class);

        $areas = $this->deliveryAreaService->paginate($request->only([
            'search', 'is_active', 'per_page',
        ]));

        return $this->success([
            'items' => DeliveryAreaResource::collection($areas->items()),
            'pagination' => [
                'current_page' => $areas->currentPage(),
                'last_page' => $areas->lastPage(),
                'per_page' => $areas->perPage(),
                'total' => $areas->total(),
            ],
        ]);
    }

    public function active(): JsonResponse
    {
        return $this->success(
            DeliveryAreaResource::collection($this->deliveryAreaService->activeList())
        );
    }

    public function store(StoreDeliveryAreaRequest $request): JsonResponse
    {
        $area = $this->deliveryAreaService->create($request->validated());

        return $this->success(new DeliveryAreaResource($area), 'تمت إضافة المنطقة بنجاح', 201);
    }

    public function show(DeliveryArea $deliveryArea): JsonResponse
    {
        $this->authorize('view', $deliveryArea);

        return $this->success(new DeliveryAreaResource($deliveryArea));
    }

    public function update(UpdateDeliveryAreaRequest $request, DeliveryArea $deliveryArea): JsonResponse
    {
        $deliveryArea = $this->deliveryAreaService->update($deliveryArea, $request->validated());

        return $this->success(new DeliveryAreaResource($deliveryArea), 'تم تحديث المنطقة بنجاح');
    }

    public function toggleActive(DeliveryArea $deliveryArea): JsonResponse
    {
        $this->authorize('update', $deliveryArea);

        $deliveryArea = $this->deliveryAreaService->toggleActive($deliveryArea);

        return $this->success(new DeliveryAreaResource($deliveryArea));
    }

    public function destroy(DeliveryArea $deliveryArea): JsonResponse
    {
        $this->authorize('delete', $deliveryArea);

        $this->deliveryAreaService->delete($deliveryArea);

        return $this->success(message: 'تم حذف المنطقة بنجاح');
    }
}
