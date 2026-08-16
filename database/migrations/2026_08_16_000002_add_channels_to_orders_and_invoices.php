<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Extends the order-type enums with the two third-party channels and links
 * every order/invoice to its channel row.
 *
 * Deliberately keeps BOTH `order_type` (string enum) and `channel_id` (FK):
 *   - order_type stays the reporting/grouping column, so ReportService,
 *     the existing indexes and the Flutter client need no rewrite.
 *   - channel_id is the config join, for commission + per-channel pricing.
 * ChannelService keeps the two in sync on write.
 */
return new class extends Migration
{
    public function up(): void
    {
        $types = ['dine_in', 'takeaway', 'delivery', 'coffee_shop', 'talabaty', 'eshyai'];

        Schema::table('orders', function (Blueprint $table) use ($types) {
            $table->enum('type', $types)->default('takeaway')->change();

            $table->foreignId('channel_id')->nullable()->after('delivery_area_id')
                ->constrained('channels')->nullOnDelete();

            // Aggregator's own order reference, shown on the ticket so staff
            // can match a POS order to the platform's app/tablet.
            $table->string('external_reference', 60)->nullable()->after('table_number');

            $table->index(['channel_id', 'status']);
            $table->index(['external_reference']);
        });

        Schema::table('invoices', function (Blueprint $table) use ($types) {
            $table->enum('order_type', $types)->default('takeaway')->change();

            $table->foreignId('channel_id')->nullable()->after('delivery_area_id')
                ->constrained('channels')->nullOnDelete();

            $table->string('external_reference', 60)->nullable()->after('table_number');

            // Commission is SNAPSHOTTED at invoice time, exactly like the
            // customer/price snapshot fields already on this table. Changing
            // a channel's rate later must never rewrite historical revenue.
            $table->decimal('commission_rate', 5, 2)->default(0)->after('total');
            $table->decimal('commission_amount', 10, 2)->default(0)->after('commission_rate');
            $table->decimal('net_total', 10, 2)->default(0)->after('commission_amount');

            // Composite index for the per-channel reporting queries
            // (paid invoices for a channel within a date range).
            $table->index(['channel_id', 'status', 'created_at'], 'invoices_channel_report_index');
            $table->index(['order_type', 'status', 'created_at'], 'invoices_type_report_index');
        });

        // Backfill: link every existing row to its channel by code, and treat
        // historical revenue as fully net (no commission was ever charged).
        foreach (DB::table('channels')->pluck('id', 'code') as $code => $id) {
            DB::table('orders')->where('type', $code)->update(['channel_id' => $id]);
            DB::table('invoices')->where('order_type', $code)->update(['channel_id' => $id]);
        }

        DB::table('invoices')->update(['net_total' => DB::raw('total')]);
    }

    public function down(): void
    {
        $types = ['dine_in', 'takeaway', 'delivery', 'coffee_shop'];

        Schema::table('invoices', function (Blueprint $table) {
            $table->dropIndex('invoices_channel_report_index');
            $table->dropIndex('invoices_type_report_index');
            $table->dropConstrainedForeignId('channel_id');
            $table->dropColumn(['external_reference', 'commission_rate', 'commission_amount', 'net_total']);
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->dropIndex(['channel_id', 'status']);
            $table->dropIndex(['external_reference']);
            $table->dropConstrainedForeignId('channel_id');
            $table->dropColumn('external_reference');
        });

        // Rows on the removed channels would violate the narrowed enum.
        DB::table('orders')->whereIn('type', ['talabaty', 'eshyai'])->update(['type' => 'delivery']);
        DB::table('invoices')->whereIn('order_type', ['talabaty', 'eshyai'])->update(['order_type' => 'delivery']);

        Schema::table('orders', function (Blueprint $table) use ($types) {
            $table->enum('type', $types)->default('takeaway')->change();
        });

        Schema::table('invoices', function (Blueprint $table) use ($types) {
            $table->enum('order_type', $types)->default('takeaway')->change();
        });
    }
};
