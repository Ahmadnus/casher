<?php

namespace App\Policies;

use App\Models\User;

class EmployeePolicy
{
    public function viewAny(User $user): bool
    {
        return $user->can('employees.view');
    }

    public function view(User $user, User $employee): bool
    {
        return $user->can('employees.view') || $user->id === $employee->id;
    }

    public function create(User $user): bool
    {
        return $user->can('employees.create');
    }

    public function update(User $user, User $employee): bool
    {
        return $user->can('employees.update') || $user->id === $employee->id;
    }

    public function delete(User $user, User $employee): bool
    {
        return $user->can('employees.delete') && $user->id !== $employee->id;
    }

    public function toggleActive(User $user, User $employee): bool
    {
        return $user->can('employees.update') && $user->id !== $employee->id;
    }
}
