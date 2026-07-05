<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PrinterSetting\StorePrinterSettingRequest;
use App\Http\Requests\PrinterSetting\UpdatePrinterSettingRequest;
use App\Http\Resources\PrinterSettingResource;
use App\Models\PrinterSetting;
use App\Services\PrinterSettingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PrinterSettingController extends Controller
{
    public function __construct(protected PrinterSettingService $printerSettingService) {}

    public function index(Request $request): JsonResponse
    {
        $this->authorize('viewAny', PrinterSetting::class);

        return $this->success(
            PrinterSettingResource::collection(
                $this->printerSettingService->listByType($request->string('type')->value() ?: null)
            )
        );
    }

    public function store(StorePrinterSettingRequest $request): JsonResponse
    {
        $printer = $this->printerSettingService->create($request->validated());

        return $this->success(new PrinterSettingResource($printer), 'تمت إضافة الطابعة بنجاح', 201);
    }

    public function show(PrinterSetting $printerSetting): JsonResponse
    {
        $this->authorize('view', $printerSetting);

        return $this->success(new PrinterSettingResource($printerSetting));
    }

    public function update(UpdatePrinterSettingRequest $request, PrinterSetting $printerSetting): JsonResponse
    {
        $printerSetting = $this->printerSettingService->update($printerSetting, $request->validated());

        return $this->success(new PrinterSettingResource($printerSetting), 'تم تحديث إعدادات الطابعة بنجاح');
    }

    public function setDefault(PrinterSetting $printerSetting): JsonResponse
    {
        $this->authorize('update', $printerSetting);

        $printerSetting = $this->printerSettingService->setDefault($printerSetting);

        return $this->success(new PrinterSettingResource($printerSetting), 'تم تعيين الطابعة الافتراضية');
    }

    public function destroy(PrinterSetting $printerSetting): JsonResponse
    {
        $this->authorize('delete', $printerSetting);

        $this->printerSettingService->delete($printerSetting);

        return $this->success(message: 'تم حذف الطابعة بنجاح');
    }
}
