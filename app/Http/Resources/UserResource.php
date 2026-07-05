<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\User
 */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'username' => $this->username,
            'email' => $this->email,
            'phone' => $this->phone,
            'avatar_url' => $this->avatar_url,
            'is_active' => $this->is_active,

            // Single primary role name, matching the Flutter EmployeeModel.role
            // string field ('admin' | 'manager' | 'cashier' | 'kitchen' | 'delivery').
            'role' => $this->getRoleNames()->first(),
            'roles' => $this->getRoleNames(),
            'permissions' => $this->when(
                $request->boolean('with_permissions'),
                fn () => $this->getAllPermissions()->pluck('name')
            ),

            'last_login_at' => $this->last_login_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}