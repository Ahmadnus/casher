<?php

namespace App\Services;

use App\Models\Category;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\UploadedFile;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Validation\ValidationException;

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

    /**
     * @throws ValidationException
     */
    public function delete(Category $category): void
    {
        // category_id on menu_items is a non-nullable FK, so a category's
        // items cannot be "un-categorized". Block the delete while items
        // still reference it — the admin must move or remove them first.
        // This prevents orphaned products silently appearing in the POS.
        $itemCount = $category->menuItems()->count();

        if ($itemCount > 0) {
            throw ValidationException::withMessages([
                'category' => ["لا يمكن حذف الفئة لوجود {$itemCount} صنف مرتبط بها. انقل أو احذف الأصناف أولاً."],
            ]);
        }

        $category->delete();
    }
}
