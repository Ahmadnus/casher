<?php

namespace Tests\Feature;

use App\Models\Invoice;
use App\Models\User;
use App\Services\InvoiceService;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class SecurityAuditTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
    }

    protected function tokenFor(User $user): string
    {
        return $user->createToken('test')->plainTextToken;
    }

    /** A low-privilege user must not escalate their own role via self-update. */
    public function test_waiter_cannot_escalate_own_role(): void
    {
        $waiter = User::factory()->create();
        $waiter->assignRole('waiter');

        $response = $this->withHeader('X-Auth-Token', $this->tokenFor($waiter))
            ->putJson("/api/employees/{$waiter->id}", [
                'name' => 'Still A Waiter',
                'role' => 'super_admin',
            ]);

        $response->assertStatus(422);
        $this->assertTrue($waiter->fresh()->hasRole('waiter'));
        $this->assertFalse($waiter->fresh()->hasRole('super_admin'));
    }

    /** A low-privilege user must not re-activate/deactivate via self-update. */
    public function test_waiter_cannot_change_own_active_status(): void
    {
        $waiter = User::factory()->create(['is_active' => true]);
        $waiter->assignRole('waiter');

        $response = $this->withHeader('X-Auth-Token', $this->tokenFor($waiter))
            ->putJson("/api/employees/{$waiter->id}", ['is_active' => false]);

        $response->assertStatus(422);
        $this->assertTrue($waiter->fresh()->is_active);
    }

    /** An admin CAN change roles — the guard must not block legitimate use. */
    public function test_admin_can_change_employee_role(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');
        $target = User::factory()->create();
        $target->assignRole('waiter');

        $response = $this->withHeader('X-Auth-Token', $this->tokenFor($admin))
            ->putJson("/api/employees/{$target->id}", ['role' => 'manager']);

        $response->assertStatus(200);
        $this->assertTrue($target->fresh()->hasRole('manager'));
    }

    /** Every protected endpoint must 401 without a token. */
    public function test_endpoints_reject_missing_token(): void
    {
        $this->getJson('/api/reports/daily')->assertStatus(401);
        $this->getJson('/api/employees')->assertStatus(401);
        $this->getJson('/api/invoices')->assertStatus(401);
    }

    public function test_endpoints_reject_invalid_token(): void
    {
        $this->withHeader('X-Auth-Token', 'garbage-token')
            ->getJson('/api/reports/daily')->assertStatus(401);
    }

    /** Cashier role must be able to confirm payment (lifecycle requirement). */
    public function test_cashier_can_mark_invoice_paid(): void
    {
        $cashier = User::factory()->create();
        $cashier->assignRole('cashier');

        $invoice = Invoice::factory()->unpaid()->create(['total' => 50]);

        $response = $this->withHeader('X-Auth-Token', $this->tokenFor($cashier))
            ->patchJson("/api/invoices/{$invoice->id}/mark-paid", [
                'payment_method' => 'cash',
            ]);

        $response->assertStatus(200);
        $this->assertSame('paid', $invoice->fresh()->status);
    }

    /** Double mark-paid must be rejected (idempotent, no double count). */
    public function test_cannot_mark_paid_twice(): void
    {
        $invoice = Invoice::factory()->create(['status' => 'paid', 'total' => 50]);

        $this->expectException(ValidationException::class);
        app(InvoiceService::class)->markPaid($invoice, 'cash');
    }

    /** A refunded invoice must not be revived back into sales. */
    public function test_cannot_refund_unpaid_invoice(): void
    {
        $invoice = Invoice::factory()->unpaid()->create(['total' => 50]);

        $this->expectException(ValidationException::class);
        app(InvoiceService::class)->refund($invoice);
    }
}
