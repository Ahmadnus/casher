<?php

namespace App\Services;

use App\Models\Category;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\UploadedFile;
use Illuminate\Pagination\LengthAwarePaginator;

class CategoryService
{
    public function paginate(array $filters = []): LengthAwarePaginator
    {
        $query = Category::query()->withCount('menuItems');

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
        return Category::active()->ordered()->get();
    }

    public function create(array $data): Category
    {
        $category = Category::create(collect($data)->except('image')->toArray());

        if (! empty($data['image']) && $data['image'] instanceof UploadedFile) {
            $category->addMedia($data['image'])->toMediaCollection('image');
        }

        return $category;
    }

    public function update(Category $category, array $data): Category
    {
        $category->update(collect($data)->except('image')->toArray());

        if (! empty($data['image']) && $data['image'] instanceof UploadedFile) {
            $category->clearMediaCollection('image');
            $category->addMedia($data['image'])->toMediaCollection('image');
        }

        return $category->fresh();
    }

    public function delete(Category $category): void
    {
        $category->delete();
    }
}
