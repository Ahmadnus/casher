<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Per-channel price overrides. A row here means "this item costs this much on
 * this channel"; with no row, the item's base menu_items.price applies.
 *
 * Sparse by design — you only store the items you actually mark up for
 * Talabaty/Eshyai, so the in-store menu stays the single source of truth.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('channel_menu_item_prices', function (Blueprint $table) {
            $table->id();

            $table->foreignId('channel_id')->constrained()->cascadeOnDelete();
            $table->foreignId('menu_item_id')->constrained()->cascadeOnDelete();

            // Null price = no override, row exists only to toggle availability.
            $table->decimal('price', 10, 2)->nullable();

            // Lets you hide an item from one channel without touching the
            // in-store menu (e.g. no fragile desserts on delivery apps).
            $table->boolean('is_available')->default(true);

            $table->timestamps();

            $table->unique(['channel_id', 'menu_item_id']);
            $table->index(['channel_id', 'is_available']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('channel_menu_item_prices');
    }
};
