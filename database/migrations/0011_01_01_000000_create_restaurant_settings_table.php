<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('restaurant_settings', function (Blueprint $table) {
            $table->id();
            $table->string('name')->default('Restaurant');
            $table->string('currency', 10)->default('JOD');
            $table->string('currency_symbol', 10)->default('د.أ');
            $table->text('address')->nullable();
            $table->string('phone')->nullable();
            $table->decimal('tax_rate', 5, 2)->default(0);
            $table->string('theme', 30)->default('dark');
            $table->text('receipt_header')->nullable();
            $table->text('receipt_footer')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('restaurant_settings');
    }
};
