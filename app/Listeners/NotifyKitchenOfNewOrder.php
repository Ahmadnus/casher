<?php

namespace App\Listeners;

use App\Events\OrderCreated;
use App\Models\User;
use App\Notifications\NewOrderNotification;
use Illuminate\Contracts\Queue\ShouldQueue;

class NotifyKitchenOfNewOrder implements ShouldQueue
{
    public function handle(OrderCreated $event): void
    {
        $kitchenStaff = User::role('kitchen')->active()->get();

        foreach ($kitchenStaff as $staff) {
            $staff->notify(new NewOrderNotification($event->order));
        }
    }
}
