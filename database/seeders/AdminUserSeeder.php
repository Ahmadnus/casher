<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::firstOrCreate(
            ['username' => 'admin'],
            [
                'name' => 'المدير العام',
                'email' => 'admin@restaurant.local',
                'password' => 'Admin@123',
                'phone' => '0700000000',
                'pin' => '0000',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );

        if (! $admin->hasRole('super_admin')) {
            $admin->assignRole('super_admin');
        }

        $manager = User::firstOrCreate(
            ['username' => 'manager'],
            [
                'name' => 'مدير الفرع',
                'email' => 'manager@restaurant.local',
                'password' => 'Manager@123',
                'phone' => '0700000001',
                'pin' => '1111',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );
        if (! $manager->hasRole('manager')) {
            $manager->assignRole('manager');
        }

        $cashier = User::firstOrCreate(
            ['username' => 'cashier'],
            [
                'name' => 'الكاشير',
                'email' => 'cashier@restaurant.local',
                'password' => 'Cashier@123',
                'phone' => '0700000002',
                'pin' => '2222',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );
        if (! $cashier->hasRole('cashier')) {
            $cashier->assignRole('cashier');
        }

        $kitchen = User::firstOrCreate(
            ['username' => 'kitchen'],
            [
                'name' => 'المطبخ',
                'email' => 'kitchen@restaurant.local',
                'password' => 'Kitchen@123',
                'phone' => '0700000003',
                'pin' => '3333',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );
        if (! $kitchen->hasRole('kitchen')) {
            $kitchen->assignRole('kitchen');
        }

        $delivery = User::firstOrCreate(
            ['username' => 'delivery'],
            [
                'name' => 'موظف التوصيل',
                'email' => 'delivery@restaurant.local',
                'password' => 'Delivery@123',
                'phone' => '0700000004',
                'pin' => '4444',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );
        if (! $delivery->hasRole('delivery')) {
            $delivery->assignRole('delivery');
        }

        $waiter = User::firstOrCreate(
            ['username' => 'waiter'],
            [
                'name' => 'موظف الصالة',
                'email' => 'waiter@restaurant.local',
                'password' => 'Waiter@123',
                'phone' => '0700000005',
                'pin' => '5555',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );
        if (! $waiter->hasRole('waiter')) {
            $waiter->assignRole('waiter');
        }
    }
}
