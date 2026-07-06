<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Every report query filters WHERE status = 'paid' AND a created_at
     * range, then aggregates. A composite index lets MySQL satisfy that
     * in one range scan instead of intersecting two single-column indexes.
     */
    public function up(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->index(['status', 'created_at'], 'invoices_status_created_at_index');
        });
    }

    public function down(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->dropIndex('invoices_status_created_at_index');
        });
    }
};
