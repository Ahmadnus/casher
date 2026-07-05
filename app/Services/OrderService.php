<?php

namespace App\Services;

use App\Events\OrderCreated;
use App\Events\OrderStatusChanged;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\User;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class OrderService
{
    public function paginate(array $filters = []): LengthAwarePaginator
    {
        $query = Order::query()->with(['customer', 'employee', 'deliveryArea']);

        $query->status($filters['status'] ?? null);
        $query->type($filters['type'] ?? null);

        if (! empty($filters['employee_id'])) {
            $query->where('employee_id', $filters['employee_id']);
        }

        if (! empty($filters['date_from'])) {
            $query->whereDate('created_at', '>=', $filters['date_from']);
        }

        if (! empty($filters['date_to'])) {
            $query->whereDate('created_at', '<=', $filters['date_to']);
        }

        if (! empty($filters['active_only'])) {
            $query->active();
        }

        $query->orderBy($filters['sort_by'] ?? 'created_at', $filters['sort_dir'] ?? 'desc');

        return $query->paginate($filters['per_page'] ?? 20);
    }

    /**
     * @throws ValidationException
     */
    public function create(array $data, User $employee): Order
    {
        return DB::transaction(function () use ($data, $employee) {
            $menuItems = MenuItem::whereIn('id', collect($data['items'])->pluck('menu_item_id'))
                ->get()
                ->keyBy('id');

            foreach ($data['items'] as $line) {
                $item = $menuItems->get($line['menu_item_id']);
                if (! $item || ! $item->is_available) {
                    throw ValidationException::withMessages([
                        'items' => ["الصنف \"{$item?->name}\" غير متوفر حالياً"],
                    ]);
                }
            }

            $order = Order::create([
                'order_number' => $this->generateOrderNumber(),
                'customer_id' => $data['customer_id'] ?? null,
                'employee_id' => $employee->id,
                'delivery_area_id' => $data['delivery_area_id'] ?? null,
                'type' => $data['type'],
                'status' => 'pending',
                'table_number' => $data['table_number'] ?? null,
                'notes' => $data['notes'] ?? null,
            ]);

            foreach ($data['items'] as $line) {
                $item = $menuItems->get($line['menu_item_id']);
                $order->items()->create([
                    'menu_item_id' => $item->id,
                    'name' => $item->name,
                    'price' => $item->price,
                    'quantity' => $line['quantity'],
                    'total' => $item->price * $line['quantity'],
                    'notes' => $line['notes'] ?? null,
                ]);
            }

            $order->load(['items', 'customer', 'employee', 'deliveryArea']);

            OrderCreated::dispatch($order);

            return $order;
        });
    }

    /**
     * @throws ValidationException
     */
    public function updateStatus(Order $order, string $newStatus): Order
    {
        if (! $order->canTransitionTo($newStatus)) {
            throw ValidationException::withMessages([
                'status' => ["لا يمكن تغيير حالة الطلب من \"{$order->status}\" إلى \"{$newStatus}\""],
            ]);
        }

        $previousStatus = $order->status;

        $timestampField = match ($newStatus) {
            'preparing' => 'preparing_at',
            'ready' => 'ready_at',
            'delivered' => 'delivered_at',
            'cancelled' => 'cancelled_at',
            default => null,
        };

        $order->update(array_filter([
            'status' => $newStatus,
            $timestampField => $timestampField ? now() : null,
        ]));

        OrderStatusChanged::dispatch($order->fresh(), $previousStatus);

        return $order->fresh(['items', 'customer', 'employee', 'deliveryArea']);
    }

    public function delete(Order $order): void
    {
        $order->delete();
    }

    protected function generateOrderNumber(): string
    {
        $prefix = 'ORD-'.now()->format('Ymd').'-';
        $todayCount = Order::whereDate('created_at', today())->count() + 1;

        $number = $prefix.str_pad((string) $todayCount, 4, '0', STR_PAD_LEFT);

        // Extremely defensive: guarantee uniqueness even under race
        // conditions by falling back to a random suffix on collision.
        while (Order::where('order_number', $number)->exists()) {
            $number = $prefix.strtoupper(Str::random(4));
        }

        return $number;
    }
}
