<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\MenuItem;
use App\Services\CategoryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class CategoryIntegrityTest extends TestCase
{
    use RefreshDatabase;

    public function test_cannot_delete_category_that_has_items(): void
    {
        $category = Category::factory()->create();
        MenuItem::factory()->create(['category_id' => $category->id]);

        $this->expectException(ValidationException::class);
        app(CategoryService::class)->delete($category);

        $this->assertDatabaseHas('categories', ['id' => $category->id, 'deleted_at' => null]);
    }

    public function test_can_delete_empty_category(): void
    {
        $category = Category::factory()->create();

        app(CategoryService::class)->delete($category);

        $this->assertSoftDeleted('categories', ['id' => $category->id]);
    }

    public function test_recreating_category_after_delete_does_not_collide_on_slug(): void
    {
        $first = app(CategoryService::class)->create(['name' => 'Drinks']);
        app(CategoryService::class)->delete($first);

        // Must not throw a unique-constraint error on the reused slug.
        $second = app(CategoryService::class)->create(['name' => 'Drinks']);

        $this->assertNotSame($first->slug, $second->slug);
        $this->assertDatabaseHas('categories', ['id' => $second->id]);
    }

    public function test_recreating_menu_item_after_delete_does_not_collide_on_slug(): void
    {
        $category = Category::factory()->create();
        $first = MenuItem::create(['category_id' => $category->id, 'name' => 'Cola', 'price' => 2]);
        $first->delete();

        $second = MenuItem::create(['category_id' => $category->id, 'name' => 'Cola', 'price' => 2]);

        $this->assertNotSame($first->slug, $second->slug);
    }
}
