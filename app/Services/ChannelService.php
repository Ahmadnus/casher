<?php

namespace App\Services;

use App\Models\Channel;
use App\Models\ChannelMenuItemPrice;
use App\Models\MenuItem;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Validation\ValidationException;

/**
 * Single place that resolves a channel code to its config row and applies
 * per-channel pricing. Both OrderService and InvoiceService go through here,
 * so an item can never be priced one way on the order and another on the
 * invoice.
 */
class ChannelService
{
    protected const CACHE_KEY = 'channels.by_code';

    protected const CACHE_TTL = 3600;

    /**
     * All channels keyed by code. Cached because every single order write
     * needs it and the table changes maybe twice a year.
     */
    public function all(): Collection
    {
        return Cache::remember(
            self::CACHE_KEY,
            self::CACHE_TTL,
            fn () => Channel::ordered()->get()->keyBy('code'),
        );
    }

    public function flushCache(): void
    {
        Cache::forget(self::CACHE_KEY);
    }

    public function activeChannels(): Collection
    {
        return $this->all()->filter(fn (Channel $c) => $c->is_active)->values();
    }

    public function findByCode(?string $code): ?Channel
    {
        return $code ? $this->all()->get($code) : null;
    }

    /**
     * Resolve the channel for an incoming order/invoice, rejecting codes that
     * exist in the enum but have been switched off (e.g. you paused Eshyai).
     *
     * @throws ValidationException
     */
    public function resolveForWrite(string $code): Channel
    {
        $channel = $this->findByCode($code);

        if (! $channel) {
            throw ValidationException::withMessages([
                'order_type' => ['قناة البيع غير معروفة: '.$code],
            ]);
        }

        if (! $channel->is_active) {
            throw ValidationException::withMessages([
                'order_type' => ["قناة البيع \"{$channel->name_ar}\" متوقفة حالياً"],
            ]);
        }

        return $channel;
    }

    /**
     * Overrides for one channel, keyed by menu_item_id. Loaded once per
     * order so pricing N lines stays a single query.
     *
     * @return Collection<int, ChannelMenuItemPrice>
     */
    public function overridesFor(?Channel $channel): Collection
    {
        if (! $channel) {
            return collect();
        }

        return ChannelMenuItemPrice::where('channel_id', $channel->id)
            ->get()
            ->keyBy('menu_item_id');
    }

    /**
     * Effective price of an item on a channel: the override when one is set,
     * otherwise the base menu price.
     */
    public function priceFor(MenuItem $item, ?Collection $overrides): float
    {
        $override = $overrides?->get($item->id);

        return $override && $override->price !== null
            ? (float) $override->price
            : (float) $item->price;
    }

    /**
     * Whether an item can be sold on this channel. An item hidden from the
     * channel is unavailable even if it is available in-store.
     */
    public function isAvailableOn(MenuItem $item, ?Collection $overrides): bool
    {
        if (! $item->is_available) {
            return false;
        }

        $override = $overrides?->get($item->id);

        return $override ? (bool) $override->is_available : true;
    }

    /**
     * Menu as one channel sees it — base menu with prices swapped and hidden
     * items removed. This is what the POS requests after picking a channel.
     */
    public function menuFor(Channel $channel): Collection
    {
        $overrides = $this->overridesFor($channel);

        return MenuItem::with('category')->available()->ordered()->get()
            ->filter(fn (MenuItem $item) => $this->isAvailableOn($item, $overrides))
            ->map(function (MenuItem $item) use ($overrides, $channel) {
                $price = $this->priceFor($item, $overrides);

                return [
                    'id' => $item->id,
                    'category_id' => $item->category_id,
                    'category_name' => $item->category?->name,
                    'name' => $item->name,
                    'description' => $item->description,
                    'image_url' => $item->image_url,
                    'base_price' => (float) $item->price,
                    'price' => $price,
                    'has_override' => $price !== (float) $item->price,
                    'channel_code' => $channel->code,
                    'sort_order' => $item->sort_order,
                ];
            })->values();
    }

    /**
     * Replace the override set for a channel in one call (the pricing screen
     * posts the whole list). Items omitted fall back to the base price.
     */
    public function syncPrices(Channel $channel, array $rows): Collection
    {
        foreach ($rows as $row) {
            ChannelMenuItemPrice::updateOrCreate(
                ['channel_id' => $channel->id, 'menu_item_id' => $row['menu_item_id']],
                [
                    'price' => $row['price'] ?? null,
                    'is_available' => $row['is_available'] ?? true,
                ],
            );
        }

        return $this->overridesFor($channel)->values();
    }
}
