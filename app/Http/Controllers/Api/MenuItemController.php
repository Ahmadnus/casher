<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\MenuItem\StoreMenuItemRequest;
use App\Http\Requests\MenuItem\UpdateMenuItemRequest;
use App\Http\Resources\MenuItemResource;
use App\Models\MenuItem;
use App\Services\MenuItemService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MenuItemController extends Controller
{
    public function __construct(protected MenuItemService $menuItemService) {}

    public function index(Request $request): JsonResponse
    {
        $this->authorize('viewAny', MenuItem::class);

        $items = $this->menuItemService->paginate($request->only([
            'search', 'category_id', 'is_available', 'per_page',
        ]));

        return $this->success([
            'items' => MenuItemResource::collection($items->items()),
            'pagination' => [
                'current_page' => $items->currentPage(),
                'last_page' => $items->lastPage(),
                'per_page' => $items->perPage(),
                'total' => $items->total(),
            ],
        ]);
    }

    public function available(Request $request): JsonResponse
    {
        $items = $this->menuItemService->availableList(
            $request->integer('category_id') ?: null
        );

        return $this->success(MenuItemResource::collection($items));
    }

    public function store(StoreMenuItemRequest $request): JsonResponse
    {
        $item = $this->menuItemService->create($request->validated());

        return $this->success(new MenuItemResource($item), 'تمت إضافة الصنف بنجاح', 201);
    }

    public function show(MenuItem $menuItem): JsonResponse
    {
        $this->authorize('view', $menuItem);

        return $this->success(new MenuItemResource($menuItem->load('category')));
    }

    public function update(UpdateMenuItemRequest $request, MenuItem $menuItem): JsonResponse
    {
        $menuItem = $this->menuItemService->update($menuItem, $request->validated());

        return $this->success(new MenuItemResource($menuItem), 'تم تحديث الصنف بنجاح');
    }

    public function toggleAvailability(MenuItem $menuItem): JsonResponse
    {
        $this->authorize('update', $menuItem);

        $menuItem = $this->menuItemService->toggleAvailability($menuItem);

        return $this->success(new MenuItemResource($menuItem));
    }

    public function destroy(MenuItem $menuItem): JsonResponse
    {
        $this->authorize('delete', $menuItem);

        $this->menuItemService->delete($menuItem);

        return $this->success(message: 'تم حذف الصنف بنجاح');
    }
}
