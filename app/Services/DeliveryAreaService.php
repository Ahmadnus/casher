<?php

namespace App\Services;

use App\Models\DeliveryArea;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Pagination\LengthAwarePaginator;

class DeliveryAreaService
{
    public function paginate(array $filters = []): LengthAwarePaginator
    {
        $query = DeliveryArea::query();

        if (! empty($filters['search'])) {
            $query->where('name', 'like', "%{$filters['search']}%");
        }

        if (isset($filters['is_active'])) {
            $query->where('is_active', filter_var($filters['is_active'], FILTER_VALIDATE_BOOLEAN));
        }

        $query->ordered();

        return $query->paginate($filters['per_page'] ?? 50);
    }

    public function activeList(): Collection
    {
        return DeliveryArea::active()->ordered()->get();
    }

    public function create(array $data): DeliveryArea
    {
        return DeliveryArea::create($data);
    }

    public function update(DeliveryArea $area, array $data): DeliveryArea
    {
        $area->update($data);

        return $area->fresh();
    }

    public function toggleActive(DeliveryArea $area): DeliveryArea
    {
        $area->update(['is_active' => ! $area->is_active]);

        return $area->fresh();
    }

    public function delete(DeliveryArea $area): void
    {
        $area->delete();
    }
}
