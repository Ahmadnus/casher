<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\MenuItem;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class CategoryMenuSeeder extends Seeder
{
    public function run(): void
    {
        $data = [
            'برجر' => [
                ['name' => 'برجر كلاسيك', 'price' => 35.0, 'description' => 'برجر لحم طازج مع جبنة وخس وطماطم'],
                ['name' => 'برجر دبل', 'price' => 55.0, 'description' => 'قطعتين لحم مع جبنة مزدوجة'],
            ],
            'بيتزا' => [
                ['name' => 'بيتزا مارغريتا', 'price' => 45.0, 'description' => 'صلصة طماطم مع جبنة موزاريلا'],
                ['name' => 'بيتزا دجاج', 'price' => 55.0, 'description' => 'دجاج مشوي مع فلفل وبصل'],
            ],
            'شاورما' => [
                ['name' => 'شاورما دجاج', 'price' => 25.0, 'description' => 'شاورما دجاج مع صلصة ثوم'],
                ['name' => 'شاورما لحم', 'price' => 30.0, 'description' => 'شاورما لحم مع صلصة طحينة'],
            ],
            'مشروبات' => [
                ['name' => 'كولا', 'price' => 10.0, 'description' => null],
                ['name' => 'عصير برتقال', 'price' => 15.0, 'description' => null],
            ],
            'إضافات' => [
                ['name' => 'بطاطس مقلية', 'price' => 15.0, 'description' => null],
                ['name' => 'سلطة خضراء', 'price' => 12.0, 'description' => null],
            ],
        ];

        $categoryOrder = 1;

        foreach ($data as $categoryName => $items) {

            $category = Category::firstOrCreate(
                ['slug' => Str::slug($categoryName)],
                [
                    'name' => $categoryName,
                    'is_active' => true,
                    'sort_order' => $categoryOrder++
                ]
            );

            foreach ($items as $itemIndex => $item) {

                MenuItem::firstOrCreate(
                    ['slug' => Str::slug($item['name'])],
                    [
                        'category_id' => $category->id,
                        'name' => $item['name'],
                        'description' => $item['description'],
                        'price' => $item['price'],
                        'is_available' => true,
                        'sort_order' => $itemIndex + 1
                    ]
                );
            }
        }
    }
}