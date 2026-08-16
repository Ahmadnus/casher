<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Sales channels (dine-in, takeaway, delivery, coffee shop, Talabaty, Eshyai).
 *
 * The existing `order_type` enum on orders/invoices stays as the denormalized
 * reporting column so every current report and the Flutter client keep working
 * untouched. This table is what makes a channel *configurable* — commission
 * rate, per-channel pricing, activation — which an enum cannot express.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('channels', function (Blueprint $table) {
            $table->id();

            // Matches orders.type / invoices.order_type exactly. This is the
            // join key between the config row and the reporting column.
            $table->string('code', 30)->unique();

            $table->string('name');
            $table->string('name_ar')->nullable();

            // Third-party platforms (Talabaty/Eshyai) charge a cut of every
            // order. Stored as a percentage, e.g. 22.50 = 22.5%.
            $table->decimal('commission_rate', 5, 2)->default(0);

            // Marks a channel as an external delivery aggregator rather than
            // an in-house one. Drives POS behaviour (no table number, external
            // reference required) and the "platform sales" report grouping.
            $table->boolean('is_third_party')->default(false);

            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);

            $table->timestamps();

            $table->index(['is_active', 'sort_order']);
        });

        $now = now();

        DB::table('channels')->insert([
            [
                'code' => 'dine_in', 'name' => 'Dine-in', 'name_ar' => 'طاولة',
                'commission_rate' => 0, 'is_third_party' => false,
                'is_active' => true, 'sort_order' => 1,
                'created_at' => $now, 'updated_at' => $now,
            ],
            [
                'code' => 'takeaway', 'name' => 'Takeaway', 'name_ar' => 'استلام',
                'commission_rate' => 0, 'is_third_party' => false,
                'is_active' => true, 'sort_order' => 2,
                'created_at' => $now, 'updated_at' => $now,
            ],
            [
                'code' => 'delivery', 'name' => 'Delivery', 'name_ar' => 'توصيل',
                'commission_rate' => 0, 'is_third_party' => false,
                'is_active' => true, 'sort_order' => 3,
                'created_at' => $now, 'updated_at' => $now,
            ],
            [
                'code' => 'coffee_shop', 'name' => 'Coffee Shop', 'name_ar' => 'كوفي شوب',
                'commission_rate' => 0, 'is_third_party' => false,
                'is_active' => true, 'sort_order' => 4,
                'created_at' => $now, 'updated_at' => $now,
            ],
            [
                'code' => 'talabaty', 'name' => 'Talabaty', 'name_ar' => 'طلباتي',
                'commission_rate' => 0, 'is_third_party' => true,
                'is_active' => true, 'sort_order' => 5,
                'created_at' => $now, 'updated_at' => $now,
            ],
            [
                'code' => 'eshyai', 'name' => 'Eshyai', 'name_ar' => 'اشيائي',
                'commission_rate' => 0, 'is_third_party' => true,
                'is_active' => true, 'sort_order' => 6,
                'created_at' => $now, 'updated_at' => $now,
            ],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('channels');
    }
};
