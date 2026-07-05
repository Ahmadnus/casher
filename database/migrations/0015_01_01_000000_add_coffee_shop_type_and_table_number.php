<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->enum('type', ['dine_in', 'takeaway', 'delivery', 'coffee_shop'])
                ->default('takeaway')->change();
        });

        Schema::table('invoices', function (Blueprint $table) {
            $table->enum('order_type', ['dine_in', 'takeaway', 'delivery', 'coffee_shop'])
                ->default('takeaway')->change();
            $table->string('table_number', 20)->nullable()->after('order_type');
        });
    }

    public function down(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->dropColumn('table_number');
            $table->enum('order_type', ['dine_in', 'takeaway', 'delivery'])
                ->default('takeaway')->change();
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->enum('type', ['dine_in', 'takeaway', 'delivery'])
                ->default('takeaway')->change();
        });
    }
};
