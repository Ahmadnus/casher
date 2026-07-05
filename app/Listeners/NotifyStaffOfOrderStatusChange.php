<?php

namespace App\Listeners;

use App\Events\OrderStatusChanged;
use App\Models\User;
use App\Notifications\OrderStatusUpdatedNotification;
use Illuminate\Contracts\Queue\ShouldQueue;

class NotifyStaffOfOrderStatusChange implements ShouldQueue
{
    public function handle(OrderStatusChanged $event): void
    {
        // Cashiers and the assigned employee should know the kitchen
        // moved the order forward so the invoice can be printed/handed off.
        $recipients = User::role(['cashier', 'manager', 'admin', 'super_admin'])
            ->active()
            ->get()
            ->push($event->order->employee)
            ->unique('id');

        foreach ($recipients as $recipient) {
            $recipient->notify(new OrderStatusUpdatedNotification($event->order, $event->previousStatus));
        }
    }
}
