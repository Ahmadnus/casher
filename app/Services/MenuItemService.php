<?php

namespace App\Services;

use App\Models\MenuItem;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\UploadedFile;
use Illuminate\Pagination\LengthAwarePaginator;

class MenuItemService
{
    public function paginate(array $filters = []): LengthAwarePaginator
    {
        $query = MenuItem::query()->with('category');

        if (! empty($filters['search'])) {
            $query->search($filters['search']);
        }

        if (! empty($filters['category_id'])) {
            $query->where('category_id', $filters['category_id']);
        }

        if (isset($filters['is_available'])) {
            $query->where('is_available', filter_var($filters['is_available'], FILTER_VALIDATE_BOOLEAN));
        }

        $query->ordered();

        return $query->paginate($filters['per_page'] ?? 50);
    }

    public function availableList(?int $categoryId = null): Collection
    {
        $query = MenuItem::query()->available()->with('category')->ordered();

        if ($categoryId) {
            $query->where('category_id', $categoryId);
        }

        return $query->get();
    }

    public function create(array $data): MenuItem
    {
        $item = MenuItem::create(collect($data)->except('image')->toArray());

        if (! empty($data['image']) && $data['image'] instanceof UploadedFile) {
            $item->addMedia($data['image'])->toMediaCollection('image');
        }

        return $item->load('category');
    }

    public function update(MenuItem $item, array $data): MenuItem
    {
        $item->update(collect($data)->except('image')->toArray());

        if (! empty($data['image']) && $data['image'] instanceof UploadedFile) {
            $item->clearMediaCollection('image');
            $item->addMedia($data['image'])->toMediaCollection('image');
        }

        return $item->fresh('category');
    }

    public function delete(MenuItem $item): void
    {
        $item->delete();
    }

    public function toggleAvailability(MenuItem $item): MenuItem
    {
        $item->update(['is_available' => ! $item->is_available]);

        return $item->fresh('category');
    }
}
