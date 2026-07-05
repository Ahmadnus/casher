<?php

namespace App\Services;

use App\Models\RestaurantSetting;
use Illuminate\Http\UploadedFile;

class SettingsService
{
    public function current(): RestaurantSetting
    {
        return RestaurantSetting::current();
    }

    public function update(array $data): RestaurantSetting
    {
        $settings = RestaurantSetting::current();

        $settings->update(collect($data)->except('logo')->toArray());

        if (! empty($data['logo']) && $data['logo'] instanceof UploadedFile) {
            $settings->clearMediaCollection('logo');
            $settings->addMedia($data['logo'])->toMediaCollection('logo');
        }

        return $settings->fresh();
    }
}
