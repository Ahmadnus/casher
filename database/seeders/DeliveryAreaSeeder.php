<?php

namespace Database\Seeders;

use App\Models\DeliveryArea;
use Illuminate\Database\Seeder;

class DeliveryAreaSeeder extends Seeder
{
    public function run(): void
    {
        $areas = [
            ['name' => 'دمشق', 'delivery_fee' => 1.5],
            ['name' => 'المزة', 'delivery_fee' => 2.0],
            ['name' => 'قدسيا', 'delivery_fee' => 2.5],
            ['name' => 'جرمانا', 'delivery_fee' => 2.5],
            ['name' => 'المالكي', 'delivery_fee' => 1.5],
            ['name' => 'باب توما', 'delivery_fee' => 1.0],
        ];

        foreach ($areas as $i => $area) {
            DeliveryArea::firstOrCreate(
                ['name' => $area['name']],
                ['delivery_fee' => $area['delivery_fee'], 'is_active' => true, 'sort_order' => $i]
            );
        }
    }
}
