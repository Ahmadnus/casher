<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Invoice\MarkInvoicePaidRequest;
use App\Http\Requests\Invoice\StoreInvoiceRequest;
use App\Http\Resources\InvoiceResource;
use App\Http\Resources\RestaurantSettingResource;
use App\Models\Invoice;
use App\Services\InvoiceService;
use App\Services\SettingsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InvoiceController extends Controller
{
    public function __construct(
        protected InvoiceService $invoiceService,
        protected SettingsService $settingsService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $this->authorize('viewAny', Invoice::class);

        $invoices = $this->invoiceService->paginate($request->only([
            'search', 'status', 'payment_method', 'date_from', 'date_to',
            'employee_id', 'delivery_area_id', 'order_type', 'sort_by', 'sort_dir', 'per_page',
        ]));

        return $this->success([
            'items' => InvoiceResource::collection($invoices->items()),
            'pagination' => [
                'current_page' => $invoices->currentPage(),
                'last_page' => $invoices->lastPage(),
                'per_page' => $invoices->perPage(),
                'total' => $invoices->total(),
            ],
        ]);
    }

    public function store(StoreInvoiceRequest $request): JsonResponse
    {
        $invoice = $this->invoiceService->create($request->validated(), $request->user());

        return $this->success(new InvoiceResource($invoice), 'تم إصدار الفاتورة بنجاح', 201);
    }

    public function show(Invoice $invoice): JsonResponse
    {
        $this->authorize('view', $invoice);

        return $this->success(new InvoiceResource(
            $invoice->load(['items', 'customer', 'employee', 'deliveryArea'])
        ));
    }

    public function markPaid(MarkInvoicePaidRequest $request, Invoice $invoice): JsonResponse
    {
        $invoice = $this->invoiceService->markPaid($invoice, $request->validated('payment_method'));

        return $this->success(new InvoiceResource($invoice), 'تم تأكيد الدفع بنجاح');
    }

    public function refund(Invoice $invoice): JsonResponse
    {
        $this->authorize('refund', $invoice);

        $invoice = $this->invoiceService->refund($invoice);

        return $this->success(new InvoiceResource($invoice), 'تم استرجاع الفاتورة');
    }

    public function cancel(Invoice $invoice): JsonResponse
    {
        $this->authorize('update', $invoice);

        $invoice = $this->invoiceService->cancel($invoice);

        return $this->success(new InvoiceResource($invoice), 'تم إلغاء الفاتورة');
    }

    public function destroy(Invoice $invoice): JsonResponse
    {
        $this->authorize('delete', $invoice);

        $this->invoiceService->delete($invoice);

        return $this->success(message: 'تم حذف الفاتورة بنجاح');
    }

    /**
     * GET /api/invoices/{invoice}/print-data
     *
     * Returns every field the Flutter PrinterService needs to render a
     * thermal receipt locally over Bluetooth: restaurant identity +
     * the full invoice payload in one call, so the app does not need a
     * second request to /api/settings before printing.
     */
    public function printData(Invoice $invoice): JsonResponse
    {
        $this->authorize('print', $invoice);

        $invoice->load(['items', 'customer', 'employee', 'deliveryArea']);

        return $this->success([
            'restaurant' => new RestaurantSettingResource($this->settingsService->current()),
            'invoice' => new InvoiceResource($invoice),
        ]);
    }
}
