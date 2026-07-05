<?php

namespace App\Policies;

use App\Models\DeliveryArea;
use App\Models\User;

class DeliveryAreaPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->can('delivery-areas.view');
    }

    public function view(User $user, DeliveryArea $deliveryArea): bool
    {
        return $user->can('delivery-areas.view');
    }

    public function create(User $user): bool
    {
        return $user->can('delivery-areas.create');
    }

    public function update(User $user, DeliveryArea $deliveryArea): bool
    {
        return $user->can('delivery-areas.update');
    }

    public function delete(User $user, DeliveryArea $deliveryArea): bool
    {
        return $user->can('delivery-areas.delete');
    }
}
