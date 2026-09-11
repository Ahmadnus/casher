<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Adds the "Otlob" (third-party aggregator) and "Other" (catch-all) order
 * sources, so every order can be attributed to one of:
 *
 *   coffee_shop · talabaty (shown as "Talabat") · otlob · other
 *
 * plus the original dine_in / takeaway / delivery / eshyai channels, which
 * stay untouched so historical rows keep their real source.
 *
 * Existing orders/invoices are NOT rewritten: they already carry the
 * channel they were sold on (order_type / channel_id were backfilled by the
 * 2026_08_16 migration), and the enum default remains `takeaway`.
 */
return new class extends Migration
{
    public function up(): void
    {
        $types = ['dine_in', 'takeaway', 'delivery', 'coffee_shop', 'talabaty', 'eshyai', 'otlob', 'other'];

        Schema::table('orders', function (Blueprint $table) use ($types) {
            $table->enum('type', $types)->default('takeaway')->change();
        });

        Schema::table('invoices', function (Blueprint $table) use ($types) {
            $table->enum('order_type', $types)->default('takeaway')->change();
        });

        $now = now();

        $rows = [
            [
                'code' => 'otlob', 'name' => 'Otlob', 'name_ar' => 'أطلب',
                'invoice_prefix' => 'OTL', 'commission_rate' => 0, 'is_third_party' => true,
                'is_active' => true, 'sort_order' => 7,
                'created_at' => $now, 'updated_at' => $now,
            ],
            [
                'code' => 'other', 'name' => 'Other', 'name_ar' => 'أخرى',
                'invoice_prefix' => 'INV', 'commission_rate' => 0, 'is_third_party' => false,
                'is_active' => true, 'sort_order' => 8,
                'created_at' => $now, 'updated_at' => $now,
            ],
        ];

        foreach ($rows as $row) {
            if (! DB::table('channels')->where('code', $row['code'])->exists()) {
                DB::table('channels')->insert($row);
            }
        }

        // Display-name only: the platform is branded "Talabat". The code
        // (`talabaty`) and prefix (TLB) stay, so no historical row changes.
        DB::table('channels')->where('code', 'talabaty')->update(['name' => 'Talabat', 'name_ar' => 'طلبات']);
    }

    public function down(): void
    {
        $types = ['dine_in', 'takeaway', 'delivery', 'coffee_shop', 'talabaty', 'eshyai'];

        // Rows on the removed channels would violate the narrowed enum.
        DB::table('orders')->where('type', 'otlob')->update(['type' => 'delivery']);
        DB::table('orders')->where('type', 'other')->update(['type' => 'takeaway']);
        DB::table('invoices')->where('order_type', 'otlob')->update(['order_type' => 'delivery']);
        DB::table('invoices')->where('order_type', 'other')->update(['order_type' => 'takeaway']);

        $ids = DB::table('channels')->whereIn('code', ['otlob', 'other'])->pluck('id');
        DB::table('orders')->whereIn('channel_id', $ids)->update(['channel_id' => null]);
        DB::table('invoices')->whereIn('channel_id', $ids)->update(['channel_id' => null]);
        DB::table('channels')->whereIn('code', ['otlob', 'other'])->delete();

        DB::table('channels')->where('code', 'talabaty')->update(['name' => 'Talabaty', 'name_ar' => 'طلباتي']);

        Schema::table('orders', function (Blueprint $table) use ($types) {
            $table->enum('type', $types)->default('takeaway')->change();
        });

        Schema::table('invoices', function (Blueprint $table) use ($types) {
            $table->enum('order_type', $types)->default('takeaway')->change();
        });
    }
};
