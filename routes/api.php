<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\DeliveryAreaController;
use App\Http\Controllers\Api\EmployeeController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\MenuItemController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PrinterSettingController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\SettingsController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Routes here are automatically prefixed with /api and assigned the
| "api" middleware group (see bootstrap/app.php). Each module appends
| its own route group below as it is built, keeping this file as the
| single source of truth for the entire REST surface.
|
*/

Route::prefix('auth')->group(function () {
    // Rate limited to slow down brute-force credential/PIN guessing.
    Route::post('login', [AuthController::class, 'login'])
        ->middleware('throttle:10,1')
        ->name('auth.login');

    Route::post('forgot-password', [AuthController::class, 'forgotPassword'])
        ->middleware('throttle:5,1')
        ->name('auth.forgot-password');

    Route::post('reset-password', [AuthController::class, 'resetPassword'])
        ->middleware('throttle:5,1')
        ->name('auth.reset-password');

    Route::middleware(['auth.token', 'active'])->group(function () {
        Route::post('logout', [AuthController::class, 'logout'])->name('auth.logout');
        Route::post('logout-all', [AuthController::class, 'logoutAllDevices'])->name('auth.logout-all');
        Route::get('me', [AuthController::class, 'me'])->name('auth.me');
        Route::post('change-password', [AuthController::class, 'changePassword'])->name('auth.change-password');
    });
});

/*
|--------------------------------------------------------------------------
| Authenticated module routes are mounted below this line as each
| module is completed (Employees, Customers, Categories, Menu Items,
| Delivery Areas, Orders, Invoices, Reports, Settings, Printer
| Settings, Dashboard).
|--------------------------------------------------------------------------
*/

Route::middleware(['auth.token', 'active'])->group(function () {
    // ── Employees ──────────────────────────────────────────────
    Route::get('employees/roles', [EmployeeController::class, 'roles']);
    Route::patch('employees/{employee}/toggle-active', [EmployeeController::class, 'toggleActive']);
    Route::apiResource('employees', EmployeeController::class);

    // ── Customers ──────────────────────────────────────────────
    Route::get('customers/find-by-phone', [CustomerController::class, 'findByPhone']);
    Route::apiResource('customers', CustomerController::class);

    // ── Categories ─────────────────────────────────────────────
    Route::get('categories/active', [CategoryController::class, 'active']);
    Route::apiResource('categories', CategoryController::class);

    // ── Menu Items ─────────────────────────────────────────────
    Route::get('menu-items/available', [MenuItemController::class, 'available']);
    Route::patch('menu-items/{menuItem}/toggle-availability', [MenuItemController::class, 'toggleAvailability']);
    Route::apiResource('menu-items', MenuItemController::class);

    // ── Delivery Areas ─────────────────────────────────────────
    Route::get('delivery-areas/active', [DeliveryAreaController::class, 'active']);
    Route::patch('delivery-areas/{deliveryArea}/toggle-active', [DeliveryAreaController::class, 'toggleActive']);
    Route::apiResource('delivery-areas', DeliveryAreaController::class);

    // ── Orders ─────────────────────────────────────────────────
    Route::get('orders/kitchen-board', [OrderController::class, 'kitchenBoard']);
    Route::middleware('throttle:pos-write')->group(function () {
        Route::patch('orders/{order}/status', [OrderController::class, 'updateStatus']);
        Route::post('orders', [OrderController::class, 'store']);
    });
    Route::apiResource('orders', OrderController::class)->except(['update', 'store']);

    // ── Invoices ───────────────────────────────────────────────
    Route::get('invoices/{invoice}/print-data', [InvoiceController::class, 'printData']);
    Route::middleware('throttle:pos-write')->group(function () {
        Route::post('invoices', [InvoiceController::class, 'store']);
        Route::patch('invoices/{invoice}/mark-paid', [InvoiceController::class, 'markPaid']);
        Route::patch('invoices/{invoice}/refund', [InvoiceController::class, 'refund']);
        Route::patch('invoices/{invoice}/cancel', [InvoiceController::class, 'cancel']);
    });
    Route::apiResource('invoices', InvoiceController::class)->except(['update', 'store']);

    // ── Settings ───────────────────────────────────────────────
    Route::get('settings', [SettingsController::class, 'show']);
    Route::post('settings', [SettingsController::class, 'update']); // POST for multipart logo upload

    // ── Printer Settings ───────────────────────────────────────
    Route::patch('printer-settings/{printerSetting}/set-default', [PrinterSettingController::class, 'setDefault']);
    Route::apiResource('printer-settings', PrinterSettingController::class);

    // ── Dashboard ──────────────────────────────────────────────
    Route::get('dashboard', [DashboardController::class, 'index']);

    // ── Reports ────────────────────────────────────────────────
    Route::prefix('reports')->group(function () {
        Route::get('daily', [ReportController::class, 'daily']);
        Route::get('weekly', [ReportController::class, 'weekly']);
        Route::get('monthly', [ReportController::class, 'monthly']);
        Route::get('best-selling-items', [ReportController::class, 'bestSellingItems']);
        Route::get('sales-by-employee', [ReportController::class, 'salesByEmployee']);
        Route::get('sales-by-delivery-area', [ReportController::class, 'salesByDeliveryArea']);
        Route::get('sales-by-category', [ReportController::class, 'salesByCategory']);
    });

    // ── Notifications ──────────────────────────────────────────
    Route::prefix('notifications')->group(function () {
        Route::get('/', [NotificationController::class, 'index']);
        Route::patch('mark-all-read', [NotificationController::class, 'markAllAsRead']);
        Route::patch('{notification}/mark-read', [NotificationController::class, 'markAsRead']);
        Route::delete('{notification}', [NotificationController::class, 'destroy']);
    });
});
