<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Settings\UpdateRestaurantSettingsRequest;
use App\Http\Resources\RestaurantSettingResource;
use App\Services\SettingsService;
use Illuminate\Http\JsonResponse;

class SettingsController extends Controller
{
    public function __construct(protected SettingsService $settingsService) {}

    public function show(): JsonResponse
    {
        return $this->success(new RestaurantSettingResource($this->settingsService->current()));
    }

    public function update(UpdateRestaurantSettingsRequest $request): JsonResponse
    {
        $settings = $this->settingsService->update($request->validated());

        return $this->success(new RestaurantSettingResource($settings), 'تم تحديث إعدادات المطعم بنجاح');
    }
}
