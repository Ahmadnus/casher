<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Artisan;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class RolePermissionSeeder extends Seeder
{
    protected array $modules = [
        'employees', 'customers', 'categories', 'menu-items', 'delivery-areas',
        'orders', 'invoices', 'reports', 'settings', 'printer-settings', 'dashboard',
    ];

    protected array $actions = ['view', 'create', 'update', 'delete'];

    public function run(): void
    {
        Artisan::call('permission:cache-reset');

        $permissions = [];
        foreach ($this->modules as $module) {
            foreach ($this->actions as $action) {
                $permissions[] = "{$module}.{$action}";
            }
        }
        $permissions[] = 'invoices.refund';
        $permissions[] = 'invoices.print';
        $permissions[] = 'orders.update-status';
        $permissions[] = 'reports.export';

        foreach ($permissions as $permission) {
            Permission::firstOrCreate(['name' => $permission, 'guard_name' => 'web']);
        }

        $superAdmin = Role::firstOrCreate(['name' => 'super_admin', 'guard_name' => 'web']);
        $superAdmin->syncPermissions(Permission::all());

        $admin = Role::firstOrCreate(['name' => 'admin', 'guard_name' => 'web']);
        $admin->syncPermissions(Permission::all());

        $manager = Role::firstOrCreate(['name' => 'manager', 'guard_name' => 'web']);
        $manager->syncPermissions([
            'customers.view', 'customers.create', 'customers.update',
            'categories.view', 'categories.create', 'categories.update',
            'menu-items.view', 'menu-items.create', 'menu-items.update',
            'delivery-areas.view', 'delivery-areas.create', 'delivery-areas.update',
            'orders.view', 'orders.create', 'orders.update', 'orders.update-status',
            'invoices.view', 'invoices.create', 'invoices.update', 'invoices.print',
            'reports.view', 'reports.export',
            'dashboard.view',
            'printer-settings.view', 'printer-settings.update',
            'employees.view',
        ]);

        $cashier = Role::firstOrCreate(['name' => 'cashier', 'guard_name' => 'web']);
        $cashier->syncPermissions([
            'customers.view', 'customers.create', 'customers.update',
            'categories.view',
            'menu-items.view',
            'delivery-areas.view',
            'orders.view', 'orders.create', 'orders.update-status',
            // invoices.update is what MarkInvoicePaidRequest authorizes on:
            // the cashier is the role that collects payment on pending
            // orders, so it must be able to mark invoices paid/refund.
            'invoices.view', 'invoices.create', 'invoices.update',
            'invoices.refund', 'invoices.print',
            'dashboard.view',
            'printer-settings.view', 'printer-settings.update',
        ]);

        $kitchen = Role::firstOrCreate(['name' => 'kitchen', 'guard_name' => 'web']);
        $kitchen->syncPermissions([
            'orders.view', 'orders.update-status',
            'menu-items.view',
        ]);

        // Floor waiter (موظف الصالة): builds the cart and issues the
        // invoice for dine-in/coffee-shop customers, but does not collect
        // payment — mark-paid/refund/print stay cashier-only.
        $waiter = Role::firstOrCreate(['name' => 'waiter', 'guard_name' => 'web']);
        $waiter->syncPermissions([
            'customers.view', 'customers.create',
            'categories.view',
            'menu-items.view',
            'delivery-areas.view',
            'invoices.view', 'invoices.create',
        ]);

        $delivery = Role::firstOrCreate(['name' => 'delivery', 'guard_name' => 'web']);
        $delivery->syncPermissions([
            'orders.view', 'orders.update-status',
            'delivery-areas.view',
            'invoices.view',
        ]);
    }
}
