<?php

namespace App\Policies;

use App\Models\PrinterSetting;
use App\Models\User;

class PrinterSettingPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->can('printer-settings.view');
    }

    public function view(User $user, PrinterSetting $printerSetting): bool
    {
        return $user->can('printer-settings.view');
    }

    public function create(User $user): bool
    {
        return $user->can('printer-settings.create');
    }

    public function update(User $user, PrinterSetting $printerSetting): bool
    {
        return $user->can('printer-settings.update');
    }

    public function delete(User $user, PrinterSetting $printerSetting): bool
    {
        return $user->can('printer-settings.delete');
    }
}
