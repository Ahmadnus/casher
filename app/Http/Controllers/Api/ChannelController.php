<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Channel;
use App\Services\ChannelService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ChannelController extends Controller
{
    public function __construct(protected ChannelService $channels) {}

    /**
     * Channel list for the POS selector. Cashiers only ever see active ones.
     */
    public function index(Request $request): JsonResponse
    {
        $channels = $request->boolean('all')
            ? Channel::ordered()->get()
            : $this->channels->activeChannels();

        return $this->success($channels);
    }

    /**
     * Commission rate / activation. Settings-level change, so gate it on the
     * same permission that guards the rest of restaurant configuration.
     */
    public function update(Request $request, Channel $channel): JsonResponse
    {
        abort_unless($request->user()->can('settings.update'), 403);

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'name_ar' => ['sometimes', 'nullable', 'string', 'max:255'],
            // Uppercase letters only — it becomes part of the invoice number.
            'invoice_prefix' => ['sometimes', 'string', 'max:8', 'regex:/^[A-Z]+$/'],
            'commission_rate' => ['sometimes', 'numeric', 'min:0', 'max:100'],
            'is_active' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ]);

        $channel->update($data);
        $this->channels->flushCache();

        return $this->success($channel->fresh());
    }

    /**
     * The menu as this channel sees it — overridden prices applied, items
     * hidden from the channel removed. The POS calls this after the cashier
     * picks a channel so the cart is priced correctly from the first tap.
     */
    public function menu(Channel $channel): JsonResponse
    {
        return $this->success($this->channels->menuFor($channel));
    }

    /**
     * Current price overrides for a channel (the pricing admin screen).
     */
    public function prices(Channel $channel): JsonResponse
    {
        return $this->success(
            $this->channels->overridesFor($channel)->load('menuItem')->values(),
        );
    }

    /**
     * Bulk create/update of this channel's price overrides.
     */
    public function syncPrices(Request $request, Channel $channel): JsonResponse
    {
        abort_unless($request->user()->can('settings.update'), 403);

        $data = $request->validate([
            'prices' => ['required', 'array'],
            'prices.*.menu_item_id' => ['required', Rule::exists('menu_items', 'id')],
            'prices.*.price' => ['nullable', 'numeric', 'min:0'],
            'prices.*.is_available' => ['sometimes', 'boolean'],
        ]);

        return $this->success($this->channels->syncPrices($channel, $data['prices']));
    }
}
