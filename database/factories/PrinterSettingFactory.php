<?php

namespace Database\Factories;

use App\Models\PrinterSetting;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\PrinterSetting>
 */
class PrinterSettingFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => fake()->word().' Printer',
            'type' => fake()->randomElement(PrinterSetting::TYPES),
            'device_identifier' => strtoupper(fake()->regexify('[0-9A-F]{4}:[0-9A-F]{4}')),
            'is_active' => true,
            'is_default' => false,
        ];
    }
}
