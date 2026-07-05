<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->string('order_number')->unique();
            $table->foreignId('customer_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('employee_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('delivery_area_id')->nullable()->constrained()->nullOnDelete();

            $table->enum('type', ['dine_in', 'takeaway', 'delivery'])->default('takeaway');
            $table->enum('status', ['pending', 'preparing', 'ready', 'delivered', 'cancelled'])
                ->default('pending');

            $table->string('table_number', 20)->nullable();
            $table->text('notes')->nullable();

            $table->timestamp('preparing_at')->nullable();
            $table->timestamp('ready_at')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();

            $table->softDeletes();
            $table->timestamps();

            $table->index(['status']);
            $table->index(['type']);
            $table->index(['employee_id', 'status']);
            $table->index(['created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
