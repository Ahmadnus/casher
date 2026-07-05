<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('invoices', function (Blueprint $table) {
            $table->id();
            $table->string('invoice_number')->unique();

            $table->foreignId('order_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('customer_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('employee_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('delivery_area_id')->nullable()->constrained()->nullOnDelete();

            // Snapshot customer fields — invoices must remain accurate
            // historical records even if the Customer row changes later.
            $table->string('customer_name')->nullable();
            $table->string('customer_phone')->nullable();
            $table->text('delivery_address')->nullable();
            $table->text('notes')->nullable();

            $table->enum('order_type', ['dine_in', 'takeaway', 'delivery'])->default('takeaway');

            $table->decimal('subtotal', 10, 2)->default(0);
            $table->decimal('tax', 10, 2)->default(0);
            $table->decimal('discount', 10, 2)->default(0);
            $table->decimal('delivery_fee', 10, 2)->default(0);
            $table->decimal('total', 10, 2)->default(0);

            $table->enum('payment_method', ['cash', 'card', 'online'])->default('cash');
            $table->enum('status', ['unpaid', 'paid', 'refunded', 'cancelled'])->default('unpaid');
            $table->timestamp('paid_at')->nullable();

            $table->softDeletes();
            $table->timestamps();

            $table->index(['status']);
            $table->index(['payment_method']);
            $table->index(['employee_id', 'created_at']);
            $table->index(['delivery_area_id']);
            $table->index(['created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('invoices');
    }
};
