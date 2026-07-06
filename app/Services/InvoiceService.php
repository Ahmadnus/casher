<?php

namespace App\Services;

use App\Models\Invoice;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\User;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class InvoiceService
{
    public function paginate(array $filters = []): LengthAwarePaginator
    {
        $query = Invoice::query()->with(['items', 'customer', 'employee', 'deliveryArea']);

        if (! empty($filters['search'])) {
            $query->search($filters['search']);
        }

        $query->status($filters['status'] ?? null);
        $query->paymentMethod($filters['payment_method'] ?? null);
        $query->betweenDates($filters['date_from'] ?? null, $filters['date_to'] ?? null);

        if (! empty($filters['employee_id'])) {
            $query->where('employee_id', $filters['employee_id']);
        }

        if (! empty($filters['delivery_area_id'])) {
            $query->where('delivery_area_id', $filters['delivery_area_id']);
        }

        if (! empty($filters['order_type'])) {
            $query->where('order_type', $filters['order_type']);
        }

        $query->orderBy($filters['sort_by'] ?? 'created_at', $filters['sort_dir'] ?? 'desc');

        return $query->paginate($filters['per_page'] ?? 20);
    }

    /**
     * @throws ValidationException
     */
    public function create(array $data, User $employee): Invoice
    {
        return DB::transaction(function () use ($data, $employee) {
            $order = null;
            $lineItems = collect();

            if (! empty($data['order_id'])) {
                $order = Order::with('items')->findOrFail($data['order_id']);

                if ($order->invoice()->exists()) {
                    throw ValidationException::withMessages([
                        'order_id' => ['تم إصدار فاتورة لهذا الطلب مسبقاً'],
                    ]);
                }

                $lineItems = $order->items->map(fn ($item) => [
                    'menu_item_id' => $item->menu_item_id,
                    'name' => $item->name,
                    'price' => $item->price,
                    'quantity' => $item->quantity,
                    'total' => $item->total,
                ]);
            } else {
                $menuItems = MenuItem::whereIn('id', collect($data['items'])->pluck('menu_item_id'))
                    ->get()
                    ->keyBy('id');

                $lineItems = collect($data['items'])->map(function ($line) use ($menuItems) {
                    $item = $menuItems->get($line['menu_item_id']);

                    if (! $item) {
                        throw ValidationException::withMessages([
                            'items' => ['أحد الأصناف المحددة غير موجود'],
                        ]);
                    }

                    return [
                        'menu_item_id' => $item->id,
                        'name' => $item->name,
                        'price' => $item->price,
                        'quantity' => $line['quantity'],
                        'total' => $item->price * $line['quantity'],
                    ];
                });
            }

            $subtotal = $lineItems->sum('total');
            $tax = (float) ($data['tax'] ?? 0);
            $discount = (float) ($data['discount'] ?? 0);
            $deliveryFee = 0.0;

            if (($data['order_type'] ?? null) === 'delivery' && ! empty($data['delivery_area_id'])) {
                $deliveryFee = (float) \App\Models\DeliveryArea::findOrFail($data['delivery_area_id'])->delivery_fee;
            }

            $total = max(0, $subtotal + $tax + $deliveryFee - $discount);

            // Order lifecycle: a newly submitted order is an UNPAID pending
            // invoice by default; it becomes a finalized paid invoice only
            // when the cashier confirms payment (mark-paid endpoint).
            // Pass "paid": true to collect payment at issuance instead.
            $isPaid = (bool) ($data['paid'] ?? false);

            $invoice = Invoice::create([
                'invoice_number' => $this->generateInvoiceNumber(),
                'order_id' => $order?->id,
                'customer_id' => $data['customer_id'] ?? null,
                'employee_id' => $employee->id,
                'delivery_area_id' => $data['delivery_area_id'] ?? null,
                'customer_name' => $data['customer_name'] ?? null,
                'customer_phone' => $data['customer_phone'] ?? null,
                'delivery_address' => $data['delivery_address'] ?? null,
                'table_number' => $data['table_number'] ?? null,
                'notes' => $data['notes'] ?? null,
                'order_type' => $data['order_type'],
                'subtotal' => $subtotal,
                'tax' => $tax,
                'discount' => $discount,
                'delivery_fee' => $deliveryFee,
                'total' => $total,
                'payment_method' => $data['payment_method'],
                'status' => $isPaid ? 'paid' : 'unpaid',
                'paid_at' => $isPaid ? now() : null,
            ]);

            foreach ($lineItems as $line) {
                $invoice->items()->create($line);
            }

            return $invoice->load(['items', 'customer', 'employee', 'deliveryArea']);
        });
    }

    public function markPaid(Invoice $invoice, ?string $paymentMethod = null): Invoice
    {
        // State-machine guard: only an unpaid invoice can be paid. This
        // makes a double-tap on "تأكيد الدفع" idempotent (the 2nd request
        // is rejected instead of re-stamping paid_at) and blocks reviving
        // a refunded/cancelled invoice back into the sales figures.
        if ($invoice->status !== 'unpaid') {
            throw ValidationException::withMessages([
                'status' => ['لا يمكن تأكيد دفع فاتورة حالتها الحالية: '.$invoice->status],
            ]);
        }

        $invoice->update(array_filter([
            'status' => 'paid',
            'paid_at' => now(),
            'payment_method' => $paymentMethod,
        ]));

        return $invoice->fresh(['items', 'customer', 'employee', 'deliveryArea']);
    }

    public function refund(Invoice $invoice): Invoice
    {
        // Only a paid invoice represents money that can be given back.
        if ($invoice->status !== 'paid') {
            throw ValidationException::withMessages([
                'status' => ['لا يمكن استرجاع فاتورة غير مدفوعة'],
            ]);
        }

        $invoice->update(['status' => 'refunded']);

        return $invoice->fresh(['items', 'customer', 'employee', 'deliveryArea']);
    }

    public function cancel(Invoice $invoice): Invoice
    {
        // A paid invoice must be refunded, not silently cancelled, so
        // collected money is never dropped from the books.
        if (! in_array($invoice->status, ['unpaid'], true)) {
            throw ValidationException::withMessages([
                'status' => ['لا يمكن إلغاء فاتورة حالتها: '.$invoice->status],
            ]);
        }

        $invoice->update(['status' => 'cancelled']);

        return $invoice->fresh(['items', 'customer', 'employee', 'deliveryArea']);
    }

    public function delete(Invoice $invoice): void
    {
        $invoice->delete();
    }

    protected function generateInvoiceNumber(): string
    {
        $prefix = 'INV-'.now()->format('Ymd').'-';
        $todayCount = Invoice::whereDate('created_at', today())->count() + 1;

        $number = $prefix.str_pad((string) $todayCount, 4, '0', STR_PAD_LEFT);

        while (Invoice::where('invoice_number', $number)->exists()) {
            $number = $prefix.strtoupper(Str::random(4));
        }

        return $number;
    }
}
